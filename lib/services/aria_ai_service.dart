// lib/services/aria_ai_service.dart
// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'package:flutter/foundation.dart';

class AriaAIService {
  static const _apiKey =
      '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';
  static const _model = 'llama-3.1-8b-instant';
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  final List<Map<String, dynamic>> _history = [];

  void clearHistory() => _history.clear();

  void primeLanguage(String language) {
    _history.clear();
    _history.addAll([
      {
        'role': 'user',
        'content': 'Please respond only in $language for this conversation.',
      },
      {
        'role': 'assistant',
        'content': 'Understood, I will respond only in $language.',
      },
    ]);
  }

  void restoreMessage(String text, bool isAria) {
    _history.add({'role': isAria ? 'assistant' : 'user', 'content': text});
  }

  Future<String> generateDashboardInsight() async {
    try {
      final context = await _buildUserContext();
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
              'role': 'system',
              'content':
                  'You are ARIA, a productivity AI. Generate ONE short, specific, '
                  'actionable insight for the user based on their data. '
                  'Max 15 words. No emojis. No filler. Be direct and specific. '
                  'Respond in English only.',
            },
            {
              'role': 'user',
              'content':
                  'Based on my data, give me one sharp productivity insight:\n$context',
            },
          ],
          'max_tokens': 40,
          'temperature': 0.7,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      }
      return 'Focus on your highest priority task first thing today.';
    } catch (e) {
      print('Insight generation error: $e');
      return 'Focus on your highest priority task first thing today.';
    }
  }

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

        if (reply.contains('TASK_ACTION:')) {
          try {
            final jsonStr = reply
                .split('TASK_ACTION:')[1]
                .trim()
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();

            final taskData = jsonDecode(jsonStr) as Map<String, dynamic>;

            if (onTaskCreate != null) {
              onTaskCreate(taskData);
            }

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

  Future<String> _buildUserContext() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return '';

      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(uid);
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      final results = await Future.wait([
        // 0 — profile
        userDoc.get(),
        // 1 — today's sessions only
        userDoc
            .collection('sessions')
            .where(
              'timestamp',
              isGreaterThan: Timestamp.fromDate(todayMidnight),
            )
            .orderBy('timestamp', descending: true)
            .get(),
        // 2 — tasks
        userDoc.collection('tasks').limit(50).get(),
        Future.value(null), // placeholder for memories — removed from brief
        // 4 — today's chats only
        userDoc
            .collection('chats')
            .where(
              'updatedAt',
              isGreaterThan: Timestamp.fromDate(todayMidnight),
            )
            .orderBy('updatedAt', descending: true)
            .limit(3)
            .get(),
      ]);

      // ── Profile ───────────────────────────────────────────────────────────
      final profile =
          (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
      final name = profile?['name'] ?? 'User';
      final streak = (profile?['streak'] as num?)?.toInt() ?? 0;
      final totalMinutes =
          (profile?['totalFocusMinutes'] as num?)?.toInt() ?? 0;

      // ── Tasks ─────────────────────────────────────────────────────────────
      final allTasks = (results[2] as QuerySnapshot).docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      // Today's tasks only
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final todayTasks = allTasks.where((t) {
        final date = t['date'] as String? ?? '';
        return date == todayStr;
      }).toList();

      final doneTodayTasks =
          todayTasks.where((t) => t['isDone'] == true).toList();
      final pendingTodayTasks =
          todayTasks.where((t) => t['isDone'] == false).toList();
      final highPriority =
          pendingTodayTasks.where((t) => t['priority'] == 'high').length;

      final pendingList = pendingTodayTasks
          .take(5)
          .map(
            (t) =>
                '- ${t['title']} (${t['priority']} priority, ${t['startTime']}–${t['endTime']})',
          )
          .join('\n');

      // ── Today's sessions ──────────────────────────────────────────────────
      final sessions = (results[1] as QuerySnapshot).docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

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

      final recentSessions = sessions
          .take(5)
          .map(
            (s) =>
                '- ${s['taskName'] ?? 'Session'}: ${s['duration']}min, '
                'score ${s['focusScore']}/100, energy ${s['energy']}',
          )
          .join('\n');

      // ── Today's chat history ──────────────────────────────────────────────
      final chatsSnap = results[4] as QuerySnapshot;
      final chatMsgs = <Map<String, dynamic>>[];

      for (final chatDoc in chatsSnap.docs) {
        final msgsSnap = await chatDoc.reference
            .collection('messages')
            .where(
              'timestamp',
              isGreaterThan: Timestamp.fromDate(todayMidnight),
            )
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();
        chatMsgs.addAll(
          msgsSnap.docs.map((d) => d.data() as Map<String, dynamic>),
        );
      }

      chatMsgs.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return ta.compareTo(tb);
      });

      final recentChatText = chatMsgs.isEmpty
          ? 'No conversations today'
          : chatMsgs
                .map(
                  (m) =>
                      '${(m['isAria'] as bool? ?? false) ? 'ARIA' : 'User'}: ${m['text']}',
                )
                .join('\n');

      final focusSection = sessions.isEmpty
          ? 'FOCUS SESSIONS: None today'
          : 'FOCUS TODAY:\n'
              'Sessions: ${sessions.length} | '
              'Avg score: $avgScore/100 | '
              'Avg duration: $avgDuration min\n'
              '$recentSessions';

      final taskSection = todayTasks.isEmpty
          ? 'TASKS: No tasks scheduled today'
          : 'TASKS TODAY:\n'
              'Completed: ${doneTodayTasks.length} | '
              'Pending: ${pendingTodayTasks.length} | '
              'High priority: $highPriority\n'
              '${pendingList.isEmpty ? '' : 'Pending:\n$pendingList'}';

      // ── Context string ────────────────────────────────────────────────────
      // NOTE: memoriesText is available here for regular chat use
      // but NOT included in brief context to avoid stale data
      return 'USER: $name\n'
          '${streak > 1 ? 'Streak: $streak days\n' : ''}'
          '\n$taskSection\n'
          '\n$focusSection\n'
          '\nTODAY\'S CONVERSATIONS:\n$recentChatText\n'
          '\nToday: ${now.toString().substring(0, 10)}';
    } catch (e) {
      debugPrint('Context error: $e');
      return '';
    }
  }

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
                  'Extract important personal facts from this conversation to remember for future. '
                  'Only extract facts that help personalize future AI responses. '
                  'User said: "$userMsg" '
                  'AI replied: "$ariaReply" '
                  'Return ONLY a valid JSON object (no markdown, no explanation) like {"key": "value"}. '
                  'Good examples: {"goal": "lose 10kg"}, {"job": "software engineer"}, {"project": "building ARIA app"}. '
                  'Use short snake_case keys. Return {} if nothing important.',
            },
          ],
          'max_tokens': 100,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String;

        final clean = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        if (clean == '{}' || clean.isEmpty) return;

        final Map<String, dynamic> facts = jsonDecode(clean);

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
    }
  }

  Future<String> generateSessionRemark({
    required String taskName,
    required int completedMin,
    required int totalMin,
    required int focusScore,
    required int distractions,
    required String energyLevel,
  }) async {
    try {
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
              'role': 'system',
              'content':
                  'You are ARIA, a brutally honest but kind productivity coach. '
                  'Generate ONE short remark (max 12 words) about this focus session. '
                  'Rules: if distractions > 2 acknowledge them directly. '
                  'If completed < 50% of planned time say so. '
                  'If focus score < 60 call it out honestly. '
                  'Be specific to the actual numbers. No toxic positivity. No emojis. English only.',
            },
            {
              'role': 'user',
              'content':
                  'Task: "$taskName". Completed $completedMin of $totalMin minutes '
                  '(${totalMin == 0 ? 0 : (completedMin * 100 ~/ totalMin)}% of planned). '
                  'Focus score: $focusScore%. Distractions: $distractions. '
                  'Energy going in: $energyLevel. Give an honest remark.',
            },
          ],
          'max_tokens': 30,
          'temperature': 0.8,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      }
      return 'Good work staying focused on $taskName.';
    } catch (e) {
      return 'Good work staying focused on $taskName.';
    }
  }

  Future<String> generateSessionInsight({
    required String energyLevel,
    required String taskName,
  }) async {
    try {
      final context = await _buildUserContext();
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
              'role': 'system',
              'content':
                  'You are ARIA. Give ONE short motivational insight (max 12 words) '
                  'before a focus session. Be specific to their energy level and task. '
                  'No emojis. English only.',
            },
            {
              'role': 'user',
              'content':
                  'Energy: $energyLevel. Task: "$taskName". User data:\n$context\n'
                  'Give one sharp pre-session insight.',
            },
          ],
          'max_tokens': 30,
          'temperature': 0.8,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      }
      return 'Stay locked in — every minute counts.';
    } catch (e) {
      return 'Stay locked in — every minute counts.';
    }
  }

  Future<String> generateDailyBrief() async {
    try {
      final context = await _buildUserContext();
      final now = DateTime.now();
      final h = now.hour;
      final timeOfDay = h < 12
          ? 'morning'
          : h < 17
          ? 'afternoon'
          : 'evening';
      final dayName = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday',
      ][now.weekday - 1];

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
              'role': 'system',
              'content':
                  'You are ARIA, speaking directly to the user like Mel Robbins at the end of their day. '
                  'Generate a warm evening check-in brief — acknowledge what they actually did today based on their data, '
                  'give them one grounding truth or reframe about how the day went, '
                  'and leave them feeling ready to rest and reset for tomorrow. '
                  'Not a productivity report. A human moment at the end of the day. '
                  'CRITICAL: Only mention data that actually exists. '
                  'If completed tasks = 0 do NOT mention completing tasks. '
                  'If sessions = 0 skip focus entirely. '
                  'If no relevant chat history skip it. '
                  'Never hallucinate numbers or achievements. '
                  'Sound like a voice note from a caring friend. '
                  'No bullet points. No "you got this". No emojis. Never say productivity. '
                  'Max 5-6 sentences. English only. Start mid-thought, no greeting.',
            },
            {
              'role': 'user',
              'content':
                  'It is evening on $dayName. '
                  'Here is my actual data. Only reference what is present and non-zero:\n$context\n\n'
                  'Give me an honest evening reflection based only on what actually happened today.',
            },
          ],
          'max_tokens': 180,
          'temperature': 0.85,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      }
      return 'It is $timeOfDay on $dayName — you showed up, and that already matters.';
    } catch (e) {
      return 'You are here, and that is the first step. Take it one thing at a time.';
    }
  }
}

String _systemPrompt(String userContext) {
  return 'You are ARIA, a personal AI assistant inside a productivity app.\n\n'
      'Your personality:\n'
      '- Warm, natural, conversational, like texting a smart friend\n'
      '- Match the user energy: casual message = casual reply, serious = thoughtful\n'
      '- Emotionally aware, if someone seems stressed or frustrated, acknowledge that first\n'
      '- Never preachy, never robotic, never force productivity talk unprompted\n\n'
      'Response rules:\n'
      '- SHORT by default. A greeting gets a greeting. A simple question gets a direct answer\n'
      '- Only give longer responses when explicitly asked for analysis, advice or a plan\n'
      '- No bullet points unless the user asks for a list\n'
      '- No filler openers like "Of course!", "Great question!", "Certainly!"\n'
      '- Never suggest focus sessions or tasks unless the user brings it up first\n'
      '- If someone says "hey" or "how are you" just respond naturally\n\n'
      'Always respond in the same language the user writes in.\n\n'
      'Only use the productivity data below when the user asks about their tasks, '
      'sessions, focus, schedule or productivity. Otherwise ignore it completely.\n\n'
      '$userContext\n\n'
      'TASK CREATION:\n'
      'If user wants to create/schedule/add a task, respond ONLY with this exact format:\n\n'
      'TASK_ACTION:{"title":"task name","date":"YYYY-MM-DD","startTime":"HH:MM AM/PM",'
      '"endTime":"HH:MM AM/PM","priority":"high/medium/low","category":"work/personal/health/learning"}\n\n'
      'Rules:\n'
      '- date: "tomorrow" = ${_tomorrow()}\n'
      '- If no end time mentioned, add 1 hour to start\n'
      '- If no priority mentioned, use "medium"\n'
      '- Only output TASK_ACTION if user clearly wants to CREATE a task\n'
      '- For everything else respond normally';
}

String _tomorrow() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
}