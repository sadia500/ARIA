// lib/services/aria_ai_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AriaAIService {
  // ── Groq API — free, fast, generous limits ─────────────────────────────
  static const _apiKey =
      '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'; // gsk_...
  static const _model = 'llama-3.1-8b-instant';
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  // Conversation history
  final List<Map<String, dynamic>> _history = [];

  // ── Send a message ─────────────────────────────────────────────────────
  Future<String> sendMessage(String userMessage) async {
    try {
      // Load user context from Firestore
      final context = await _buildUserContext();

      // Add to history
      _history.add({'role': 'user', 'content': userMessage});

      // Build messages — system prompt + history
      final messages = [
        {'role': 'system', 'content': _systemPrompt(context)},
        ..._history,
      ];

      print('Calling Groq API with ${messages.length} messages...');

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

      print('Groq response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] as String;

        // Add assistant reply to history
        _history.add({'role': 'assistant', 'content': reply});

        // Keep history manageable (last 10 exchanges = 20 messages)
        if (_history.length > 20) {
          _history.removeRange(0, 2);
        }

        return reply.trim();
      } else if (response.statusCode == 429) {
        print('Rate limit: ${response.body}');
        return 'Too many messages — please wait a moment and try again! 🌿';
      } else {
        print('Groq error ${response.statusCode}: ${response.body}');
        return 'Error ${response.statusCode} — please try again.';
      }
    } catch (e) {
      print('AriaAIService error: $e');
      return 'Something went wrong. Please check your connection.';
    }
  }

  // ── Clear history ──────────────────────────────────────────────────────
  void clearHistory() => _history.clear();

  // ── Build user context from Firestore ──────────────────────────────────
  Future<String> _buildUserContext() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 'User not logged in.';

      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(uid);

      final results = await Future.wait([
        userDoc.get(),
        userDoc
            .collection('sessions')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get(),
        userDoc
            .collection('tasks')
            .where('isDone', isEqualTo: false)
            .limit(10)
            .get(),
      ]);

      final profile =
          (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
      final sessions = (results[1] as QuerySnapshot).docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
      final tasks = (results[2] as QuerySnapshot).docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      final name = profile?['name'] ?? 'User';
      final streak = profile?['streak'] ?? 0;
      final totalSessions = sessions.length; // ← use actual count
      final totalMinutes = profile?['totalFocusMinutes'] ?? 0;

      final taskList = tasks.isEmpty
          ? 'No pending tasks'
          : tasks
                .map(
                  (t) =>
                      '- ${t['title']} (${t['priority']} priority, '
                      '${t['startTime']}–${t['endTime']}, '
                      'category: ${t['category']})',
                )
                .join('\n');

      final sessionList = sessions.isEmpty
          ? 'No recent sessions'
          : sessions
                .map(
                  (s) =>
                      '- ${s['taskName'] ?? 'Unknown'}: '
                      '${s['duration'] ?? 0}min, '
                      'score ${s['focusScore'] ?? 0}/100, '
                      'energy ${s['energy'] ?? 'unknown'}',
                )
                .join('\n');
      return '''
User name: $name
Focus streak: $streak days
Total focus sessions: $totalSessions
Total focus time: $totalMinutes minutes

Pending tasks today:
$taskList

Recent focus sessions:
$sessionList

Today's date: ${DateTime.now().toString().substring(0, 10)}
''';
    } catch (e) {
      print('Context load error: $e');
      return 'Could not load user data.';
    }
  }

  // ── System prompt ──────────────────────────────────────────────────────
  String _systemPrompt(String userContext) {
    return '''
You are ARIA, a premium AI productivity coach inside the ARIA app.
You are warm, intelligent, and concise — like a smart friend who knows your schedule.

User's live data:
$userContext

STRICT response rules:
- NEVER dump raw lists or data at the user
- NEVER use bullet points with dashes (- item)
- NEVER show session details line by line
- Always summarize data into natural conversational sentences
- Maximum 3 sentences per response
- Be specific — mention actual task names and real numbers
- Sound like a premium AI assistant, not a database printout
- End with one short motivating sentence
- Keep responses VERY SHORT — maximum 2 sentences for greetings and simple questions
- Only give longer responses if user explicitly asks for details or a list
- For "hi", "hello", "hey" — respond in ONE sentence only
- Never repeat information the user didn't ask for

Example of BAD response:
"- study: 30min, score 92, energy medium, distractions 3
- Free Focus Session: 15min, score 92"

Example of GOOD response:
"You've completed 6 focus sessions totaling 185 minutes — that's impressive! Your scores are consistently around 92/100, which shows strong concentration. Keep this momentum going today! 🔥"
''';
  }
}
