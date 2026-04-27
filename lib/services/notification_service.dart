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

  static const int _focusActiveId = 4000;
  static const int _focusCompletedId = 4001;
  static const int _dailySummaryId = 5000;
  static const int _streakId = 6000;

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

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;

    tz.initializeTimeZones();
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    try {
      final matched = tz.timeZoneDatabase.locations.entries.firstWhere(
        (e) => e.value.currentTimeZone.offset == offsetHours * 3600000,
        orElse: () => tz.timeZoneDatabase.locations.entries.first,
      );
      tz.setLocalLocation(matched.value);
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
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

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    }
    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    required DateTime taskEndDateTime,
    int minutesBefore = 10,
  }) async {
    if (kIsWeb || !_initialized) return;
    final now = DateTime.now();

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
    }

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
    }

    final missedTime = taskEndDateTime.add(const Duration(minutes: 5));
    if (missedTime.isAfter(now)) {
      final id = 2000 + (taskId.hashCode.abs() % 500);
      await _plugin.zonedSchedule(
        id,
        '⚠️ Did you complete: $taskTitle?',
        'This task just ended. Mark it done or reschedule it!',
        tz.TZDateTime.from(missedTime, tz.local),
        _taskNotifDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (kIsWeb || !_initialized) return;
    final base = taskId.hashCode.abs();
    await _plugin.cancel(1000 + (base % 500));
    await _plugin.cancel(1500 + (base % 500));
    await _plugin.cancel(2000 + (base % 500));
  }

  Future<void> scheduleReminder({
    required String reminderId,
    required String title,
    required String subtitle,
    required String time,
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
          icon: '@drawable/ic_notification',
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
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminder(String reminderId) async {
    if (kIsWeb || !_initialized) return;
    final id = 3000 + (reminderId.hashCode.abs() % 1000);
    await _plugin.cancel(id);
  }

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
          icon: '@drawable/ic_notification',
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
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> scheduleDailySummary({
    required int taskCount,
    required int highPriorityCount,
  }) async {
    if (kIsWeb || !_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
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
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

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
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

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
          icon: '@drawable/ic_notification',
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

  NotificationDetails _taskNotifDetails() => NotificationDetails(
    android: AndroidNotificationDetails(
      _reminderChannel.id,
      _reminderChannel.name,
      channelDescription: _reminderChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
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
