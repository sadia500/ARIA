// lib/screens/focus_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES FROM ORIGINAL:
// • Removed _buildBottomNav() — Focus is a PUSHED route from dashboard,
//   not a tab. Shell nav hides automatically when this screen is pushed.
// • Back navigation: top bar back button added so user can return to shell
// • All other logic unchanged
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: deprecated_member_use, unused_element, unused_field, unnecessary_underscores

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../services/app_blocker_service.dart';
import '../services/ambient_sound_service.dart';
import 'package:flutter/foundation.dart';
import 'schedule_screen.dart';
import '../services/aria_ai_service.dart';

const Color _bg = Color(0xFF0E0B1E); // exact match
const Color _card = Color(0xFF1A1035); // reminders uses this tone
const Color _surface = Color(0xFF211E45);
const Color _cardBorder = Color(0x28FFFFFF); // matches _glassBorder
const Color _green = Color(0xFF34A853);
const Color _amber = Color(0xFFFFAA44);
const Color _red = Color(0xFFEF4444);

enum _ScreenState { energyPick, aiSuggestion, session, reflection }

enum _Energy { high, medium, low }

class FocusScreen extends StatefulWidget {
  final String initialTask;
  const FocusScreen({
    super.key,
    this.initialTask = 'Finalize architectural proposal for Project Nova',
  });
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _ScreenState _screen = _ScreenState.energyPick;
  _Energy? _energy;

  int _totalSeconds = 30 * 60;
  int _remaining = 30 * 60;
  bool _isRunning = false;
  Timer? _timer;
  Timer? _distractTimer;

  int _distractions = 0;
  int _focusScore = 100;
  int _streak = 7;
  int _uninterruptedSec = 0;
  late String _activeTask;

  bool _focusShield = false;
  AmbientSound _selectedSound = AmbientSoundService.sounds.first;

  int? _reflectionRating;
  double _mediaVolume = 0.6;

  bool _pendingSessionStart = false;
  String _sessionRemark = '';
  StreamSubscription<List<ARIATask>>? _taskSub;
  String _focusInsight = '';

  static const _sounds = ['Rain', 'Instrumental', 'Minimal', 'Silent'];
  static const _soundIcons = [
    Icons.water_drop_outlined,
    Icons.music_note_outlined,
    Icons.waves_outlined,
    Icons.do_not_disturb_on_outlined,
  ];

  static const _aiMessages = [
    'This is usually your most productive time of day.',
    'You\'ve completed 3 sessions today — great momentum.',
    'Your focus peaks between 9AM–12PM. Use this time well.',
  ];
  int _aiMsgIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeTask = widget.initialTask;

    _taskSub = TaskStore.stream().listen((_) {
      if (mounted) setState(() {});
    });
  }

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final AnimationController _enterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  late final AnimationController _overlayCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final Animation<double> _pulse = Tween<double>(
    begin: 0.3,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  late final Animation<double> _glow = Tween<double>(
    begin: 0.4,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  late final Animation<double> _enter = CurvedAnimation(
    parent: _enterCtrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _overlay = CurvedAnimation(
    parent: _overlayCtrl,
    curve: Curves.easeOutBack,
  );
  Timer? _volumeTimer;
  Future<void> _setVolume(double value) async {
    setState(() => _mediaVolume = value);
    AmbientSoundService.instance.setVolume(value);
  }

  String get _timeString {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => 1.0 - (_remaining / _totalSeconds);

  String get _energyLabel => switch (_energy) {
    _Energy.high => 'High Energy',
    _Energy.medium => 'Medium Energy',
    _Energy.low => 'Low Energy',
    null => '',
  };

  Color get _energyColor => switch (_energy) {
    _Energy.high => _green,
    _Energy.medium => AC.purple,
    _Energy.low => _amber,
    null => AC.purple,
  };

  int get _suggestedMinutes => switch (_energy) {
    _Energy.high => 50,
    _Energy.medium => 30,
    _Energy.low => 15,
    null => 25,
  };

  Color get _focusScoreColor {
    if (_focusScore >= 80) return _green;
    if (_focusScore >= 60) return _amber;
    return _red;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    if (!_pendingSessionStart) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final hasNotif =
          await AppBlockerService.hasNotificationListenerPermission();
      if (!hasNotif) return; // still missing notification permission

      final hasAccessibility =
          await AppBlockerService.hasAccessibilityPermission();
      if (!hasAccessibility) {
        // Notification done, now ask accessibility
        _showAccessibilityPermissionDialog();
        return;
      }
    }

    // All permissions granted
    setState(() {
      _pendingSessionStart = false;
      _focusShield = true; // auto turn ON shield
    });

    await AppBlockerService.enableNotificationBlocking();
    await AppBlockerService.startAppBlocking();
  }

  Future<void> _loadFocusInsight() async {
    final energyStr = switch (_energy) {
      _Energy.high => 'high',
      _Energy.medium => 'medium',
      _Energy.low => 'low',
      null => 'medium',
    };
    final insight = await AriaAIService().generateSessionInsight(
      energyLevel: energyStr,
      taskName: _activeTask,
    );
    if (mounted) setState(() => _focusInsight = insight);
  }

  void _pickEnergy(_Energy e) {
    HapticFeedback.mediumImpact();
    setState(() {
      _energy = e;
      _totalSeconds = _suggestedMinutes * 60;
      _remaining = _totalSeconds;
      _aiMsgIndex = DateTime.now().hour % _aiMessages.length;
    });
    _transition(_ScreenState.aiSuggestion);
    _loadFocusInsight();
  }

  void _transition(_ScreenState next) {
    _enterCtrl.reset();
    setState(() => _screen = next);
    _enterCtrl.forward();
  }

  void _startSession() async {
    HapticFeedback.mediumImpact();

    try {
      if (_focusShield) {
        await AppBlockerService.enableNotificationBlocking();
        await AppBlockerService.startAppBlocking();
      }
    } catch (e) {
      debugPrint('Shield error: $e');
    }

    AmbientSoundService.instance.play(_selectedSound);
    _transition(_ScreenState.session);
    setState(() {
      _isRunning = true;
      _focusScore = 100;
    });
    _startTick();
    NotificationService.instance.showFocusStarted(
      durationMinutes: _suggestedMinutes,
      taskTitle: _activeTask,
    );
  }

  void _startTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining > 0) {
        setState(() {
          _remaining--;
          _uninterruptedSec++;
        });
      } else {
        _completeSession();
      }
    });
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _startTick();
      AmbientSoundService.instance.resume(); // 🎵 resume sound
    } else {
      _timer?.cancel();
      AmbientSoundService.instance.pause(); // 🎵 pause sound
      setState(() {
        _distractions++;
        _focusScore = math.max(0, _focusScore - 8);
        _uninterruptedSec = 0;
      });
    }
  }

  void _stopSession() {
    HapticFeedback.heavyImpact();
    _timer?.cancel();
    _distractTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
    _overlayCtrl.forward();
  }

  void _completeSession() {
    _timer?.cancel();
    _distractTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _isRunning = false;
      _streak++;
    });

    AmbientSoundService.instance.stop();

    final completedMin = (_totalSeconds - _remaining) ~/ 60;
    NotificationService.instance.showFocusCompleted(
      completedMinutes: completedMin,
      focusScore: _focusScore,
      streak: _streak,
    );
    StorageService.instance.addFocusSession(completedMin);
    _transition(_ScreenState.reflection);

    try {
      if (_focusShield) {
        AppBlockerService.disableNotificationBlocking();
        AppBlockerService.stopAppBlocking();
      }
    } catch (e) {
      debugPrint('Stop error: $e');
    }

    // After _transition(_ScreenState.reflection);
    _loadSessionRemark();
  }

  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Allow Notification Access',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'ARIA needs Notification Access to silently block distracting notifications during focus sessions. Your volume is never affected.',
          style: GoogleFonts.spaceGrotesk(color: const Color(0x99FFFFFF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(color: const Color(0x66FFFFFF)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _pendingSessionStart = true); // 🆕
              await Future.delayed(const Duration(milliseconds: 300));
              await AppBlockerService.requestNotificationListenerPermission();
            },
            child: Text(
              'Open Settings',
              style: GoogleFonts.spaceGrotesk(color: AC.purple),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Enable App Blocking',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'ARIA needs Accessibility permission to block distracting apps during focus sessions. Find "ARIA Focus Blocker" in the list and enable it.',
          style: GoogleFonts.spaceGrotesk(color: const Color(0x99FFFFFF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(color: const Color(0x66FFFFFF)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _pendingSessionStart = true); // 🆕
              await Future.delayed(const Duration(milliseconds: 300));
              await AppBlockerService.requestAccessibilityPermission();
            },
            child: Text(
              'Open Settings',
              style: GoogleFonts.spaceGrotesk(color: AC.purple),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSessionRemark() async {
    final energyStr = switch (_energy) {
      _Energy.high => 'high',
      _Energy.medium => 'medium',
      _Energy.low => 'low',
      null => 'medium',
    };
    final completedMin = (_totalSeconds - _remaining) ~/ 60;
    final totalMin = _totalSeconds ~/ 60;
    final remark = await AriaAIService().generateSessionRemark(
      taskName: _activeTask,
      completedMin: completedMin,
      totalMin: totalMin,
      focusScore: _focusScore,
      distractions: _distractions,
      energyLevel: energyStr,
    );
    if (mounted) setState(() => _sessionRemark = remark);
  }

  void _submitReflection(int rating) async {
    HapticFeedback.selectionClick();
    setState(() {
      _reflectionRating = rating;
      _sessionRemark = '';
    });

    // Convert rating number to string
    final reflectionStr = switch (rating) {
      0 => 'great',
      1 => 'okay',
      _ => 'distracted',
    };

    // Convert energy to string
    final energyStr = switch (_energy) {
      _Energy.high => 'high',
      _Energy.medium => 'medium',
      _Energy.low => 'low',
      null => 'medium',
    };

    // Save session to Firestore
    try {
      await FirestoreService.instance.saveSession(
        energy: energyStr,
        durationMinutes: _suggestedMinutes,
        focusScore: _focusScore,
        distractions: _distractions,
        reflection: reflectionStr,
        taskName: _activeTask,
      );
    } catch (e, stackTrace) {
      debugPrint('Error saving session: $e');
      debugPrint('StackTrace: $stackTrace');
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _screen = _ScreenState.energyPick;
        _energy = null;
        _remaining = 30 * 60;
        _totalSeconds = 30 * 60;
        _isRunning = false;
        _distractions = 0;
        _focusScore = 100;
        _uninterruptedSec = 0;
        _reflectionRating = null;
      });
    });
  }

  void _dismissStopOverlay() => _overlayCtrl.reverse();

  void _confirmStop() {
    AmbientSoundService.instance.stop();
    _overlayCtrl.reverse().then((_) => _transition(_ScreenState.reflection));
    try {
      if (_focusShield) {
        AppBlockerService.disableNotificationBlocking();
        AppBlockerService.stopAppBlocking();
      }
    } catch (e) {
      debugPrint('Stop error: $e');
    }

    // After _transition(_ScreenState.reflection);
    _loadSessionRemark();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _distractTimer?.cancel();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _enterCtrl.dispose();
    _overlayCtrl.dispose();
    AmbientSoundService.instance.stop(); // 🎵 stop on screen exit
    super.dispose();
    _taskSub?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B1E),
      body: Stack(
        children: [
          _buildBackground(),
          Positioned.fill(child: CustomPaint(painter: _FocusGrainPainter())),
          SafeArea(
            child: AnimatedBuilder(
              animation: _enter,
              builder: (_, child) => Opacity(
                opacity: _enter.value,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - _enter.value)),
                  child: child,
                ),
              ),
              child: _buildCurrentScreen(),
            ),
          ),
          if (_overlayCtrl.value > 0) _buildStopOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => CustomPaint(
        painter: _FocusNebulaPainter(_glow.value),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildCurrentScreen() => switch (_screen) {
    _ScreenState.energyPick => _buildEnergyPick(),
    _ScreenState.aiSuggestion => _buildAISuggestion(),
    _ScreenState.session => _buildSession(),
    _ScreenState.reflection => _buildReflection(),
  };

  // ── STEP 1 — Energy Pick ─────────────────────────────────────────────────
  Widget _buildEnergyPick() {
    return Column(
      children: [
        _buildTopBar(showBack: true),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                // Heading
                Text(
                  'How\'s your energy\nright now?',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ARIA picks the best session length for you.',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withOpacity(0.40),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),
                // Energy cards
                _energyCard(
                  energy: _Energy.high,
                  icon: Icons.bolt_rounded,
                  label: 'High Energy',
                  sub: 'Ready to crush it — 50 min deep work',
                  color: const Color(0xFF3DD68C),
                ),
                const SizedBox(height: 10),
                _energyCard(
                  energy: _Energy.medium,
                  icon: Icons.track_changes_rounded,
                  label: 'Medium Energy',
                  sub: 'Solid focus — 30 min session',
                  color: const Color(0xFF8A6CD1),
                ),
                const SizedBox(height: 10),
                _energyCard(
                  energy: _Energy.low,
                  icon: Icons.nights_stay_rounded,
                  label: 'Low Energy',
                  sub: 'Light work — 15 min gentle session',
                  color: const Color(0xFFFFAA44),
                ),
                const SizedBox(height: 28),
                _buildTaskSelector(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _energyCard({
    required _Energy energy,
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _pickEnergy(energy),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13102A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.40),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: color.withOpacity(0.7),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A6CD1), Color(0x663DD68C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ACTIVE TASK',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showTaskEditSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF13102A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF8A6CD1).withOpacity(0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A6CD1).withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8A6CD1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8A6CD1).withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _activeTask,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8A6CD1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8A6CD1).withOpacity(0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF8A6CD1),
                    size: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTaskEditSheet() {
    final now = DateTime.now();
    final todayTasks = TaskStore.all
        .where(
          (t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day &&
              !t.isDone,
        )
        .toList();

    final ctrl = TextEditingController(text: _activeTask);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF13102A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF8A6CD1).withOpacity(0.28),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'What will you focus on?',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a task or type your own',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                if (todayTasks.isNotEmpty) ...[
                  Text(
                    "TODAY'S TASKS",
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...todayTasks.map((task) {
                    final priorityColor = task.priority == TaskPriority.high
                        ? const Color(0xFFFF6B8A)
                        : task.priority == TaskPriority.medium
                        ? const Color(0xFFFFAA44)
                        : const Color(0xFF3DD68C);
                    final isSelected = _activeTask == task.title;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _activeTask = task.title);
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
    ? const Color(0xFF8A6CD1).withValues(alpha: 0.15)
    : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8A6CD1).withOpacity(0.45)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: priorityColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: priorityColor.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                task.title,
                                style: GoogleFonts.spaceGrotesk(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.75),
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF8A6CD1),
                                size: 16,
                              )
                            else
                              Text(
                                task.startTime,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.08)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR TYPE YOUR OWN',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.08)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8A6CD1).withOpacity(0.30),
                    ),
                  ),
                  child: TextField(
                    controller: ctrl,
                    autofocus: todayTasks.isEmpty,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Review project proposal',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        color: Colors.white.withOpacity(0.22),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (ctrl.text.trim().isNotEmpty) {
                        setState(() => _activeTask = ctrl.text.trim());
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      setState(() => _activeTask = ctrl.text.trim());
                    }
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B3FC8), Color(0xFF8A6CD1)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8A6CD1).withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Set Task',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── STEP 2 — AI Suggestion ───────────────────────────────────────────────
  Widget _buildAISuggestion() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AC.purple.withValues(alpha: 0.2),
                        AC.purpleDeep.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: AC.purple.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AC.purple.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AC.purple,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ARIA INSIGHT',
                            style: GoogleFonts.spaceGrotesk(
                              color: AC.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _focusInsight.isEmpty
                          ? Text(
                              'Preparing your session insight...',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white.withOpacity(0.40),
                                fontSize: 14,
                              ),
                            )
                          : Text(
                              _focusInsight,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        'Consider starting with: "$_activeTask"',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0x80FFFFFF),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _card,
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR SESSION',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0x55FFFFFF),
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _sessionStat(_energyLabel, 'Energy', _energyColor),
                          _vDivider(),
                          _sessionStat(
                            '$_suggestedMinutes min',
                            'Duration',
                            Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildAmbientPicker(),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _startSession,
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [AC.purple, AC.purpleDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AC.purple.withValues(alpha: 0.5),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Begin Focus Session',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() => _focusInsight = ''); // ← add this
                    _transition(_ScreenState.energyPick);
                  },
                  child: Center(
                    child: Text(
                      '← Change energy level',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0x55FFFFFF),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sessionStat(String value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0x55FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 32,
    color: const Color(0x15FFFFFF),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  Widget _buildAmbientPicker() {
    final sounds = AmbientSoundService.sounds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AMBIENT SOUND',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0x55FFFFFF),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(sounds.length, (i) {
            final sound = sounds[i];
            final sel = _selectedSound.id == sound.id;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSound = sound);
                  AmbientSoundService.instance.play(sound);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: i < sounds.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: sel ? AC.purple.withValues(alpha: 0.18) : _surface,
                    border: Border.all(
                      color: sel
                          ? AC.purple.withValues(alpha: 0.5)
                          : _cardBorder,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(sound.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(
                        sound.name,
                        style: GoogleFonts.spaceGrotesk(
                          color: sel ? AC.purple : const Color(0x55FFFFFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── STEP 3 — Session ─────────────────────────────────────────────────────
  Widget _buildSession() {
    return Column(
      children: [
        _buildSessionTopBar(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24), // more space above ring
              _buildTimerRing(),
              const SizedBox(height: 6),
              _buildActiveTaskCard(),
              const Spacer(),
              // Focus stability moved near shield
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildFocusPulse(),
              ),
              const SizedBox(height: 8),
              _buildFocusShield(),
              const SizedBox(height: 20),
              _buildForestControls(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTopBar() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRunning ? _green : _amber,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRunning ? _green : _amber).withValues(
                          alpha: 0.8,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isRunning ? 'FOCUS MODE ACTIVE' : 'SESSION PAUSED',
                  style: GoogleFonts.spaceGrotesk(
                    color: _isRunning ? _green : _amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _energyColor.withValues(alpha: 0.08),
                border: Border.all(color: _energyColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                _energyLabel,
                style: GoogleFonts.spaceGrotesk(
                  color: _energyColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerRing() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _glow]),
      builder: (_, __) => SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isRunning)
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AC.purple.withValues(
                        alpha: 0.06 + 0.08 * _pulse.value,
                      ),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            CustomPaint(
              size: const Size(260, 260),
              painter: _RingPainter(
                progress: _progress,
                glowT: _pulse.value,
                isRunning: _isRunning,
                energyColor: _energyColor,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeString,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 58,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _isRunning ? 'DEEP FOCUS' : 'PAUSED',
                    key: ValueKey(_isRunning),
                    style: GoogleFonts.spaceGrotesk(
                      color: _isRunning ? const Color(0x44FFFFFF) : _amber,
                      fontSize: 10,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTaskCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AC.purple,
              boxShadow: [
                BoxShadow(
                  color: AC.purple.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _activeTask,
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0x99FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusPulse() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _card,
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.show_chart_rounded, color: _focusScoreColor, size: 14),
            const SizedBox(width: 8),
            Text(
              'Focus Stability',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0x55FFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      color: _surface,
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 500),
                      widthFactor: _focusScore / 100,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: _focusScoreColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$_focusScore%',
              style: GoogleFonts.spaceGrotesk(
                color: _focusScoreColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusShield() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _card,
          border: Border.all(
            color: _focusShield
                ? AC.purple.withValues(alpha: 0.3)
                : _cardBorder,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: _focusShield
                        ? AC.purple.withValues(alpha: 0.15)
                        : _surface,
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: _focusShield ? AC.purple : const Color(0x33FFFFFF),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Shield',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _focusShield
                            ? 'Blocking apps & notifications'
                            : 'Tap to protect your focus',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0x44FFFFFF),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    if (!_focusShield) {
                      if (defaultTargetPlatform == TargetPlatform.android) {
                        final hasNotif =
                            await AppBlockerService.hasNotificationListenerPermission();
                        if (!hasNotif) {
                          _showNotificationPermissionDialog();
                          return;
                        }
                        final hasAccessibility =
                            await AppBlockerService.hasAccessibilityPermission();
                        if (!hasAccessibility) {
                          _showAccessibilityPermissionDialog();
                          return;
                        }
                      }
                      await AppBlockerService.enableNotificationBlocking();
                      await AppBlockerService.startAppBlocking();
                    } else {
                      await AppBlockerService.disableNotificationBlocking();
                      await AppBlockerService.stopAppBlocking();
                    }
                    setState(() => _focusShield = !_focusShield);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 44,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _focusShield ? AC.purple : _surface,
                      border: Border.all(
                        color: _focusShield
                            ? AC.purple.withValues(
                                alpha: 0.5,
                              ) // was 0.3, now sharper
                            : const Color(
                                0x25FFFFFF,
                              ), // was _cardBorder, now slightly more visible
                        width: 1.0, // explicit 1px
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: _focusShield
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 18,
                        height: 18,
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
            if (_focusShield) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.volume_down_rounded,
                    color: Color(0x33FFFFFF),
                    size: 14,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AC.purple,
                        inactiveTrackColor: const Color(0x18FFFFFF),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        trackHeight: 2,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(value: _mediaVolume, onChanged: _setVolume),
                    ),
                  ),
                  const Icon(
                    Icons.volume_up_rounded,
                    color: Color(0x33FFFFFF),
                    size: 14,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForestControls() {
    return Column(
      children: [
        // Centered pause orb
        GestureDetector(
          onTap: _togglePause,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 76,
              height: 76,
              // Replace the pause button Container decoration:
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRunning ? AC.purple : const Color(0xFF1A3D28),
                boxShadow: [
                  BoxShadow(
                    color: (_isRunning ? AC.purple : _green).withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 20,
                    spreadRadius: -4, // ← negative spread keeps edges crisp
                  ),
                ],
              ),
              child: Icon(
                _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Distraction + End pills below
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Distraction count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: _card,
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: _distractions == 0
                        ? const Color(0x33FFFFFF)
                        : _red.withValues(alpha: 0.8),
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_distractions distractions',
                    style: GoogleFonts.spaceGrotesk(
                      color: _distractions == 0
                          ? const Color(0x44FFFFFF)
                          : _red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // End session pill
            // Replace the End pill GestureDetector:
            GestureDetector(
              onTap: _stopSession,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: _red.withValues(alpha: 0.08),
                  border: Border.all(
                    color: _red.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Smooth circle stop instead of sharp square
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, // ← circle not rectangle
                        color: _red.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'End',
                      style: GoogleFonts.spaceGrotesk(
                        color: _red.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniStat(String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.7), size: 14),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0x44FFFFFF),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── STEP 4 — Reflection ──────────────────────────────────────────────────
  Widget _buildReflection() {
    final completedMin = (_totalSeconds - _remaining) ~/ 60;
    final completedSec = (_totalSeconds - _remaining) % 60;
    final totalMin = _totalSeconds ~/ 60;
    final pctCompleted = _totalSeconds == 0
        ? 0
        : ((_totalSeconds - _remaining) / _totalSeconds * 100).round();
    
    final Color contextColor;
    final IconData contextIcon;
    if (_distractions >= 3) {
      contextColor = const Color(0xFFFF6B8A);
      contextIcon = Icons.warning_amber_rounded;
    } else if (_focusScore >= 85 && _distractions == 0) {
      contextColor = const Color(0xFF3DD68C);
      contextIcon = Icons.verified_rounded;
    } else if (_focusScore >= 70) {
      contextColor = const Color(0xFF8A6CD1);
      contextIcon = Icons.thumb_up_rounded;
    } else if (completedMin < 5) {
      contextColor = const Color(0xFFFFAA44);
      contextIcon = Icons.directions_walk_rounded;
    } else {
      contextColor = const Color(0xFFFF6B8A);
      contextIcon = Icons.warning_amber_rounded;
    }

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Hero ─────────────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF3DD68C).withOpacity(0.20),
                              const Color(0xFF3DD68C).withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF3DD68C).withOpacity(0.45),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3DD68C).withOpacity(0.20),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF3DD68C),
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Session Complete!',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3DD68C).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF3DD68C).withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          completedMin > 0
                              ? '$completedMin min $completedSec sec of $totalMin min'
                              : 'Quick session',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF3DD68C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── AI remark card ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: contextColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: contextColor.withOpacity(0.20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: contextColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(contextIcon, color: contextColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _sessionRemark.isEmpty
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: contextColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'ARIA is analysing your session...',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white.withOpacity(0.40),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _sessionRemark,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Stats card ────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13102A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8A6CD1).withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _metricRow(
                        Icons.pie_chart_rounded,
                        'Completed',
                        '$pctCompleted%',
                        pctCompleted >= 80
                            ? const Color(0xFF3DD68C)
                            : const Color(0xFFFFAA44),
                      ),
                      _metricDivider(),
                      _metricRow(
                        Icons.psychology_rounded,
                        'Focus Stability',
                        '$_focusScore%',
                        _focusScoreColor,
                      ),
                      _metricDivider(),
                      _metricRow(
                        Icons.do_not_disturb_on_rounded,
                        'Interruptions',
                        _distractions == 0 ? 'None' : '$_distractions',
                        _distractions == 0
                            ? const Color(0xFF3DD68C)
                            : const Color(0xFFFF6B8A),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── How was your focus ────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A6CD1), Color(0x663DD68C)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'HOW WAS YOUR FOCUS?',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _reflectionCard(
                      0,
                      Icons.rocket_launch_rounded,
                      'Great',
                      const Color(0xFF3DD68C),
                    ),
                    const SizedBox(width: 10),
                    _reflectionCard(
                      1,
                      Icons.horizontal_rule_rounded,
                      'Okay',
                      const Color(0xFF8A6CD1),
                    ),
                    const SizedBox(width: 10),
                    _reflectionCard(
                      2,
                      Icons.wind_power_rounded,
                      'Distracted',
                      const Color(0xFFFF6B8A),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: Colors.white.withOpacity(0.06)),
  );

  Widget _metricRow(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statTile(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF13102A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _reflectionCard(int index, IconData icon, String label, Color color) {
    final selected = _reflectionRating == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _submitReflection(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? color.withOpacity(0.14) : const Color(0xFF13102A),
            border: Border.all(
              color: selected
                  ? color.withOpacity(0.55)
                  : const Color(0x22FFFFFF),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(selected ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? color : Colors.white.withOpacity(0.40),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SHARED WIDGETS ───────────────────────────────────────────────────────
  // showBack: true adds a back arrow for the energy pick step
  Widget _buildTopBar({bool showBack = false}) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (showBack)
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x14FFFFFF),
                        border: Border.all(color: const Color(0x28FFFFFF)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8A6CD1).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFF8A6CD1).withOpacity(0.40),
                    ),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF8A6CD1),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Focus',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _amber.withValues(alpha: 0.1),
        border: Border.all(color: _amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            '$_streak day streak',
            style: GoogleFonts.spaceGrotesk(
              color: _amber,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stop overlay ─────────────────────────────────────────────────────────
  Widget _buildStopOverlay() {
    return AnimatedBuilder(
      animation: _overlay,
      builder: (_, __) => Container(
        color: Colors.black.withValues(alpha: 0.7 * _overlayCtrl.value),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: 0.85 + 0.15 * _overlay.value,
          child: Opacity(
            opacity: _overlayCtrl.value.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: _card,
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_circle_outlined, color: _red, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'End Session?',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your progress will still be saved.',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0x66FFFFFF),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _dismissStopOverlay,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: _surface,
                              border: Border.all(color: _cardBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Continue',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _confirmStop,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: _red.withValues(alpha: 0.15),
                              border: Border.all(
                                color: _red.withValues(alpha: 0.4),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'End Session',
                              style: GoogleFonts.spaceGrotesk(
                                color: _red,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }
}

// ─── Ring painter ─────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final double glowT;
  final bool isRunning;
  final Color energyColor;

  const _RingPainter({
    required this.progress,
    required this.glowT,
    required this.isRunning,
    required this.energyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    const sw = 7.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1E1B3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            energyColor.withValues(alpha: 0.6),
            const Color(0xFF9B6FE8),
            const Color(0xFFD4A8FF),
            const Color(0xFF6B3FBF),
          ],
          stops: const [0.0, 0.3, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    if (progress > 0.01) {
      final angle = -math.pi / 2 + sweep;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      canvas.drawCircle(
        Offset(dx, dy),
        9 + 3 * glowT,
        Paint()
          ..color = const Color(
            0xFF9B6FE8,
          ).withValues(alpha: 0.25 + 0.2 * glowT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(Offset(dx, dy), 5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.glowT != glowT ||
      old.isRunning != isRunning;
}

class _FocusNebulaPainter extends CustomPainter {
  final double t;
  _FocusNebulaPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Base background — matches reminders exactly
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1035), Color(0xFF0E0B1E), Color(0xFF160E2E)],
        ).createShader(Offset.zero & size),
    );

    // Top-left nebula bloom — primary purple glow
    canvas.drawCircle(
      Offset(
        cx * 0.3 + 35 * math.sin(t * math.pi),
        cy * 0.35 + 22 * math.cos(t * math.pi),
      ),
      size.width * 0.85,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x508A6CD1), const Color(0x008A6CD1)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx * 0.3, cy * 0.35),
                radius: size.width * 0.85,
              ),
            ),
    );

    // Right-side secondary bloom
    canvas.drawCircle(
      Offset(
        cx * 1.7 - 22 * math.cos(t * math.pi),
        cy * 0.6 + 18 * math.sin(t * math.pi),
      ),
      size.width * 0.65,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x386B4DA8), const Color(0x006B4DA8)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx * 1.7, cy * 0.6),
                radius: size.width * 0.65,
              ),
            ),
    );

    // Extra center-top bloom for focus screen — gives the bright top feel
    canvas.drawCircle(
      Offset(cx + 15 * math.sin(t * math.pi * 0.7), cy * 0.15),
      size.width * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x3A7C3AED), const Color(0x007C3AED)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx, cy * 0.15),
                radius: size.width * 0.55,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(_FocusNebulaPainter old) => old.t != t;
}

class _FocusGrainPainter extends CustomPainter {
  final _rng = math.Random(42);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.013);
    for (int i = 0; i < 900; i++) {
      canvas.drawCircle(
        Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
        _rng.nextDouble() * 0.7,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_FocusGrainPainter _) => false;
}
