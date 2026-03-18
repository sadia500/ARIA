// lib/services/storage_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Persists all ARIA data across sessions using shared_preferences.
// Stores tasks as JSON, user prefs as simple key-value.
//
// Package: shared_preferences: ^2.3.2
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Keys ─────────────────────────────────────────────────────────────────────
class _Keys {
  static const tasks = 'aria_tasks_v1';
  static const userName = 'aria_user_name';
  static const userEmail = 'aria_user_email';
  static const streak = 'aria_streak';
  static const lastActiveDate = 'aria_last_active';
  static const focusSessions = 'aria_focus_sessions';
  static const totalFocusMinutes = 'aria_total_focus_minutes';
  static const notificationsOn = 'aria_notif_on';
  static const focusShieldOn = 'aria_focus_shield';
  static const smartRemindersOn = 'aria_smart_reminders';
  static const dailyReportOn = 'aria_daily_report';
  static const onboardingDone = 'aria_onboarding_done';
  static const darkMode = 'aria_dark_mode';
  static const userAvatarColor = 'aria_avatar_color';
}

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;

  // ─────────────────────────────────────────────────────────────────────────
  // INIT — call once in main() before runApp
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ StorageService initialized');
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'StorageService.init() must be called before use');
    return _prefs!;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TASKS
  // ─────────────────────────────────────────────────────────────────────────

  /// Save full task list as JSON
  Future<void> saveTasks(List<Map<String, dynamic>> tasks) async {
    final encoded = jsonEncode(tasks);
    await _p.setString(_Keys.tasks, encoded);
    debugPrint('💾 Saved ${tasks.length} tasks');
  }

  /// Load task list from JSON — returns empty list if nothing saved
  List<Map<String, dynamic>> loadTasks() {
    final raw = _p.getString(_Keys.tasks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('⚠️ Failed to decode tasks: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER INFO
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveUserName(String name) => _p.setString(_Keys.userName, name);

  String loadUserName() => _p.getString(_Keys.userName) ?? '';

  Future<void> saveUserEmail(String email) =>
      _p.setString(_Keys.userEmail, email);

  String loadUserEmail() => _p.getString(_Keys.userEmail) ?? '';

  // ─────────────────────────────────────────────────────────────────────────
  // STREAK
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveStreak(int streak) => _p.setInt(_Keys.streak, streak);

  int loadStreak() => _p.getInt(_Keys.streak) ?? 0;

  Future<void> saveLastActiveDate(DateTime date) =>
      _p.setString(_Keys.lastActiveDate, date.toIso8601String());

  DateTime? loadLastActiveDate() {
    final raw = _p.getString(_Keys.lastActiveDate);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Auto-increment or reset streak based on last active date
  Future<int> updateStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = loadLastActiveDate();
    int streak = loadStreak();

    if (lastDate == null) {
      // First time
      streak = 1;
    } else {
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 0) {
        // Same day — no change
      } else if (diff == 1) {
        // Consecutive day
        streak++;
      } else {
        // Streak broken
        streak = 1;
      }
    }

    await saveStreak(streak);
    await saveLastActiveDate(today);
    return streak;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOCUS STATS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveFocusSessions(int count) =>
      _p.setInt(_Keys.focusSessions, count);

  int loadFocusSessions() => _p.getInt(_Keys.focusSessions) ?? 0;

  Future<void> addFocusSession(int durationMinutes) async {
    final sessions = loadFocusSessions() + 1;
    final minutes = loadTotalFocusMinutes() + durationMinutes;
    await _p.setInt(_Keys.focusSessions, sessions);
    await _p.setInt(_Keys.totalFocusMinutes, minutes);
    debugPrint(
      '💪 Focus session saved: $durationMinutes min | Total: ${minutes}min',
    );
  }

  Future<void> saveTotalFocusMinutes(int minutes) =>
      _p.setInt(_Keys.totalFocusMinutes, minutes);

  int loadTotalFocusMinutes() => _p.getInt(_Keys.totalFocusMinutes) ?? 0;

  double get totalFocusHours => loadTotalFocusMinutes() / 60;

  // ─────────────────────────────────────────────────────────────────────────
  // SETTINGS / PREFERENCES
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveNotificationsOn(bool v) =>
      _p.setBool(_Keys.notificationsOn, v);
  bool loadNotificationsOn() => _p.getBool(_Keys.notificationsOn) ?? true;

  Future<void> saveFocusShieldOn(bool v) => _p.setBool(_Keys.focusShieldOn, v);
  bool loadFocusShieldOn() => _p.getBool(_Keys.focusShieldOn) ?? true;

  Future<void> saveSmartRemindersOn(bool v) =>
      _p.setBool(_Keys.smartRemindersOn, v);
  bool loadSmartRemindersOn() => _p.getBool(_Keys.smartRemindersOn) ?? true;

  Future<void> saveDailyReportOn(bool v) => _p.setBool(_Keys.dailyReportOn, v);
  bool loadDailyReportOn() => _p.getBool(_Keys.dailyReportOn) ?? false;

  // ─────────────────────────────────────────────────────────────────────────
  // ONBOARDING
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> setOnboardingDone() => _p.setBool(_Keys.onboardingDone, true);

  bool get isOnboardingDone => _p.getBool(_Keys.onboardingDone) ?? false;

  // ─────────────────────────────────────────────────────────────────────────
  // THEME
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveDarkMode(bool v) => _p.setBool(_Keys.darkMode, v);
  bool loadDarkMode() => _p.getBool(_Keys.darkMode) ?? true;

  Future<void> saveAvatarColor(int colorValue) =>
      _p.setInt(_Keys.userAvatarColor, colorValue);
  int loadAvatarColor() =>
      _p.getInt(_Keys.userAvatarColor) ?? 0xFF9B6FE8; // default purple

  // ─────────────────────────────────────────────────────────────────────────
  // CLEAR (sign out)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> clearUserData() async {
    await _p.remove(_Keys.userName);
    await _p.remove(_Keys.userEmail);
    // Keep tasks and focus stats — user might log back in
    debugPrint('🗑 User data cleared');
  }

  Future<void> clearAll() async {
    await _p.clear();
    debugPrint('🗑 All storage cleared');
  }
}
