class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {}
  Future<void> requestPermissions() async {}
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    int minutesBefore = 10,
  }) async {}
  Future<void> cancelTaskReminder(String taskId) async {}
  Future<void> showFocusStarted({
    required int durationMinutes,
    required String taskTitle,
  }) async {}
  Future<void> dismissFocusNotification() async {}
  Future<void> showFocusCompleted({
    required int completedMinutes,
    required int focusScore,
    required int streak,
  }) async {}
  Future<void> scheduleDailySummary({
    required int taskCount,
    required int highPriorityCount,
  }) async {}
  Future<void> scheduleStreakReminder(int currentStreak) async {}
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {}
  Future<void> cancelAll() async {}
  Future<void> cancel(int id) async {}
}
