// ignore_for_file: unnecessary_underscores, unused_element_parameter, unused_element, unused_import

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../services/firestore_service.dart';

// ─── Palette (matches app theme) ──────────────────────────────────────────────
const Color _bg = Color(0xFF0E0B1E);
const Color _card = Color(0x1AFFFFFF);
const Color _glass = Color(0x14FFFFFF);
const Color _glassBorder = Color(0x28FFFFFF);
const Color _violet = Color(0xFF8A6CD1);
const Color _violetGlow = Color(0xFF4D3385);
const Color _mint = Color(0xFF3DD68C);
const Color _rose = Color(0xFFFF6B8A);
const Color _amber = Color(0xFFFFB347);
const Color _blue = Color(0xFF5B9CF6);

// ─── Reminder model ───────────────────────────────────────────────────────────
enum ReminderType { focusTime, breakTime, meeting, habit, custom }

enum ReminderPriority { high, medium, low }

class _Reminder {
  final String id, title, subtitle, time;
  final ReminderType type;
  final ReminderPriority priority;
  final bool isAISuggested;
  bool isEnabled;
  bool isDismissed;

  _Reminder({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.priority,
    this.isAISuggested = false,
    this.isEnabled = true,
    this.isDismissed = false,
  });

  // ── ADD THIS ──
  factory _Reminder.fromFirestore(Map<String, dynamic> data) {
    final typeMap = {
      'focusTime': ReminderType.focusTime,
      'breakTime': ReminderType.breakTime,
      'meeting': ReminderType.meeting,
      'habit': ReminderType.habit,
      'custom': ReminderType.custom,
    };
    final priorityMap = {
      'high': ReminderPriority.high,
      'medium': ReminderPriority.medium,
      'low': ReminderPriority.low,
    };
    return _Reminder(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      time: data['time'] ?? '',
      type: typeMap[data['type']] ?? ReminderType.custom,
      priority: priorityMap[data['priority']] ?? ReminderPriority.medium,
      isAISuggested: data['isAISuggested'] ?? false,
      isEnabled: data['isEnabled'] ?? true,
    );
  }
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with TickerProviderStateMixin {
  // ── Animations
  late final AnimationController _nebulaCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final AnimationController _breathCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final AnimationController _bellCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final AnimationController _alarmCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final Animation<double> _nebula = CurvedAnimation(
    parent: _nebulaCtrl,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _breath = CurvedAnimation(
    parent: _breathCtrl,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _bellSwing = Tween<double>(
    begin: -0.18,
    end: 0.18,
  ).animate(CurvedAnimation(parent: _bellCtrl, curve: Curves.elasticInOut));
  late final Animation<double> _alarmScale = Tween<double>(
    begin: 0.85,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.easeOutBack));
  late final Animation<double> _pulse = CurvedAnimation(
    parent: _pulseCtrl,
    curve: Curves.easeInOut,
  );

  // ── State
  bool _showAlarmOverlay = false;
  _Reminder? _activeAlarm;
  int _selectedTab = 0; // 0=All, 1=Today, 2=AI

  // ── Data
  List<_Reminder> _reminders = [];

  List<_Reminder> get _filteredReminders {
    switch (_selectedTab) {
      case 1: // Today — show all enabled
        return _reminders.where((r) => !r.isDismissed && r.isEnabled).toList();
      case 2: // AI suggested
        return _reminders
            .where((r) => r.isAISuggested && !r.isDismissed)
            .toList();
      default:
        return _reminders.where((r) => !r.isDismissed).toList();
    }
  }

  void _triggerAlarm(_Reminder reminder) {
    HapticFeedback.heavyImpact();
    setState(() {
      _activeAlarm = reminder;
      _showAlarmOverlay = true;
    });
    _bellCtrl.repeat(reverse: true);
    _alarmCtrl.forward();
  }

  void _dismissAlarm() {
    HapticFeedback.mediumImpact();
    _bellCtrl.stop();
    _bellCtrl.reset();
    _alarmCtrl.reverse().then((_) {
      if (mounted) setState(() => _showAlarmOverlay = false);
    });
  }

  void _snoozeAlarm() {
    HapticFeedback.selectionClick();
    _dismissAlarm();
  }

  void _toggleReminder(String id) {
    HapticFeedback.selectionClick();
    final r = _reminders.firstWhere((r) => r.id == id);
    final newValue = !r.isEnabled;
    setState(() => r.isEnabled = newValue); // optimistic UI update
    FirestoreService.instance.toggleReminder(id, newValue); // sync to Firestore
  }

  void _dismissReminder(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      _reminders.firstWhere((r) => r.id == id).isDismissed = true;
    });
    FirestoreService.instance.deleteReminder(
      id,
    ); // permanently delete from Firestore
  }

  Color _typeColor(ReminderType type) => switch (type) {
    ReminderType.focusTime => _violet,
    ReminderType.breakTime => _mint,
    ReminderType.meeting => _blue,
    ReminderType.habit => _amber,
    ReminderType.custom => _rose,
  };

  IconData _typeIcon(ReminderType type) => switch (type) {
    ReminderType.focusTime => Icons.timer_rounded,
    ReminderType.breakTime => Icons.free_breakfast_rounded,
    ReminderType.meeting => Icons.people_rounded,
    ReminderType.habit => Icons.favorite_border_rounded,
    ReminderType.custom => Icons.notifications_rounded,
  };

  String _typeLabel(ReminderType type) => switch (type) {
    ReminderType.focusTime => 'Focus',
    ReminderType.breakTime => 'Break',
    ReminderType.meeting => 'Meeting',
    ReminderType.habit => 'Habit',
    ReminderType.custom => 'Custom',
  };

  Color _priorityColor(ReminderPriority p) => switch (p) {
    ReminderPriority.high => _rose,
    ReminderPriority.medium => _amber,
    ReminderPriority.low => _mint,
  };

  // ── ADD THIS BLOCK right before your dispose() method ──
  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() {
    FirestoreService.instance.remindersStream().listen((data) {
      if (!mounted) return;
      setState(() {
        _reminders = data.map((d) => _Reminder.fromFirestore(d)).toList();
      });
    });
  }

  @override
  void dispose() {
    _nebulaCtrl.dispose();
    _breathCtrl.dispose();
    _bellCtrl.dispose();
    _alarmCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Nebula bg
          AnimatedBuilder(
            animation: _nebula,
            builder: (_, __) => CustomPaint(
              painter: _NebulaPainter(_nebula.value),
              child: const SizedBox.expand(),
            ),
          ),
          // Grain
          Positioned.fill(child: CustomPaint(painter: _GrainPainter())),

          Column(
            children: [
              SafeArea(bottom: false, child: _buildTopBar()),
              _buildHeader(),
              _buildTabs(),
              Expanded(child: _buildReminderList()),
            ],
          ),

          // FAB
          Positioned(
            bottom: 24,
            right: 20,
            child: SafeArea(child: _buildFAB()),
          ),

          // Alarm overlay
          if (_showAlarmOverlay) _buildAlarmOverlay(),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: _glass,
              border: Border.all(color: _glassBorder),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 16,
            ),
          ),
        ),
        Text(
          'Reminders',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        GestureDetector(
          onTap: () => _triggerAlarm(_reminders.first),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: _glass,
              border: Border.all(color: _glassBorder),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 18,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Header with bell ──────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _pulse]),
      builder: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            // Animated bell icon
            GestureDetector(
              onTap: () {
                _bellCtrl.forward(from: 0).then((_) => _bellCtrl.reverse());
              },
              child: AnimatedBuilder(
                animation: _bellSwing,
                builder: (_, child) => Transform.rotate(
                  angle: _bellCtrl.isAnimating ? _bellSwing.value : 0,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow bloom
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _violet.withValues(
                              alpha: 0.25 + 0.15 * _breath.value,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _violet.withValues(alpha: 0.15),
                        border: Border.all(
                          color: _violet.withValues(
                            alpha: 0.3 + 0.15 * _pulse.value,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _violet.withValues(
                              alpha: 0.3 + 0.2 * _pulse.value,
                            ),
                            blurRadius: 16 + 8 * _pulse.value,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.notifications_rounded,
                        color: _violet,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Reminders',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_reminders.where((r) => r.isEnabled && !r.isDismissed).length} active · '
                    '${_reminders.where((r) => r.isAISuggested).length} AI-suggested',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // ARIA AI badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _violet.withValues(alpha: 0.12),
                border: Border.all(color: _violet.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: _violet, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    'ARIA',
                    style: GoogleFonts.spaceGrotesk(
                      color: _violet,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────────
  Widget _buildTabs() {
    const tabs = ['All', 'Today', 'AI Picks'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final selected = e.key == _selectedTab;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedTab = e.key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected ? _violet.withValues(alpha: 0.2) : _glass,
                border: Border.all(
                  color: selected
                      ? _violet.withValues(alpha: 0.5)
                      : _glassBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                e.value,
                style: GoogleFonts.spaceGrotesk(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Reminder list ─────────────────────────────────────────────────────────────
  Widget _buildReminderList() {
    final items = _filteredReminders;
    if (items.isEmpty) return _buildEmptyState();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: items.length,
      itemBuilder: (_, i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + i * 60),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: child,
            ),
          ),
          child: _buildReminderCard(items[i]),
        );
      },
    );
  }

  Widget _buildReminderCard(_Reminder r) {
    final color = _typeColor(r.type);
    final dimmed = !r.isEnabled;

    return Dismissible(
      key: Key(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _rose.withValues(alpha: 0.2),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: _rose, size: 22),
      ),
      onDismissed: (_) => _dismissReminder(r.id),
      child: GestureDetector(
        onTap: () => _triggerAlarm(r),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: dimmed ? 0.4 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _glass,
              border: Border.all(
                color: r.isEnabled
                    ? color.withValues(alpha: 0.2)
                    : _glassBorder,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Type icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: color.withValues(alpha: 0.12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(_typeIcon(r.type), color: color, size: 20),
                      ),
                      const SizedBox(width: 14),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.title,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (r.isAISuggested)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: _violet.withValues(alpha: 0.15),
                                    ),
                                    child: Text(
                                      'AI',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: _violet,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              r.subtitle,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Time
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white.withValues(alpha: 0.07),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                        size: 11,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        r.time,
                                        style: GoogleFonts.spaceGrotesk(
                                          color: Colors.white.withValues(
                                            alpha: 0.55,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Type label
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: color.withValues(alpha: 0.10),
                                  ),
                                  child: Text(
                                    _typeLabel(r.type),
                                    style: GoogleFonts.spaceGrotesk(
                                      color: color.withValues(alpha: 0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Priority dot
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _priorityColor(r.priority),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _priorityColor(
                                          r.priority,
                                        ).withValues(alpha: 0.6),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Toggle
                      GestureDetector(
                        onTap: () => _toggleReminder(r.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 44,
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            color: r.isEnabled
                                ? _violet
                                : Colors.white.withValues(alpha: 0.08),
                            border: Border.all(
                              color: r.isEnabled
                                  ? _violet
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                            boxShadow: r.isEnabled
                                ? [
                                    BoxShadow(
                                      color: _violet.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: r.isEnabled
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: Colors.white.withValues(alpha: 0.15),
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            'No reminders here',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add one or let ARIA suggest',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return GestureDetector(
      onTap: () => _showAddReminderSheet(),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_violet, _violetGlow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _violet.withValues(alpha: 0.45 + 0.2 * _pulse.value),
                blurRadius: 20 + 8 * _pulse.value,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  // ── Add reminder bottom sheet ─────────────────────────────────────────────────
  void _showAddReminderSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddReminderSheet(
        onAdd: (title, time, type) async {
          // Convert enum to string for Firestore
          final typeStr = type.name; // 'focusTime', 'breakTime', etc.

          await FirestoreService.instance.saveReminder(
            title: title,
            subtitle: 'Custom reminder',
            time: time,
            type: typeStr,
            priority: 'medium',
          );
          setState(() {
            _reminders.insert(
              0,
              _Reminder(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                subtitle: 'Custom reminder',
                time: time,
                type: type,
                priority: ReminderPriority.medium,
              ),
            );
          });
        },
      ),
    );
  }

  // ── Alarm overlay ─────────────────────────────────────────────────────────────
  Widget _buildAlarmOverlay() {
    final r = _activeAlarm!;
    final color = _typeColor(r.type);

    return AnimatedBuilder(
      animation: Listenable.merge([_alarmScale, _bellSwing, _pulse]),
      builder: (_, __) => GestureDetector(
        onTap: _dismissAlarm,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75 * _alarmScale.value),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: _alarmScale.value,
            child: Opacity(
              opacity: _alarmScale.value.clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(
                              alpha: 0.25 + 0.15 * _pulse.value,
                            ),
                            blurRadius: 40 + 20 * _pulse.value,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated bell
                          Transform.rotate(
                            angle: _bellCtrl.isAnimating ? _bellSwing.value : 0,
                            alignment: Alignment.topCenter,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ripple rings
                                ...List.generate(3, (i) {
                                  final scale =
                                      1.0 + i * 0.35 + 0.15 * _pulse.value;
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: color.withValues(
                                            alpha: (0.25 - i * 0.07).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _typeIcon(r.type),
                                    color: color,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Time
                          Text(
                            r.time,
                            style: GoogleFonts.spaceGrotesk(
                              color: color,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            r.title,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _snoozeAlarm,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.snooze_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Snooze 10m',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _dismissAlarm,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: LinearGradient(
                                        colors: [
                                          color,
                                          color.withValues(alpha: 0.7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Got it',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Add Reminder Bottom Sheet ────────────────────────────────────────────────
class _AddReminderSheet extends StatefulWidget {
  final void Function(String title, String time, ReminderType type) onAdd;
  const _AddReminderSheet({required this.onAdd});
  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _titleCtrl = TextEditingController();
  ReminderType _selectedType = ReminderType.focusTime;
  String _selectedTime = '3:00 PM';

  static final _types = [
    (ReminderType.focusTime, Icons.timer_rounded, 'Focus', _violet),
    (ReminderType.breakTime, Icons.free_breakfast_rounded, 'Break', _mint),
    (ReminderType.meeting, Icons.people_rounded, 'Meeting', _blue),
    (ReminderType.habit, Icons.favorite_border_rounded, 'Habit', _amber),
    (ReminderType.custom, Icons.notifications_rounded, 'Custom', _rose),
  ];

  static const _quickTimes = [
    '9:00 AM',
    '10:00 AM',
    '12:00 PM',
    '2:00 PM',
    '4:00 PM',
    '6:00 PM',
    '8:00 PM',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13102A).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(Icons.add_alert_rounded, color: _violet, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'New Reminder',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title input
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: TextField(
                  controller: _titleCtrl,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Reminder title...',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withValues(alpha: 0.25),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Type picker
              Text(
                'TYPE',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 9,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _types.map((t) {
                    final selected = _selectedType == t.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = t.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selected
                              ? t.$4.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: selected
                                ? t.$4.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.10),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t.$2,
                              color: selected
                                  ? t.$4
                                  : Colors.white.withValues(alpha: 0.35),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.$3,
                              style: GoogleFonts.spaceGrotesk(
                                color: selected
                                    ? t.$4
                                    : Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Time picker
              Text(
                'TIME',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 9,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickTimes.map((t) {
                    final selected = _selectedTime == t;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTime = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: selected
                              ? _violet.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: selected
                                ? _violet.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.10),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          t,
                          style: GoogleFonts.spaceGrotesk(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Add button
              GestureDetector(
                onTap: () {
                  final title = _titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  widget.onAdd(title, _selectedTime, _selectedType);
                  Navigator.pop(context);
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [_violet, _violetGlow],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _violet.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Set Reminder',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────
class _NebulaPainter extends CustomPainter {
  final double t;
  _NebulaPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1035), Color(0xFF0E0B1E), Color(0xFF160E2E)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(
        cx * 0.3 + 35 * math.sin(t * math.pi),
        cy * 0.4 + 22 * math.cos(t * math.pi),
      ),
      size.width * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x408A6CD1), const Color(0x008A6CD1)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx * 0.3, cy * 0.4),
                radius: size.width * 0.75,
              ),
            ),
    );
    canvas.drawCircle(
      Offset(
        cx * 1.65 - 22 * math.cos(t * math.pi),
        cy * 0.85 + 18 * math.sin(t * math.pi),
      ),
      size.width * 0.6,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x306B4DA8), const Color(0x006B4DA8)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx * 1.65, cy * 0.85),
                radius: size.width * 0.6,
              ),
            ),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: const Alignment(0, 0.3),
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_NebulaPainter old) => old.t != t;
}

class _GrainPainter extends CustomPainter {
  final _rng = math.Random(99);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.014);
    for (int i = 0; i < 900; i++) {
      canvas.drawCircle(
        Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
        _rng.nextDouble() * 0.7,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter _) => false;
}
