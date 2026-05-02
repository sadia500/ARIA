// lib/services/storage_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: unused_field

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ StorageService initialized');
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'StorageService.init() must be called before use');
    return _prefs!;
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────
  Future<void> saveTasks(List<Map<String, dynamic>> tasks) async {
    await _p.setString(_Keys.tasks, jsonEncode(tasks));
    debugPrint('💾 Saved ${tasks.length} tasks');
  }

  List<Map<String, dynamic>> loadTasks() {
    final raw = _p.getString(_Keys.tasks);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('⚠️ Failed to decode tasks: $e');
      return [];
    }
  }

  // ── User info ─────────────────────────────────────────────────────────────
  Future<void> saveUserName(String name) => _p.setString(_Keys.userName, name);
  String loadUserName() => _p.getString(_Keys.userName) ?? '';

  Future<void> saveUserEmail(String email) =>
      _p.setString(_Keys.userEmail, email);
  String loadUserEmail() => _p.getString(_Keys.userEmail) ?? '';

  // ── Streak ────────────────────────────────────────────────────────────────
  Future<void> saveStreak(int streak) => _p.setInt(_Keys.streak, streak);
  int loadStreak() => _p.getInt(_Keys.streak) ?? 0;

  Future<void> saveLastActiveDate(DateTime date) =>
      _p.setString(_Keys.lastActiveDate, date.toIso8601String());

  DateTime? loadLastActiveDate() {
    final raw = _p.getString(_Keys.lastActiveDate);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<int> updateStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = loadLastActiveDate();
    int streak = loadStreak();

    if (lastDate == null) {
      streak = 1;
    } else {
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 0) {
        // same day
      } else if (diff == 1) {
        streak++;
      } else {
        streak = 1;
      }
    }

    await saveStreak(streak);
    await saveLastActiveDate(today);
    return streak;
  }

  Future<void> markTaskCompletedToday() async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastStr = _p.getString('aria_last_completion_date') ?? '';
    if (lastStr == todayStr) return;

    await _p.setString('aria_last_completion_date', todayStr);

    final lastDate = loadLastActiveDate();
    int streak = loadStreak();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (lastDate == null) {
      streak = 1;
    } else {
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = todayDate.difference(lastDay).inDays;
      if (diff == 0) {
        // already counted
      } else if (diff == 1) {
        streak++;
      } else {
        streak = 1;
      }
    }

    await saveStreak(streak);
    await saveLastActiveDate(todayDate);
  }

  // ── Focus stats ───────────────────────────────────────────────────────────
  Future<void> saveFocusSessions(int count) =>
      _p.setInt(_Keys.focusSessions, count);
  int loadFocusSessions() => _p.getInt(_Keys.focusSessions) ?? 0;

  Future<void> addFocusSession(int durationMinutes) async {
    final sessions = loadFocusSessions() + 1;
    final minutes = loadTotalFocusMinutes() + durationMinutes;
    await _p.setInt(_Keys.focusSessions, sessions);
    await _p.setInt(_Keys.totalFocusMinutes, minutes);
  }

  Future<void> saveTotalFocusMinutes(int minutes) =>
      _p.setInt(_Keys.totalFocusMinutes, minutes);
  int loadTotalFocusMinutes() => _p.getInt(_Keys.totalFocusMinutes) ?? 0;
  double get totalFocusHours => loadTotalFocusMinutes() / 60;

  // ── Settings ──────────────────────────────────────────────────────────────
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

  // ── Onboarding ────────────────────────────────────────────────────────────
  Future<void> setOnboardingDone() => _p.setBool(_Keys.onboardingDone, true);
  bool get isOnboardingDone => _p.getBool(_Keys.onboardingDone) ?? false;

  // ── Theme ─────────────────────────────────────────────────────────────────
  Future<void> saveDarkMode(bool v) => _p.setBool(_Keys.darkMode, v);
  bool loadDarkMode() => _p.getBool(_Keys.darkMode) ?? true;

  Future<void> saveAvatarColor(int colorValue) =>
      _p.setInt(_Keys.userAvatarColor, colorValue);
  int loadAvatarColor() => _p.getInt(_Keys.userAvatarColor) ?? 0xFF9B6FE8;

  // ── Profile image ─────────────────────────────────────────────────────────
  Future<void> saveProfileImageUrl(String url) =>
      _p.setString('aria_profile_image', url);

  String? loadProfileImageUrl() {
    final url = _p.getString('aria_profile_image');
    return (url == null || url.isEmpty) ? null : url;
  }

  // ── Brief time ────────────────────────────────────────────────────────────
  Future<void> saveBriefTime(int hour, int minute) async {
    await _p.setInt('brief_hour', hour);
    await _p.setInt('brief_minute', minute);
  }

  int loadBriefHour() => _p.getInt('brief_hour') ?? 22;
  int loadBriefMinute() => _p.getInt('brief_minute') ?? 0;

  // ── Daily brief ───────────────────────────────────────────────────────────
  Future<void> saveDailyBriefContent(String brief) =>
      _p.setString('aria_daily_brief', brief);
  String loadDailyBriefContent() => _p.getString('aria_daily_brief') ?? '';

  Future<void> saveBriefGeneratedDate(String date) =>
      _p.setString('aria_brief_date', date);
  String loadBriefGeneratedDate() => _p.getString('aria_brief_date') ?? '';

  bool get isBriefReadyToday {
    final saved = loadBriefGeneratedDate();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return saved == today && loadDailyBriefContent().isNotEmpty;
  }

  Future<void> markBriefDismissedToday() => _p.setString(
    'aria_brief_dismissed',
    DateTime.now().toIso8601String().substring(0, 10),
  );

  bool get isBriefDismissedToday {
    final saved = _p.getString('aria_brief_dismissed') ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return saved == today;
  }

  // ── Clear ─────────────────────────────────────────────────────────────────
  Future<void> clearUserData() async {
    await _p.remove(_Keys.userName);
    await _p.remove(_Keys.userEmail);
    debugPrint('🗑 User data cleared');
  }

  Future<void> clearAll() async {
    await _p.clear();
    debugPrint('🗑 All storage cleared');
  }

  Future<void> saveDailyBriefOn(bool v) => _p.setBool('aria_daily_brief_on', v);
  bool loadDailyBriefOn() => _p.getBool('aria_daily_brief_on') ?? false;

  Future<void> resetBriefDismissed() => _p.remove('aria_brief_dismissed');

  Future<void> markBriefHeardToday() => _p.setString(
    'aria_brief_heard',
    DateTime.now().toIso8601String().substring(0, 10),
  );

  bool get isBriefHeardToday {
    final saved = _p.getString('aria_brief_heard') ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return saved == today;
  }

  
}
