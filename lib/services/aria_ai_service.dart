// lib/services/aria_ai_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AriaAIService {
  static const _apiKey =
      'AQ.Ab8RN6IcMkykmrh6sC8JOTk6wQkDX0Ghb32fvMqMqqZabR10FQ'; // ← paste your key here
  static const _model = 'gemini-2.0-flash'; // free and fast
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // Conversation history for multi-turn chat
  final List<Map<String, dynamic>> _history = [];

  // ── Send a message and get a response ─────────────────────────────────
  Future<String> sendMessage(String userMessage) async {
    try {
      // Load user context from Firestore
      final context = await _buildUserContext();

      // Add user message to history
      _history.add({
        'role': 'user',
        'parts': [
          {'text': userMessage},
        ],
      });

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt(context)},
            ],
          },
          'contents': _history,
          'generationConfig': {'maxOutputTokens': 1024, 'temperature': 0.7},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Add assistant reply to history
        _history.add({
          'role': 'model',
          'parts': [
            {'text': reply},
          ],
        });

        // Keep history from growing too large (last 10 exchanges)
        if (_history.length > 20) {
          _history.removeRange(0, 2);
        }

        return reply;
      } else if (response.statusCode == 429) {
        return 'ARIA is taking a quick breather. Please try again in a moment! 🌿';
      } else {
        print('Gemini error: ${response.statusCode} ${response.body}');
        return 'Error ${response.statusCode} - please try again';
      }
    } catch (e) {
      print('AriaAIService error: $e');
      return 'Something went wrong. Please check your connection.';
    }
  }

  // ── Clear conversation history ─────────────────────────────────────────
  void clearHistory() => _history.clear();

  // ── Build context from user's Firestore data ───────────────────────────
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
      final totalSessions = profile?['totalSessions'] ?? 0;
      final totalMinutes = profile?['totalFocusMinutes'] ?? 0;

      final taskList = tasks.isEmpty
          ? 'No pending tasks'
          : tasks
                .map(
                  (t) =>
                      '- ${t['title']} (${t['priority']} priority, ${t['startTime']}–${t['endTime']})',
                )
                .join('\n');

      final sessionList = sessions.isEmpty
          ? 'No recent sessions'
          : sessions
                .map(
                  (s) =>
                      '- ${s['taskName']}: ${s['duration']}min, score ${s['focusScore']}, energy ${s['energy']}',
                )
                .join('\n');

      return '''
User: $name
Focus streak: $streak days
Total sessions: $totalSessions
Total focus time: $totalMinutes minutes

Pending tasks:
$taskList

Recent focus sessions:
$sessionList
''';
    } catch (e) {
      print('Context load error: $e');
      return '';
    }
  }

  // ── System prompt ──────────────────────────────────────────────────────
  String _systemPrompt(String userContext) {
    return '''
You are ARIA, an intelligent productivity and focus coach built into the ARIA AI app.
You are warm, concise, and motivating. You help users manage tasks, plan focus sessions,
track habits, and stay productive.

Here is the current user's live data from the app:
$userContext

Guidelines:
- Keep responses concise (2-4 sentences unless the user asks for detail)
- Be personalized — reference their actual tasks, sessions and streak when relevant
- Be encouraging and positive
- If asked to start a focus session or add a task, acknowledge it warmly
- Today's date is ${DateTime.now().toString().substring(0, 10)}
- You have full knowledge of the user's productivity data above
''';
  }
}
