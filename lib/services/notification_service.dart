// lib/services/notification_service.dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Notification ID ranges ───────────────────────────────────────────────
  // Tasks 10min before: 1000–1499
  // Tasks at start:     1500–1999
  // Tasks missed:       2000–2499  (was reminders, moved up)
  // Reminders:          3000–3999
  // Focus:              4000, 4001
  // Summary:            5000
  // Streak:             6000
  static const int _focusActiveId = 4000;
  static const int _focusCompletedId = 4001;
  static const int _dailySummaryId = 5000;
  static const int _streakId = 6000;

  // ── Android channels ─────────────────────────────────────────────────────
  static const _reminderChannel = AndroidNotificationChannel(
    'aria_reminders',
    'ARIA Reminders',
    description: 'Smart reminders from ARIA',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  static const _focusChannel = AndroidNotificationChannel(
    'aria_focus',
    'Focus Sessions',
    description: 'Focus session notifications',
    importance: Importance.defaultImportance,
  );
  static const _summaryChannel = AndroidNotificationChannel(
    'aria_summary',
    'Daily Summary',
    description: 'Daily productivity summaries',
    importance: Importance.low,
  );

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_reminderChannel);
    await androidPlugin?.createNotificationChannel(_focusChannel);
    await androidPlugin?.createNotificationChannel(_summaryChannel);

    _initialized = true;
  }

  // ── Permissions ───────────────────────────────────────────────────────────
  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    }
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TASK NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Schedule all 3 task notifications:
  /// 1. 10 min before start
  /// 2. At exact start time
  /// 3. 30 min after end time (missed task)
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime, // task start DateTime
    required DateTime taskEndDateTime, // task end DateTime
    int minutesBefore = 10,
  }) async {
    if (kIsWeb || !_initialized) return;

    final now = DateTime.now();

    // 1️⃣ 10 min before start
    final beforeTime = taskDateTime.subtract(Duration(minutes: minutesBefore));
    if (beforeTime.isAfter(now)) {
      final id = 1000 + (taskId.hashCode.abs() % 500);
      await _plugin.zonedSchedule(
        id,
        '⏰ Starting soon: $taskTitle',
        'Starts in $minutesBefore minutes — get ready!',
        tz.TZDateTime.from(beforeTime, tz.local),
        _taskNotifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Scheduled 10min-before for "$taskTitle" at $beforeTime');
    }

    // 2️⃣ At exact start time
    if (taskDateTime.isAfter(now)) {
      final id = 1500 + (taskId.hashCode.abs() % 500);
      await _plugin.zonedSchedule(
        id,
        '🚀 Time to start: $taskTitle',
        'Your task is starting now. Focus up!',
        tz.TZDateTime.from(taskDateTime, tz.local),
        _taskNotifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Scheduled start-time for "$taskTitle" at $taskDateTime');
    }

    // 3️⃣ 30 min after end time (missed task check)
    final missedTime = taskEndDateTime.add(const Duration(minutes: 30));
    if (missedTime.isAfter(now)) {
      final id = 2000 + (taskId.hashCode.abs() % 500);
      await _plugin.zonedSchedule(
        id,
        '😟 Did you miss: $taskTitle?',
        'This task ended 30 minutes ago. Tap to reschedule.',
        tz.TZDateTime.from(missedTime, tz.local),
        _taskNotifDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Scheduled missed-task for "$taskTitle" at $missedTime');
    }
  }

  /// Cancel all 3 notifications for a task (call when task is completed/deleted)
  Future<void> cancelTaskReminder(String taskId) async {
    if (kIsWeb || !_initialized) return;
    final base = taskId.hashCode.abs();
    await _plugin.cancel(1000 + (base % 500)); // 10min before
    await _plugin.cancel(1500 + (base % 500)); // at start
    await _plugin.cancel(2000 + (base % 500)); // missed
    print('Cancelled all notifications for task $taskId');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMART REMINDERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> scheduleReminder({
    required String reminderId,
    required String title,
    required String subtitle,
    required String time, // e.g. "3:00 PM"
  }) async {
    if (kIsWeb || !_initialized) return;

    final scheduledTime = _parseTime(time);
    if (scheduledTime == null) return;

    final id = 3000 + (reminderId.hashCode.abs() % 1000);
    await _plugin.zonedSchedule(
      id,
      title,
      subtitle,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel.id,
          _reminderChannel.name,
          channelDescription: _reminderChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: [
            const AndroidNotificationAction('snooze', 'Snooze 10m'),
            const AndroidNotificationAction('dismiss', 'Dismiss'),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    print('Scheduled reminder "$title" daily at $time');
  }

  Future<void> cancelReminder(String reminderId) async {
    if (kIsWeb || !_initialized) return;
    final id = 3000 + (reminderId.hashCode.abs() % 1000);
    await _plugin.cancel(id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOCUS SESSION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> showFocusStarted({
    required int durationMinutes,
    required String taskTitle,
  }) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.show(
      _focusActiveId,
      '🎯 Focus Session Active',
      '$taskTitle · $durationMinutes min',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _focusChannel.id,
          _focusChannel.name,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> dismissFocusNotification() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(_focusActiveId);
  }

  Future<void> showFocusCompleted({
    required int completedMinutes,
    required int focusScore,
    required int streak,
  }) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(_focusActiveId);
    await _plugin.show(
      _focusCompletedId,
      '✅ Session Complete!',
      '$completedMinutes min · Score $focusScore · 🔥 $streak day streak',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _focusChannel.id,
          _focusChannel.name,
          importance: Importance.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY BRIEFING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> scheduleDailySummary({
    required int taskCount,
    required int highPriorityCount,
  }) async {
    if (kIsWeb || !_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _dailySummaryId,
      '📋 Good morning! Your day ahead',
      '$taskCount tasks · $highPriorityCount high priority',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _summaryChannel.id,
          _summaryChannel.name,
          importance: Importance.low,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAK REMINDER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> scheduleStreakReminder(int currentStreak) async {
    if (kIsWeb || !_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _streakId,
      '🔥 Keep your streak alive!',
      currentStreak > 0
          ? "You're on a $currentStreak day streak — don't break it!"
          : 'Start your focus streak today!',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel.id,
          _reminderChannel.name,
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INSTANT + CANCEL
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel.id,
          _reminderChannel.name,
          importance: Importance.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  NotificationDetails _taskNotifDetails() => NotificationDetails(
    android: AndroidNotificationDetails(
      _reminderChannel.id,
      _reminderChannel.name,
      channelDescription: _reminderChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  tz.TZDateTime? _parseTime(String time) {
    try {
      final parts = time.split(' ');
      final timeParts = parts[0].split(':');
      final isPM = parts[1].toUpperCase() == 'PM';
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return scheduled;
    } catch (e) {
      print('Error parsing time "$time": $e');
      return null;
    }
  }
}
