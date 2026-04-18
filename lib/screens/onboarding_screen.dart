// lib/screens/onboarding_screen.dart
// ignore_for_file: no_leading_underscores_for_local_identifiers, prefer_final_fields, deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── Page controller ──────────────────────────────────────────────────────
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _saving = false;

  // ── User answers ─────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  List<String> _selectedGoals = [];
  String _workStart = '9:00 AM';
  String _workEnd = '6:00 PM';
  int _focusDuration = 25; // minutes

  // ── Options ───────────────────────────────────────────────────────────────
  final _goals = [
    ('🎯', 'Deep Focus', 'Minimize distractions\nand get into flow'),
    ('📈', 'Productivity', 'Get more done\nin less time'),
    ('⚖️', 'Work-Life Balance', 'Balance work and\npersonal time'),
    ('🧠', 'Learning', 'Build new skills\nconsistently'),
  ];

  final _workStartOptions = [
    '6:00 AM',
    '7:00 AM',
    '8:00 AM',
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
  ];
  final _workEndOptions = [
    '3:00 PM',
    '4:00 PM',
    '5:00 PM',
    '6:00 PM',
    '7:00 PM',
    '8:00 PM',
  ];
  final _focusOptions = [15, 25, 45, 60, 90];

  // ── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _nameCtrl.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────
  void _next() {
    // Validate current page
    if (_currentPage == 0 && _nameCtrl.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (_currentPage == 1 && _selectedGoals.isEmpty) {
      _showError('Please select at least one goal');
      return;
    }

    if (_currentPage < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AC.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          msg,
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
      ),
    );
  }

  // ── Finish — save everything ──────────────────────────────────────────────
  Future<void> _finish() async {
    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final name = _nameCtrl.text.trim();

      // 1. Update Firebase Auth display name
      await user?.updateDisplayName(name);

      // 2. Save to Firestore
      await FirestoreService.instance.saveProfile(
        name: name,
        email: user?.email ?? '',
      );

      // 3. Save onboarding answers to Firestore
      await FirestoreService.instance.saveOnboardingData(
        goal: _selectedGoals.join(', '),
        workStart: _workStart,
        workEnd: _workEnd,
        focusDuration: _focusDuration,
      );

      // 4. Save name locally
      await StorageService.instance.saveUserName(name);

      // 5. Mark onboarding complete
      await StorageService.instance.setOnboardingDone();

      if (!mounted) return;

      // 6. Go to home
      Navigator.pushReplacementNamed(context, '/home', arguments: name);
    } catch (e) {
      setState(() => _saving = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientGlow()),
          SafeArea(
            child: Column(
              children: [
                // ── Progress bar + back button ──────────────────────────
                _buildTopBar(),
                // ── Pages ───────────────────────────────────────────────
                // ── Pages ───────────────────────────────────────────────────────────────
                Expanded(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _fadeCtrl,
                      curve: Curves.easeOut,
                    ),
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) {
                        setState(() => _currentPage = i);
                        _fadeCtrl.reset();
                        _fadeCtrl.forward();
                      },
                      children: [
                        _buildPage1Name(),
                        _buildPage2Goal(),
                        _buildPage3WorkHours(),
                        _buildPage4Focus(),
                      ],
                    ),
                  ),
                ),
                // ── Bottom button ────────────────────────────────────────
                _buildBottomButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              if (_currentPage > 0)
                GestureDetector(
                  onTap: _back,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AC.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AC.cardBorder),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                )
              else
                const SizedBox(width: 38),
              const SizedBox(width: 12),
              // Step indicator
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${_currentPage + 1} of 4',
                      style: GoogleFonts.spaceGrotesk(
                        color: AC.bodyText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / 4,
                        minHeight: 4,
                        backgroundColor: AC.card,
                        valueColor: const AlwaysStoppedAnimation(AC.purple),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ARIA logo small
              const AriaLogo(size: 32),
            ],
          ),
        ],
      ),
    );
  }

  // ── PAGE 1 — Name ─────────────────────────────────────────────────────────
  Widget _buildPage1Name() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            emoji: '👋',
            title: 'What should\nARIA call you?',
            subtitle: 'This is how ARIA will greet you every day.',
          ),
          const SizedBox(height: 36),
          Container(
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.purpleBorder),
            ),
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: AC.hint,
                  fontSize: 18,
                ),
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: AC.iconTint,
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AC.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AC.purpleBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AC.purple,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ARIA will personalize your experience based on your name and preferences.',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE 2 — Goal ─────────────────────────────────────────────────────────
  Widget _buildPage2Goal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            emoji: '🎯',
            title: 'What are your\ngoals?',
            subtitle:
                'Select all that apply — ARIA will tailor your schedule accordingly.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AC.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AC.purpleBorder),
            ),
            child: Text(
              '${_selectedGoals.length} selected — tap to toggle',
              style: GoogleFonts.spaceGrotesk(
                color: AC.purple,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ..._goals.map((g) {
            final isSelected = _selectedGoals.contains(g.$2);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedGoals.remove(g.$2);
                } else {
                  _selectedGoals.add(g.$2);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected ? AC.purple.withOpacity(0.12) : AC.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AC.purple : AC.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(g.$1, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.$2,
                            style: GoogleFonts.spaceGrotesk(
                              color: isSelected ? AC.purple : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            g.$3,
                            style: GoogleFonts.spaceGrotesk(
                              color: AC.bodyText,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: isSelected ? AC.purple : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? AC.purple : AC.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 13,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── PAGE 3 — Work Hours ───────────────────────────────────────────────────
  Widget _buildPage3WorkHours() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            emoji: '🕘',
            title: 'When do you\nusually work?',
            subtitle:
                'ARIA will schedule tasks and reminders within your work hours.',
          ),
          const SizedBox(height: 32),
          _sectionLabel('WORK START'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._workStartOptions.map((t) {
                final sel = _workStart == t;
                return GestureDetector(
                  onTap: () => setState(() => _workStart = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? AC.purple.withOpacity(0.15) : AC.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AC.purple : AC.cardBorder,
                      ),
                    ),
                    child: Text(
                      t,
                      style: GoogleFonts.spaceGrotesk(
                        color: sel ? AC.purple : AC.bodyText,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }),
              // Custom time picker
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: AC.purple),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    final h = picked.hourOfPeriod == 0
                        ? 12
                        : picked.hourOfPeriod;
                    final m = picked.minute.toString().padLeft(2, '0');
                    final ap = picked.period == DayPeriod.am ? 'AM' : 'PM';
                    setState(() => _workStart = '$h:$m $ap');
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: !_workStartOptions.contains(_workStart)
                        ? AC.purple.withOpacity(0.15)
                        : AC.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_workStartOptions.contains(_workStart)
                          ? AC.purple
                          : AC.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: !_workStartOptions.contains(_workStart)
                            ? AC.purple
                            : AC.iconTint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        !_workStartOptions.contains(_workStart)
                            ? _workStart
                            : 'Custom',
                        style: GoogleFonts.spaceGrotesk(
                          color: !_workStartOptions.contains(_workStart)
                              ? AC.purple
                              : AC.bodyText,
                          fontSize: 13,
                          fontWeight: !_workStartOptions.contains(_workStart)
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('WORK END'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._workEndOptions.map((t) {
                final sel = _workEnd == t;
                return GestureDetector(
                  onTap: () => setState(() => _workEnd = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? AC.purple.withOpacity(0.15) : AC.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AC.purple : AC.cardBorder,
                      ),
                    ),
                    child: Text(
                      t,
                      style: GoogleFonts.spaceGrotesk(
                        color: sel ? AC.purple : AC.bodyText,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }),
              // Custom time picker
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 18, minute: 0),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: AC.purple),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    final h = picked.hourOfPeriod == 0
                        ? 12
                        : picked.hourOfPeriod;
                    final m = picked.minute.toString().padLeft(2, '0');
                    final ap = picked.period == DayPeriod.am ? 'AM' : 'PM';
                    setState(() => _workEnd = '$h:$m $ap');
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: !_workEndOptions.contains(_workEnd)
                        ? AC.purple.withOpacity(0.15)
                        : AC.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_workEndOptions.contains(_workEnd)
                          ? AC.purple
                          : AC.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: !_workEndOptions.contains(_workEnd)
                            ? AC.purple
                            : AC.iconTint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        !_workEndOptions.contains(_workEnd)
                            ? _workEnd
                            : 'Custom',
                        style: GoogleFonts.spaceGrotesk(
                          color: !_workEndOptions.contains(_workEnd)
                              ? AC.purple
                              : AC.bodyText,
                          fontSize: 13,
                          fontWeight: !_workEndOptions.contains(_workEnd)
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AC.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule_rounded, color: AC.purple, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Work window: $_workStart – $_workEnd',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE 4 — Focus Duration ───────────────────────────────────────────────
  Widget _buildPage4Focus() {
    final _customCtrl = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(
            emoji: '⏱️',
            title: 'Preferred focus\nsession length?',
            subtitle:
                'ARIA will use this as your default when starting focus sessions.',
          ),
          const SizedBox(height: 32),
          ..._focusOptions.map((mins) {
            final isSelected = _focusDuration == mins;
            String label;
            String desc;
            switch (mins) {
              case 15:
                label = '15 min';
                desc = 'Quick sprint';
                break;
              case 25:
                label = '25 min';
                desc = 'Pomodoro classic';
                break;
              case 45:
                label = '45 min';
                desc = 'Deep work block';
                break;
              case 60:
                label = '60 min';
                desc = 'Power hour';
                break;
              default:
                label = '90 min';
                desc = 'Ultra focus';
            }
            return GestureDetector(
              onTap: () => setState(() => _focusDuration = mins),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AC.purple.withOpacity(0.12) : AC.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AC.purple : AC.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? AC.purple.withOpacity(0.2) : AC.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AC.purpleBorder : AC.cardBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$mins',
                          style: GoogleFonts.spaceGrotesk(
                            color: isSelected ? AC.purple : AC.bodyText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                              color: isSelected ? AC.purple : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            desc,
                            style: GoogleFonts.spaceGrotesk(
                              color: AC.bodyText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AC.purple,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
          // ── Custom duration input ─────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: !_focusOptions.contains(_focusDuration)
                  ? AC.purple.withOpacity(0.12)
                  : AC.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: !_focusOptions.contains(_focusDuration)
                    ? AC.purple
                    : AC.cardBorder,
                width: !_focusOptions.contains(_focusDuration) ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: !_focusOptions.contains(_focusDuration)
                        ? AC.purple.withOpacity(0.2)
                        : AC.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AC.cardBorder),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.edit_rounded,
                      color: AC.iconTint,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom',
                        style: GoogleFonts.spaceGrotesk(
                          color: !_focusOptions.contains(_focusDuration)
                              ? AC.purple
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: _customCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: '...',
                                hintStyle: GoogleFonts.spaceGrotesk(
                                  color: AC.hint,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) {
                                final val = int.tryParse(v);
                                if (val != null && val > 0 && val <= 300) {
                                  setState(() => _focusDuration = val);
                                }
                              },
                            ),
                          ),
                          Text(
                            'min',
                            style: GoogleFonts.spaceGrotesk(
                              color: AC.bodyText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!_focusOptions.contains(_focusDuration))
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AC.purple,
                    size: 22,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM BUTTON ─────────────────────────────────────────────────────────
  Widget _buildBottomButton() {
    final isLast = _currentPage == 3;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: GestureDetector(
        onTap: _saving ? null : _next,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AC.purple, AC.purpleDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AC.purpleShadow1,
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLast ? 'Get Started' : 'Continue',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLast
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _pageHeader({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: GoogleFonts.spaceGrotesk(
            color: AC.bodyText,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        color: AC.bodyText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}
