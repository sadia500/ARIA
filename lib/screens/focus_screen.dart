// lib/screens/focus_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES FROM ORIGINAL:
// • Removed _buildBottomNav() — Focus is a PUSHED route from dashboard,
//   not a tab. Shell nav hides automatically when this screen is pushed.
// • Back navigation: top bar back button added so user can return to shell
// • All other logic unchanged
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: unnecessary_underscores

import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
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

const Color _bg = Color(0xFF12102A);
const Color _card = Color(0xFF1C1940);
const Color _surface = Color(0xFF211E45);
const Color _cardBorder = Color(0x18FFFFFF);
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

  void _pickEnergy(_Energy e) {
    HapticFeedback.mediumImpact();
    setState(() {
      _energy = e;
      _totalSeconds = _suggestedMinutes * 60;
      _remaining = _totalSeconds;
      _aiMsgIndex = DateTime.now().hour % _aiMessages.length;
    });
    _transition(_ScreenState.aiSuggestion);
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
      _distractions++;
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

  void _submitReflection(int rating) async {
    HapticFeedback.selectionClick();
    setState(() => _reflectionRating = rating);

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _buildBackground(),
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
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                const Color(0xFF1A1640),
                const Color(0xFF1F1850),
                _glow.value,
              )!,
              _bg,
              const Color(0xFF0F0D24),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Center(child: _buildStreakBadge()),
                const SizedBox(height: 32),
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
                  'ARIA will suggest the best focus duration for you.',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0x66FFFFFF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                _energyCard(
                  energy: _Energy.high,
                  emoji: '⚡',
                  label: 'High Energy',
                  sub: 'Ready to crush it — 50 min deep work',
                  color: _green,
                ),
                const SizedBox(height: 12),
                _energyCard(
                  energy: _Energy.medium,
                  emoji: '🎯',
                  label: 'Medium Energy',
                  sub: 'Solid focus — 30 min session',
                  color: AC.purple,
                ),
                const SizedBox(height: 12),
                _energyCard(
                  energy: _Energy.low,
                  emoji: '🌙',
                  label: 'Low Energy',
                  sub: 'Light work — 15 min gentle session',
                  color: _amber,
                ),
                const SizedBox(height: 32),
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
    required String emoji,
    required String label,
    required String sub,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _pickEnergy(energy),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _card,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
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
                      color: const Color(0x66FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.6),
              size: 20,
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
        Text(
          'ACTIVE TASK',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0x55FFFFFF),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _card,
            border: Border.all(color: AC.purple.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
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
              const Icon(
                Icons.edit_outlined,
                color: Color(0x44FFFFFF),
                size: 16,
              ),
            ],
          ),
        ),
      ],
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
                      Text(
                        _aiMessages[_aiMsgIndex],
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
                          _vDivider(),
                          _sessionStat('$_streak', 'Day Streak', _amber),
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
                  onTap: () => _transition(_ScreenState.energyPick),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildTimerRing(),
                const SizedBox(height: 20),
                _buildActiveTaskCard(),
                const SizedBox(height: 14),
                _buildFocusPulse(),
                const SizedBox(height: 14),
                _buildSessionControls(),
                const SizedBox(height: 14),
                _buildFocusShield(),
                const SizedBox(height: 14),
                _buildDistractionCounter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTopBar() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AC.purple.withValues(alpha: 0.1 + 0.12 * _glow.value),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRunning ? _green : _amber,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRunning ? _green : _amber).withValues(
                          alpha: 0.7,
                        ),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isRunning ? 'FOCUS MODE ACTIVE' : 'SESSION PAUSED',
                  style: GoogleFonts.spaceGrotesk(
                    color: _isRunning ? _green : _amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _energyColor.withValues(alpha: 0.1),
                border: Border.all(color: _energyColor.withValues(alpha: 0.3)),
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
        width: 270,
        height: 270,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isRunning)
              Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AC.purple.withValues(
                        alpha: 0.08 + 0.10 * _pulse.value,
                      ),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            CustomPaint(
              size: const Size(270, 270),
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
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _isRunning ? 'DEEP FOCUS' : 'PAUSED',
                    key: ValueKey(_isRunning),
                    style: GoogleFonts.spaceGrotesk(
                      color: _isRunning ? const Color(0x66FFFFFF) : _amber,
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _focusScoreColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: _focusScoreColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        color: _focusScoreColor,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_focusScore% focus',
                        style: GoogleFonts.spaceGrotesk(
                          color: _focusScoreColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _card,
          border: Border.all(
            color: AC.purple.withValues(alpha: 0.15 + 0.15 * _pulse.value),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AC.purple.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AC.purple,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FOCUSING ON',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.purple,
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _activeTask,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
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

  Widget _buildFocusPulse() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _card,
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    color: _focusScoreColor,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'FOCUS STABILITY',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0x66FFFFFF),
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '$_focusScore%',
                style: GoogleFonts.spaceGrotesk(
                  color: _focusScoreColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 6, width: double.infinity, color: _surface),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 6,
                    width: double.infinity,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _focusScore / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              _focusScoreColor,
                              _focusScoreColor.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _focusScore >= 80
                ? 'Excellent — you\'re in flow state'
                : _focusScore >= 60
                ? 'Good — minor interruptions detected'
                : 'Needs improvement — frequent distractions',
            style: GoogleFonts.spaceGrotesk(
              color: _focusScoreColor.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionControls() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _togglePause,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _isRunning
                      ? [AC.purple, AC.purpleDeep]
                      : [const Color(0xFF1E4D2B), const Color(0xFF14331C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRunning ? AC.purple : _green).withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRunning ? 'Pause' : 'Resume',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _stopSession,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _surface,
              border: Border.all(color: _cardBorder),
            ),
            child: const Icon(Icons.stop_rounded, color: _red, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusShield() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _card,
        border: Border.all(
          color: _focusShield ? AC.purple.withValues(alpha: 0.3) : _cardBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _focusShield
                      ? AC.purple.withValues(alpha: 0.15)
                      : _surface,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: _focusShield ? AC.purple : const Color(0x44FFFFFF),
                  size: 18,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _focusShield
                          ? 'Blocking all notifications & apps'
                          : 'Tap to enable focus protection',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0x55FFFFFF),
                        fontSize: 11,
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
                  width: 46,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: _focusShield ? AC.purple : _surface,
                    border: Border.all(
                      color: _focusShield ? AC.purple : _cardBorder,
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
          if (_focusShield) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.volume_down_rounded,
                  color: Color(0x44FFFFFF),
                  size: 16,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AC.purple,
                      inactiveTrackColor: const Color(0x22FFFFFF),
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 3,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(value: _mediaVolume, onChanged: _setVolume),
                  ),
                ),
                const Icon(
                  Icons.volume_up_rounded,
                  color: Color(0x44FFFFFF),
                  size: 16,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDistractionCounter() {
    final uninterruptedMin = _uninterruptedSec ~/ 60;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _card,
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniStat(
              '$_distractions',
              'Distractions',
              _distractions == 0 ? _green : _red,
              Icons.warning_amber_outlined,
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0x12FFFFFF)),
          Expanded(
            child: _miniStat(
              '${uninterruptedMin}m',
              'Uninterrupted',
              _green,
              Icons.timer_outlined,
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0x12FFFFFF)),
          Expanded(
            child: _miniStat(
              '$_focusScore%',
              'Focus Score',
              _focusScoreColor,
              Icons.psychology_outlined,
            ),
          ),
        ],
      ),
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
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _green.withValues(alpha: 0.12),
                    border: Border.all(
                      color: _green.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.25),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _green,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Session Complete!',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completedMin minutes of focused work',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0x66FFFFFF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: _card,
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Column(
                    children: [
                      _metricRow(
                        Icons.warning_amber_outlined,
                        'Distractions',
                        '$_distractions',
                        _red,
                      ),
                      const SizedBox(height: 14),
                      _metricRow(
                        Icons.psychology_outlined,
                        'Focus Stability',
                        '$_focusScore%',
                        _focusScoreColor,
                      ),
                      const SizedBox(height: 14),
                      _metricRow(
                        Icons.timer_outlined,
                        'Uninterrupted Time',
                        '${_uninterruptedSec ~/ 60}m ${_uninterruptedSec % 60}s',
                        _green,
                      ),
                      const SizedBox(height: 14),
                      _metricRow(
                        Icons.local_fire_department_rounded,
                        'Current Streak',
                        '$_streak days',
                        _amber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'HOW WAS YOUR FOCUS?',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0x55FFFFFF),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _reflectionCard(0, '🎯', 'Great', _green),
                    const SizedBox(width: 10),
                    _reflectionCard(1, '😐', 'Okay', AC.purple),
                    const SizedBox(width: 10),
                    _reflectionCard(2, '😵', 'Distracted', _red),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricRow(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color.withValues(alpha: 0.7), size: 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0x80FFFFFF),
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _reflectionCard(int index, String emoji, String label, Color color) {
    final selected = _reflectionRating == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _submitReflection(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? color.withValues(alpha: 0.15) : _card,
            border: Border.all(
              color: selected ? color : _cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? color : const Color(0x66FFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
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
                      borderRadius: BorderRadius.circular(9),
                      color: _surface,
                      border: Border.all(color: _cardBorder),
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
                  borderRadius: BorderRadius.circular(9),
                  color: _surface,
                  border: Border.all(color: _cardBorder),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AC.purple,
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
          _buildStreakBadge(),
        ],
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
