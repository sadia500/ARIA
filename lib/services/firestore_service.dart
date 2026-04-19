import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final instance = FirestoreService._();
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ── Shortcut to current user's document ─────────────────────────────────
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference get _userDoc => _db.collection('users').doc(_uid);

  // ════════════════════════════════════════════════════════════════════════
  // USER PROFILE
  // ════════════════════════════════════════════════════════════════════════

  /// Call this right after sign up to save user info
  Future<void> saveProfile({
    required String name,
    required String email,
  }) async {
    await _userDoc.set({
      'name': name,
      'email': email,
      'streak': 0,
      'totalSessions': 0,
      'totalFocusMinutes': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // merge: true means if document already exists,
    // only update the fields we provide, don't delete the rest
  }

  /// Load user profile data
  Future<Map<String, dynamic>?> loadProfile() async {
    final doc = await _userDoc.get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  /// Update streak count
  Future<void> updateStreak(int streak) async {
    await _userDoc.update({'streak': streak});
  }

  /// Save onboarding preferences
  Future<void> saveOnboardingData({
    required String goal,
    required String workStart,
    required String workEnd,
    required int focusDuration,
  }) async {
    await _userDoc.set({
      'onboarding': {
        'goal': goal,
        'workStart': workStart,
        'workEnd': workEnd,
        'focusDuration': focusDuration,
      },
      'onboardingDone': true,
    }, SetOptions(merge: true));
  }

  // ════════════════════════════════════════════════════════════════════════
  // FOCUS SESSIONS
  // ════════════════════════════════════════════════════════════════════════

  /// Save a completed focus session
  Future<void> saveSession({
    required String energy, // 'high', 'medium', 'low'
    required int durationMinutes, // how long the session was
    required int focusScore, // 0-100 focus quality score
    required int distractions, // number of interruptions
    required String reflection, // 'great', 'okay', 'distracted'
    required String taskName, // what they were working on
  }) async {
    // Add new session document to sessions subcollection
    await _userDoc.collection('sessions').add({
      'energy': energy,
      'duration': durationMinutes,
      'focusScore': focusScore,
      'distractions': distractions,
      'reflection': reflection,
      'taskName': taskName,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String().substring(0, 10), // "2025-04-15"
    });

    // Also update total counts on user profile
    await _userDoc.update({
      'totalSessions': FieldValue.increment(1),
      'totalFocusMinutes': FieldValue.increment(durationMinutes),
    });
  }

  /// Load last 30 sessions (for analytics)
  Future<List<Map<String, dynamic>>> loadSessions() async {
    final snapshot = await _userDoc
        .collection('sessions')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Load sessions for a specific date
  Future<List<Map<String, dynamic>>> loadSessionsForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final snapshot = await _userDoc
        .collection('sessions')
        .where('date', isEqualTo: dateStr)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  // ════════════════════════════════════════════════════════════════════════
  // TASKS
  // ════════════════════════════════════════════════════════════════════════
  /// Update an existing task's fields
  Future<void> updateTask({
    required String taskId,
    required String title,
    required String subtitle,
    required String startTime,
    required String endTime,
    required String priority,
    required String category,
    required String date,
  }) async {
    await _userDoc.collection('tasks').doc(taskId).update({
      'title': title,
      'subtitle': subtitle,
      'startTime': startTime,
      'endTime': endTime,
      'priority': priority,
      'category': category,
      'date': date,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Save a new task
  Future<String> saveTask({
    required String title,
    required String subtitle,
    required String startTime,
    required String endTime,
    required String priority,
    required String category,
    required String date,
    bool isDone = false,
    String recurrence = 'none',
  }) async {
    final ref = await _userDoc.collection('tasks').add({
      'title': title,
      'subtitle': subtitle,
      'startTime': startTime,
      'endTime': endTime,
      'priority': priority,
      'category': category,
      'date': date,
      'isDone': isDone,
      'recurrence': recurrence,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Mark a task as completed or uncompleted
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    await _userDoc.collection('tasks').doc(taskId).update({
      'isDone': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    await _userDoc.collection('tasks').doc(taskId).delete();
  }

  /// Live stream of all tasks — UI updates automatically when tasks change
  Stream<List<Map<String, dynamic>>> tasksStream() {
    return _userDoc
        .collection('tasks')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
        );
  }

  /// Load all tasks once (not live)
  Future<List<Map<String, dynamic>>> loadTasks() async {
    final snapshot = await _userDoc
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  // ════════════════════════════════════════════════════════════════════════
  // REMINDERS
  // ════════════════════════════════════════════════════════════════════════

  /// Save a new reminder
  Future<String> saveReminder({
    required String title,
    required String subtitle,
    required String time,
    required String type, // 'focusTime', 'breakTime', 'meeting', etc
    required String priority, // 'high', 'medium', 'low'
    bool isAISuggested = false,
  }) async {
    final ref = await _userDoc.collection('reminders').add({
      'title': title,
      'subtitle': subtitle,
      'time': time,
      'type': type,
      'priority': priority,
      'isAISuggested': isAISuggested,
      'isEnabled': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Toggle reminder on or off
  Future<void> toggleReminder(String reminderId, bool isEnabled) async {
    await _userDoc.collection('reminders').doc(reminderId).update({
      'isEnabled': isEnabled,
    });
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    await _userDoc.collection('reminders').doc(reminderId).delete();
  }

  /// Live stream of reminders
  Stream<List<Map<String, dynamic>>> remindersStream() {
    return _userDoc
        .collection('reminders')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
        );
  }

  // ════════════════════════════════════════════════════════════════════════
  // ANALYTICS
  // ════════════════════════════════════════════════════════════════════════

  /// Get summary stats for analytics screen
  Future<Map<String, dynamic>> loadAnalyticsSummary() async {
    final profile = await loadProfile();
    final sessions = await loadSessions();

    if (sessions.isEmpty) {
      return {
        'totalSessions': 0,
        'totalFocusMinutes': 0,
        'averageFocusScore': 0,
        'averageDistractions': 0,
        'streak': profile?['streak'] ?? 0,
        'bestFocusScore': 0,
      };
    }

    // Calculate averages from session data
    final totalScore = sessions
        .map((s) => (s['focusScore'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a + b);

    final totalDistractions = sessions
        .map((s) => (s['distractions'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a + b);

    final scores = sessions
        .map((s) => (s['focusScore'] as num?)?.toInt() ?? 0)
        .toList();
    scores.sort();

    return {
      'totalSessions': profile?['totalSessions'] ?? sessions.length,
      'totalFocusMinutes': profile?['totalFocusMinutes'] ?? 0,
      'averageFocusScore': (totalScore / sessions.length).round(),
      'averageDistractions': (totalDistractions / sessions.length).round(),
      'streak': profile?['streak'] ?? 0,
      'bestFocusScore': scores.last,
      'recentSessions': sessions.take(7).toList(), // last 7 for chart
    };
  }

  Future<void> updateReminder({
    required String reminderId,
    required String time,
    required String repeat,
  }) async {}

  // ════════════════════════════════════════════════════════════════════════
  // MEMORIES
  // ════════════════════════════════════════════════════════════════════════

  /// Save a memory (key-value fact about the user)
  Future<void> saveMemory(String key, String value) async {
    await _userDoc.collection('memories').doc(key).set({
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Load all memories
  Future<Map<String, String>> loadMemories() async {
    try {
      final snap = await _userDoc.collection('memories').get();
      return Map.fromEntries(
        snap.docs.map(
          (d) => MapEntry(d.id, (d.data()['value'] as String?) ?? ''),
        ),
      );
    } catch (e) {
      return {};
    }
  }

  /// Delete a specific memory
  Future<void> deleteMemory(String key) async {
    await _userDoc.collection('memories').doc(key).delete();
  }

  /// Clear all memories
  Future<void> clearAllMemories() async {
    final snap = await _userDoc.collection('memories').get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
