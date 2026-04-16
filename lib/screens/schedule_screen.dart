// lib/screens/schedule_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES FROM PREVIOUS VERSION:
// • TaskStore now reads/writes Firestore instead of local SharedPreferences
// • Removed loadFromStorage() — Firestore streams data automatically
// • Screen subscribes to a live Firestore stream via _taskStream listener
// • toggle() now takes current isDone state to flip it server-side
// • delete() calls Firestore directly — no local list mutation needed
// • add() saves to Firestore and uses the returned doc ID for notifications
// • _hasTasksOn() uses _allTasks list (populated by stream) instead of TaskStore.all
// • No setState() needed after mutations — stream listener handles rebuilds
// • TaskStore._cache kept in sync so dashboard/analytics/profile can read
//   synchronously via TaskStore.all and TaskStore.forDate() without streams
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';

// ─── Task model ───────────────────────────────────────────────────────────────
class ARIATask {
  final String id;
  String title;
  String subtitle;
  String startTime;
  String endTime;
  TaskPriority priority;
  TaskCategory category;
  bool isDone;
  DateTime date;

  ARIATask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.startTime,
    required this.endTime,
    required this.priority,
    required this.category,
    required this.date,
    this.isDone = false,
  });
}

enum TaskPriority { high, medium, low }

enum TaskCategory { work, personal, health, learning }

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
    TaskPriority.high => 'HIGH',
    TaskPriority.medium => 'MEDIUM',
    TaskPriority.low => 'LOW',
  };
  Color get color => switch (this) {
    TaskPriority.high => const Color(0xFFE05C3A),
    TaskPriority.medium => const Color(0xFFF0A500),
    TaskPriority.low => const Color(0xFF34A853),
  };
}

extension TaskCategoryX on TaskCategory {
  String get label => switch (this) {
    TaskCategory.work => 'Work',
    TaskCategory.personal => 'Personal',
    TaskCategory.health => 'Health',
    TaskCategory.learning => 'Learning',
  };
  Color get color => switch (this) {
    TaskCategory.work => AC.purple,
    TaskCategory.personal => const Color(0xFF3B8BD4),
    TaskCategory.health => const Color(0xFF34A853),
    TaskCategory.learning => const Color(0xFFF0A500),
  };
  IconData get icon => switch (this) {
    TaskCategory.work => Icons.work_outline_rounded,
    TaskCategory.personal => Icons.person_outline_rounded,
    TaskCategory.health => Icons.favorite_outline_rounded,
    TaskCategory.learning => Icons.menu_book_rounded,
  };
}

// ─── Persistent Task Store (Firestore-backed) ─────────────────────────────────
class TaskStore {
  // ── In-memory cache kept in sync by the stream ────────────────────────────
  // Other screens (dashboard, analytics, profile) read this synchronously.
  static List<ARIATask> _cache = [];

  // ── Convert ARIATask → Firestore-friendly map ─────────────────────────────
  static Map<String, dynamic> _toFirestore(ARIATask t) => {
    'title': t.title,
    'subtitle': t.subtitle,
    'startTime': t.startTime,
    'endTime': t.endTime,
    'priority': t.priority.name, // 'high' | 'medium' | 'low'
    'category': t.category.name, // 'work' | 'personal' | 'health' | 'learning'
    'isDone': t.isDone,
    'date': t.date.toIso8601String().substring(0, 10), // "2026-04-16"
  };

  // ── Convert Firestore map → ARIATask ──────────────────────────────────────
  static ARIATask fromFirestore(Map<String, dynamic> m) => ARIATask(
    id: m['id'] as String,
    title: m['title'] as String? ?? 'Untitled',
    subtitle: m['subtitle'] as String? ?? '',
    startTime: m['startTime'] as String? ?? '09:00 AM',
    endTime: m['endTime'] as String? ?? '10:00 AM',
    priority: TaskPriority.values.firstWhere(
      (p) => p.name == m['priority'],
      orElse: () => TaskPriority.medium,
    ),
    category: TaskCategory.values.firstWhere(
      (c) => c.name == m['category'],
      orElse: () => TaskCategory.work,
    ),
    isDone: m['isDone'] as bool? ?? false,
    date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
  );

  // ── Live stream — the schedule screen subscribes to this ──────────────────
  // Also keeps _cache in sync so .all and .forDate() always reflect reality.
  static Stream<List<ARIATask>> stream() {
    return FirestoreService.instance.tasksStream().map((list) {
      final tasks = list.map(fromFirestore).toList();
      _cache = tasks; // keep sync cache up to date
      return tasks;
    });
  }

  // ── Synchronous reads used by dashboard / analytics / profile ─────────────
  // These return whatever is currently in the cache.
  // The cache is populated the moment the schedule screen (or any other
  // subscriber) first listens to stream().
  static List<ARIATask> get all => List.unmodifiable(_cache);

  static List<ARIATask> forDate(DateTime date) =>
      _cache
          .where(
            (t) =>
                t.date.year == date.year &&
                t.date.month == date.month &&
                t.date.day == date.day,
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  static bool hasTasksOn(DateTime date) => _cache.any(
    (t) =>
        t.date.year == date.year &&
        t.date.month == date.month &&
        t.date.day == date.day,
  );

  // ── Add a new task to Firestore ───────────────────────────────────────────
  static Future<void> add(ARIATask task) async {
    final data = _toFirestore(task);

    // Save to Firestore — get the real doc ID back
    final firestoreId = await FirestoreService.instance.saveTask(
      title: data['title'],
      subtitle: data['subtitle'],
      startTime: data['startTime'],
      endTime: data['endTime'],
      priority: data['priority'],
      category: data['category'],
      date: data['date'],
      isDone: data['isDone'],
    );

    // Schedule local notification using the real Firestore doc ID
    if (StorageService.instance.loadNotificationsOn()) {
      final taskTime = _parseTaskDateTime(task.date, task.startTime);
      if (taskTime != null) {
        await NotificationService.instance.scheduleTaskReminder(
          taskId: firestoreId,
          taskTitle: task.title,
          taskDateTime: taskTime,
          minutesBefore: 10,
        );
      }
    }
  }

  // ── Toggle isDone — flips current value on Firestore ─────────────────────
  static Future<void> toggle(String id, bool currentDone) async {
    await FirestoreService.instance.updateTaskCompletion(id, !currentDone);
    // If task just got marked done, cancel its scheduled notification
    if (!currentDone) {
      await NotificationService.instance.cancelTaskReminder(id);
    }
  }

  // ── Delete a task from Firestore ──────────────────────────────────────────
  static Future<void> delete(String id) async {
    await FirestoreService.instance.deleteTask(id);
    await NotificationService.instance.cancelTaskReminder(id);
  }

  // ── Parse "10:30 AM" string into full DateTime ────────────────────────────
  static DateTime? _parseTaskDateTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}

// ─── Schedule Screen ──────────────────────────────────────────────────────────
class ARIAScheduleScreen extends StatefulWidget {
  final String userName;
  const ARIAScheduleScreen({super.key, required this.userName});

  @override
  State<ARIAScheduleScreen> createState() => _ARIAScheduleScreenState();
}

class _ARIAScheduleScreenState extends State<ARIAScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime.now();

  // Search state
  bool _searchMode = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Live task list — populated by Firestore stream
  List<ARIATask> _allTasks = [];

  // Stream — declared as field so the same instance is reused
  late final Stream<List<ARIATask>> _taskStream = TaskStore.stream();

  @override
  void initState() {
    super.initState();
    // Subscribe to live Firestore stream — any change auto-rebuilds the UI
    // The stream also keeps TaskStore._cache in sync for other screens
    _taskStream.listen((tasks) {
      if (mounted) setState(() => _allTasks = tasks);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Computed getters using live _allTasks list ────────────────────────────
  List<ARIATask> get _tasks {
    return _allTasks
        .where(
          (t) =>
              t.date.year == _selectedDate.year &&
              t.date.month == _selectedDate.month &&
              t.date.day == _selectedDate.day,
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  bool _hasTasksOn(DateTime date) => _allTasks.any(
    (t) =>
        t.date.year == date.year &&
        t.date.month == date.month &&
        t.date.day == date.day,
  );

  List<ARIATask> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return _allTasks
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.subtitle.toLowerCase().contains(q) ||
              t.category.label.toLowerCase().contains(q),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  int get _doneCount => _tasks.where((t) => t.isDone).length;
  int get _totalCount => _tasks.length;

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  String _monthName(int m) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m];

  String _fullDayName(int wd) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][wd - 1];

  List<DateTime?> _calendarDays() {
    final first = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final last = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final offset = first.weekday - 1;
    final days = <DateTime?>[];
    for (int i = 0; i < offset; i++) days.add(null);
    for (int d = 1; d <= last.day; d++) {
      days.add(DateTime(_calendarMonth.year, _calendarMonth.month, d));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientGlow()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        if (_searchMode) ...[
                          _buildSearchResults(),
                        ] else ...[
                          _buildCalendar(),
                          const SizedBox(height: 24),
                          _buildDayHeader(),
                          const SizedBox(height: 14),
                          if (_tasks.isEmpty)
                            _buildEmptyState()
                          else ...[
                            _buildProgressBar(),
                            const SizedBox(height: 16),
                            ..._tasks.map((t) => _buildTaskCard(t)),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // FAB — Add Task
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 90,
            right: 20,
            child: GestureDetector(
              onTap: _showAddTaskSheet,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AC.purple, AC.purpleDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AC.purpleShadow1,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _searchMode
              ? Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AC.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AC.purpleBorder),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: GoogleFonts.spaceGrotesk(
                          color: AC.hint,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AC.iconTint,
                          size: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                )
              : Text(
                  'Schedule',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _searchMode = !_searchMode;
                  if (!_searchMode) {
                    _searchQuery = '';
                    _searchCtrl.clear();
                  }
                }),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _searchMode ? AC.purple.withOpacity(0.2) : AC.card,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: _searchMode ? AC.purpleBorder : AC.cardBorder,
                    ),
                  ),
                  child: Icon(
                    _searchMode ? Icons.close_rounded : Icons.search_rounded,
                    color: _searchMode ? AC.purple : Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = DateTime.now();
                  _calendarMonth = DateTime.now();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AC.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AC.purpleBorder),
                  ),
                  child: Text(
                    'Today',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.purple,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CALENDAR ──────────────────────────────────────────────────────────────
  Widget _buildCalendar() {
    final days = _calendarDays();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AC.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                  ),
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AC.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AC.cardBorder),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Text(
                '${_monthName(_calendarMonth.month)} ${_calendarMonth.year}',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                  ),
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AC.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AC.cardBorder),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.spaceGrotesk(
                          color: AC.bodyText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              if (day == null) return const SizedBox();
              final isSelected = _isSameDay(day, _selectedDate);
              final isToday = _isToday(day);
              // Uses local _allTasks — reflects Firestore in real time
              final hasTasks = _hasTasksOn(day);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AC.purple
                        : isToday
                        ? AC.purpleGlow
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected
                        ? Border.all(color: AC.purpleBorder, width: 1)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: GoogleFonts.spaceGrotesk(
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? AC.purple
                              : AC.bodyText,
                          fontSize: 13,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (hasTasks && !isSelected)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isToday ? AC.purple : AC.mutedText,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── DAY HEADER ────────────────────────────────────────────────────────────
  Widget _buildDayHeader() {
    final isToday = _isToday(_selectedDate);
    final isTomorrow = _isSameDay(
      _selectedDate,
      DateTime.now().add(const Duration(days: 1)),
    );
    String label;
    if (isToday) {
      label = 'Today';
    } else if (isTomorrow) {
      label = 'Tomorrow';
    } else {
      label = _fullDayName(_selectedDate.weekday);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
              style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 12),
            ),
          ],
        ),
        if (_totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AC.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AC.purpleBorder),
            ),
            child: Text(
              '$_doneCount / $_totalCount done',
              style: GoogleFonts.spaceGrotesk(
                color: AC.purple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ── PROGRESS BAR ──────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final pct = _totalCount == 0 ? 0.0 : _doneCount / _totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AC.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Progress',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 13,
                ),
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AC.bg,
              valueColor: const AlwaysStoppedAnimation(AC.purple),
            ),
          ),
        ],
      ),
    );
  }

  // ── TASK CARD ─────────────────────────────────────────────────────────────
  Widget _buildTaskCard(ARIATask task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(task.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFE05C3A).withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFE05C3A),
            size: 24,
          ),
        ),
        onDismissed: (_) {
          // Delete from Firestore — stream listener will rebuild the list
          TaskStore.delete(task.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AC.card,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Text(
                'Task deleted',
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
              ),
            ),
          );
        },
        child: GestureDetector(
          onTap: () => _showTaskDetail(task),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: task.isDone ? AC.card.withOpacity(0.5) : AC.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: task.isDone
                    ? AC.cardBorder
                    : task.priority.color.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 52,
                  decoration: BoxDecoration(
                    color: task.isDone ? AC.cardBorder : task.priority.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: task.category.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: task.category.color.withOpacity(0.25),
                    ),
                  ),
                  child: Icon(
                    task.category.icon,
                    color: task.isDone ? AC.iconTint : task.category.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.spaceGrotesk(
                          color: task.isDone ? AC.mutedText : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AC.mutedText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: AC.iconTint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.startTime} – ${task.endTime}',
                            style: GoogleFonts.spaceGrotesk(
                              color: AC.bodyText,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: task.priority.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.priority.label,
                              style: GoogleFonts.spaceGrotesk(
                                color: task.isDone
                                    ? AC.mutedText
                                    : task.priority.color,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Checkbox — toggle passes current isDone so Firestore can flip it
                GestureDetector(
                  onTap: () {
                    TaskStore.toggle(task.id, task.isDone);
                    // No setState needed — stream listener handles the rebuild
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isDone ? AC.purple : Colors.transparent,
                      border: Border.all(
                        color: task.isDone ? AC.purple : AC.cardBorder,
                        width: 1.5,
                      ),
                    ),
                    child: task.isDone
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── SEARCH RESULTS ────────────────────────────────────────────────────────
  Widget _buildSearchResults() {
    final results = _searchResults;
    if (_searchQuery.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_rounded, color: AC.iconTint, size: 40),
              const SizedBox(height: 12),
              Text(
                'Start typing to search tasks',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, color: AC.iconTint, size: 40),
              const SizedBox(height: 12),
              Text(
                'No tasks found for "$_searchQuery"',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${results.length} result${results.length == 1 ? "" : "s"} for "$_searchQuery"',
            style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 12),
          ),
        ),
        ...results.map((t) => _buildTaskCard(t)),
      ],
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AC.card,
                shape: BoxShape.circle,
                border: Border.all(color: AC.cardBorder),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AC.iconTint,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks for this day',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add a new task',
              style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── TASK DETAIL SHEET ─────────────────────────────────────────────────────
  void _showTaskDetail(ARIATask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        onToggle: () {
          TaskStore.toggle(task.id, task.isDone);
        },
        onDelete: () {
          Navigator.pop(context);
          TaskStore.delete(task.id);
        },
      ),
    );
  }

  // ── ADD TASK SHEET ────────────────────────────────────────────────────────
  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(
        selectedDate: _selectedDate,
        onAdd: (task) {
          // Save to Firestore — stream will add it to the list automatically
          TaskStore.add(task);
        },
      ),
    );
  }
}

// ─── Task Detail Sheet ────────────────────────────────────────────────────────
class _TaskDetailSheet extends StatelessWidget {
  final ARIATask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskDetailSheet({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AC.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AC.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: task.category.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: task.category.color.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  task.category.icon,
                  color: task.category.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.category.label,
                      style: GoogleFonts.spaceGrotesk(
                        color: task.category.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      task.title,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            task.subtitle,
            style: GoogleFonts.spaceGrotesk(
              color: AC.bodyText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoChip(
                Icons.access_time_rounded,
                '${task.startTime} – ${task.endTime}',
                AC.purple,
              ),
              const SizedBox(width: 10),
              _infoChip(
                Icons.flag_rounded,
                task.priority.label,
                task.priority.color,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    onToggle();
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AC.purple, AC.purpleDeep],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: AC.purpleShadow2,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        task.isDone ? 'Mark Incomplete' : 'Mark Complete',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05C3A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE05C3A).withOpacity(0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE05C3A),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Task Sheet ───────────────────────────────────────────────────────────
class _AddTaskSheet extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(ARIATask) onAdd;

  const _AddTaskSheet({required this.selectedDate, required this.onAdd});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  TaskCategory _category = TaskCategory.work;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    widget.onAdd(
      ARIATask(
        // Temporary local ID — Firestore will assign the real one
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim().isEmpty
            ? 'No description'
            : _subtitleCtrl.text.trim(),
        startTime: _fmt(_start),
        endTime: _fmt(_end),
        priority: _priority,
        category: _category,
        date: widget.selectedDate,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AC.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'New Task',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _sheetField(_titleCtrl, 'Task title', Icons.title_rounded),
            const SizedBox(height: 12),
            _sheetField(
              _subtitleCtrl,
              'Description (optional)',
              Icons.notes_rounded,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _timePicker(
                    'Start',
                    _start,
                    (t) => setState(() => _start = t),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _timePicker(
                    'End',
                    _end,
                    (t) => setState(() => _end = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Priority',
              style: GoogleFonts.spaceGrotesk(
                color: AC.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: TaskPriority.values.map((p) {
                final sel = p == _priority;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? p.color.withOpacity(0.18) : AC.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? p.color : AC.cardBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          p.label,
                          style: GoogleFonts.spaceGrotesk(
                            color: sel ? p.color : AC.bodyText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: GoogleFonts.spaceGrotesk(
                color: AC.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: TaskCategory.values.map((c) {
                final sel = c == _category;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? c.color.withOpacity(0.15) : AC.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? c.color : AC.cardBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            c.icon,
                            color: sel ? c.color : AC.iconTint,
                            size: 16,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            c.label,
                            style: GoogleFonts.spaceGrotesk(
                              color: sel ? c.color : AC.bodyText,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: _save,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AC.purple, AC.purpleDeep],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: AC.purpleShadow1,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Add Task',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AC.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.inputBorder),
      ),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: AC.hint, fontSize: 14),
          prefixIcon: Icon(icon, color: AC.iconTint, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _timePicker(
    String label,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onPick,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AC.purple),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AC.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.inputBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AC.iconTint, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.bodyText,
                    fontSize: 10,
                  ),
                ),
                Text(
                  _fmt(time),
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
