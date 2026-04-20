// lib/services/aria_ai_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AriaAIService {
  // ── Groq API ───────────────────────────────────────────────────────────────
  static const _apiKey =
      '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'; // gsk_...
  static const _model = 'llama-3.1-8b-instant';
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  // ── Conversation history ───────────────────────────────────────────────────
  final List<Map<String, dynamic>> _history = [];

  // ─────────────────────────────────────────────────────────────────────────
  // SEND MESSAGE
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> sendMessage(
    String userMessage, {
    Function(Map<String, dynamic>)? onTaskCreate,
  }) async {
    try {
      final context = await _buildUserContext();

      _history.add({'role': 'user', 'content': userMessage});

      final messages = [
        {'role': 'system', 'content': _systemPrompt(context)},
        ..._history,
      ];

      print('Calling Groq...');

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 200,
          'temperature': 0.7,
        }),
      );

      print('Groq status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['choices'][0]['message']['content'] as String;
        reply = reply.trim();

        // ── Check if AI wants to create a task ──────────────────────
        if (reply.contains('TASK_ACTION:')) {
          try {
            final jsonStr = reply
                .split('TASK_ACTION:')[1]
                .trim()
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();

            final taskData = jsonDecode(jsonStr) as Map<String, dynamic>;

            // Call the callback to create task in app
            if (onTaskCreate != null) {
              onTaskCreate(taskData);
            }

            // Give friendly confirmation reply
            reply =
                'Done! I\'ve added "${taskData['title']}" to your schedule '
                'for ${taskData['date']} at ${taskData['startTime']} 🗓️';
          } catch (e) {
            print('Task parse error: $e');
            reply =
                'I\'d like to add that task — please go to the Schedule tab to add it manually!';
          }
        }

        _history.add({'role': 'assistant', 'content': reply});

        if (_history.length > 20) {
          _history.removeRange(0, 2);
        }

        _extractMemories(userMessage, reply);

        return reply.trim();
      } else if (response.statusCode == 429) {
        return 'Too many messages — please wait a moment! 🌿';
      } else {
        print('Groq error ${response.statusCode}: ${response.body}');
        return 'Error ${response.statusCode} — please try again.';
      }
    } catch (e) {
      print('AriaAIService error: $e');
      return 'Something went wrong. Please check your connection.';
    }
  }

  // ── Clear history ──────────────────────────────────────────────────────────
  void clearHistory() => _history.clear();

  // ─────────────────────────────────────────────────────────────────────────
  // LEVEL 1 — BUILD RICH USER CONTEXT WITH PATTERN ANALYSIS
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> _buildUserContext() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return '';

      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(uid);

      final results = await Future.wait([
        userDoc.get(),
        userDoc
            .collection('sessions')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get(),
        userDoc.collection('tasks').limit(50).get(),
        userDoc.collection('memories').get(), // Level 2 memories
      ]);

      final profile =
          (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
      final sessions = (results[1] as QuerySnapshot).docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
      final allTasks = (results[2] as QuerySnapshot).docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      // ── Profile basics ────────────────────────────────────────────────────
      final name = profile?['name'] ?? 'User';
      final streak = profile?['streak'] ?? 0;
      final totalMinutes = profile?['totalFocusMinutes'] ?? 0;

      // ── Task pattern analysis ─────────────────────────────────────────────
      final doneTasks = allTasks.where((t) => t['isDone'] == true).toList();
      final pendingTasks = allTasks.where((t) => t['isDone'] == false).toList();
      final completionRate = allTasks.isEmpty
          ? 0
          : (doneTasks.length / allTasks.length * 100).toInt();

      // Most completed category
      final categoryDone = <String, int>{};
      for (final t in doneTasks) {
        final cat = t['category'] ?? 'work';
        categoryDone[cat] = (categoryDone[cat] ?? 0) + 1;
      }
      final topCategory = categoryDone.entries.isEmpty
          ? 'unknown'
          : categoryDone.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;

      // Most skipped category
      final categorySkipped = <String, int>{};
      for (final t in pendingTasks) {
        final cat = t['category'] ?? 'work';
        categorySkipped[cat] = (categorySkipped[cat] ?? 0) + 1;
      }
      final skippedCategory = categorySkipped.entries.isEmpty
          ? 'none'
          : categorySkipped.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;

      // High priority pending count
      final highPriority = pendingTasks
          .where((t) => t['priority'] == 'high')
          .length;

      // Pending tasks list (top 5)
      final pendingList = pendingTasks
          .take(5)
          .map(
            (t) =>
                '- ${t['title']} (${t['priority']} priority, '
                '${t['startTime']}–${t['endTime']})',
          )
          .join('\n');

      // ── Focus session pattern analysis ────────────────────────────────────
      final avgScore = sessions.isEmpty
          ? 0
          : sessions
                    .map((s) => (s['focusScore'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a + b) ~/
                sessions.length;

      final avgDuration = sessions.isEmpty
          ? 0
          : sessions
                    .map((s) => (s['duration'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a + b) ~/
                sessions.length;

      final avgDistractions = sessions.isEmpty
          ? 0
          : sessions
                    .map((s) => (s['distractions'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a + b) ~/
                sessions.length;

      final bestScore = sessions.isEmpty
          ? 0
          : sessions
                .map((s) => (s['focusScore'] as num?)?.toInt() ?? 0)
                .reduce(math.max);

      // Best energy level
      final energyCount = <String, int>{};
      for (final s in sessions) {
        final e = s['energy'] ?? 'medium';
        energyCount[e] = (energyCount[e] ?? 0) + 1;
      }
      final bestEnergy = energyCount.entries.isEmpty
          ? 'medium'
          : energyCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      // Score trend (improving or declining)
      String scoreTrend = 'stable';
      if (sessions.length >= 4) {
        final recent =
            sessions
                .take(3)
                .map((s) => (s['focusScore'] as num?)?.toInt() ?? 0)
                .reduce((a, b) => a + b) ~/
            3;
        final older =
            sessions
                .skip(3)
                .take(3)
                .map((s) => (s['focusScore'] as num?)?.toInt() ?? 0)
                .reduce((a, b) => a + b) ~/
            3;
        if (recent > older + 5) scoreTrend = 'improving';
        if (recent < older - 5) scoreTrend = 'declining';
      }

      // Recent sessions list (top 5)
      final recentSessions = sessions
          .take(5)
          .map(
            (s) =>
                '- ${s['taskName'] ?? 'Session'}: ${s['duration']}min, '
                'score ${s['focusScore']}/100, energy ${s['energy']}',
          )
          .join('\n');

      // ── Level 2: Load memories ────────────────────────────────────────────
      final memoriesSnap = results[3] as QuerySnapshot;
      final memories = Map.fromEntries(
        memoriesSnap.docs.map(
          (d) => MapEntry(d.id, ((d.data() as Map)['value'] as String?) ?? ''),
        ),
      );
      final memoriesText = memories.isEmpty
          ? 'None yet'
          : memories.entries.map((e) => '- ${e.key}: ${e.value}').join('\n');

      // ── Build final context string ────────────────────────────────────────
      return '''
USER PROFILE:
Name: $name
Focus streak: $streak days
Total focus time: ${(totalMinutes / 60).toStringAsFixed(1)} hours

TASK PATTERNS:
Total tasks: ${allTasks.length} | Completed: ${doneTasks.length} | Pending: ${pendingTasks.length}
Completion rate: $completionRate%
Most productive category: $topCategory
Most skipped category: $skippedCategory
High priority pending: $highPriority tasks

PENDING TASKS:
${pendingList.isEmpty ? 'No pending tasks' : pendingList}

FOCUS PATTERNS:
Total sessions: ${sessions.length}
Average focus score: $avgScore/100
Best focus score ever: $bestScore/100
Score trend: $scoreTrend
Average session length: $avgDuration minutes
Best energy level: $bestEnergy
Average distractions: $avgDistractions per session

RECENT SESSIONS:
${recentSessions.isEmpty ? 'No sessions yet' : recentSessions}

REMEMBERED FACTS ABOUT USER:
$memoriesText

Today: ${DateTime.now().toString().substring(0, 10)}
''';
    } catch (e) {
      print('Context error: $e');
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEVEL 2 — EXTRACT AND SAVE MEMORIES FROM CONVERSATION
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _extractMemories(String userMsg, String ariaReply) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content':
                  '''
Extract important personal facts from this conversation to remember for future.
Only extract facts that help personalize future AI responses.

User said: "$userMsg"
AI replied: "$ariaReply"

Return ONLY a valid JSON object (no markdown, no explanation):
{"key": "value"}

Good examples:
- {"goal": "lose 10kg by June"}
- {"work_hours": "9am to 6pm"}
- {"exam_date": "next Monday"}
- {"job": "software engineer"}
- {"distraction": "social media"}
- {"prefers_morning_focus": "true"}
- {"project": "building ARIA app"}

Use short snake_case keys. Return {} if nothing important.
''',
            },
          ],
          'max_tokens': 100,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String;

        // Clean and parse JSON
        final clean = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        if (clean == '{}' || clean.isEmpty) return;

        final Map<String, dynamic> facts = jsonDecode(clean);

        // Save each fact to Firestore
        for (final entry in facts.entries) {
          if (entry.key.isNotEmpty && entry.value.toString().isNotEmpty) {
            await FirestoreService.instance.saveMemory(
              entry.key,
              entry.value.toString(),
            );
            print('Memory saved: ${entry.key} = ${entry.value}');
          }
        }
      }
    } catch (e) {
      print('Memory extraction error: $e');
      // Silent fail — memory extraction is background feature
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYSTEM PROMPT
  // ─────────────────────────────────────────────────────────────────────────
}

String _systemPrompt(String userContext) {
  return '''
You are ARIA, a personal AI assistant inside a productivity app.

Your personality:
- Warm, natural, conversational — like texting a smart friend
- Match the user's energy: casual message = casual reply, serious = thoughtful
- Emotionally aware — if someone seems stressed, tired or frustrated, acknowledge that first
- Never preachy, never robotic, never force productivity talk unprompted

Response rules:
- SHORT by default. A greeting gets a greeting. A simple question gets a direct answer
- Only give longer responses when explicitly asked for analysis, advice or a plan
- No bullet points unless the user asks for a list
- No filler openers like "Of course!", "Great question!", "Certainly!"
- Never suggest focus sessions or tasks unless the user brings it up first
- If someone says "hey" or "how are you" — just respond naturally like a person would

Only use the productivity data below when the user asks about their tasks, sessions, focus, schedule or productivity. Otherwise ignore it completely.

$userContext

TASK CREATION:
If user wants to create/schedule/add a task, respond ONLY with this exact format:

TASK_ACTION:{"title":"task name","date":"YYYY-MM-DD","startTime":"HH:MM AM/PM","endTime":"HH:MM AM/PM","priority":"high/medium/low","category":"work/personal/health/learning"}

Rules:
- date: "tomorrow" = ${_tomorrow()}
- If no end time mentioned, add 1 hour to start
- If no priority mentioned, use "medium"
- Only output TASK_ACTION if user clearly wants to CREATE a task
- For everything else respond normally
''';
}

String _tomorrow() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
}
