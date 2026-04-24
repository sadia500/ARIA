// lib/screens/dashboard.dart
// ignore_for_file: unused_import, unnecessary_underscores, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import '../services/firestore_service.dart';
import 'schedule_screen.dart';
import 'focus_screen.dart';
import 'reminder_screen.dart';
import 'AI_chat_screen.dart';
import '../services/aria_ai_service.dart';
import 'dart:async';
import 'dart:math' as math;

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _bg = Color(0xFF0E0B1E);
const Color _glass = Color(0x14FFFFFF);
const Color _glassBorder = Color(0x28FFFFFF);
const Color _violet = Color(0xFF8A6CD1);
const Color _violetDeep = Color(0xFF5B3FA8);
const Color _violetGlow = Color(0xFF4D3385);
const Color _mint = Color(0xFF3DD68C);
const Color _rose = Color(0xFFFF6B8A);
const Color _amber = Color(0xFFFFAA44);
const Color _cardBg = Color(0xFF13102A);
const Color _cardBorder = Color(0x22FFFFFF);

class ARIADashboard extends StatefulWidget {
  final String userName;
  final void Function(int index) shellContext;
  const ARIADashboard({
    super.key,
    required this.userName,
    required this.shellContext,
  });

  @override
  State<ARIADashboard> createState() => _ARIADashboardState();
}

class _ARIADashboardState extends State<ARIADashboard>
    with TickerProviderStateMixin {
  StreamSubscription<List<ARIATask>>? _taskSub;
  List<ARIATask> _allTasks = [];
  int _streak = 0;
  String _insight = 'Analysing your productivity data...';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _entranceFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
        );

    _taskSub = TaskStore.stream().listen((tasks) {
      if (mounted) setState(() => _allTasks = tasks);
    });
    _loadStreak();
    _loadInsight();
  }

  Future<void> _loadStreak() async {
    try {
      final p = await FirestoreService.instance.loadProfile();
      if (mounted) setState(() => _streak = (p?['streak'] as int?) ?? 0);
    } catch (_) {}
  }

  Future<void> _loadInsight() async {
    try {
      final insight = await AriaAIService().generateDashboardInsight();
      if (mounted) setState(() => _insight = insight);
    } catch (_) {}
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────────
  List<ARIATask> get _todayTasks {
    final now = DateTime.now();
    return _allTasks
        .where(
          (t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day,
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  int get _total => _todayTasks.length;
  int get _done => _todayTasks.where((t) => t.isDone).length;
  int get _urgent => _todayTasks
      .where((t) => t.priority == TaskPriority.high && !t.isDone)
      .length;
  double get _progress => _total == 0 ? 0.0 : _done / _total;

  ARIATask? get _nextTask {
    final hp = _todayTasks
        .where((t) => !t.isDone && t.priority == TaskPriority.high)
        .toList();
    if (hp.isNotEmpty) return hp.first;
    final any = _todayTasks.where((t) => !t.isDone).toList();
    return any.isNotEmpty ? any.first : null;
  }

  // Up to 3 upcoming tasks after nextTask
  List<ARIATask> get _upcomingTasks {
    final next = _nextTask;
    final pending = _todayTasks.where((t) => !t.isDone).toList();
    if (next == null) return [];
    return pending.where((t) => t.id != next.id).take(3).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientGlow()),
          // Violet bloom top-right
          Positioned(top: -80, right: -60, child: _glowOrb(200, _violet, 0.16)),
          // Mint bloom bottom-left
          Positioned(bottom: 140, left: -50, child: _glowOrb(160, _mint, 0.07)),
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 18),
                      _buildHeroCard(),
                      const SizedBox(height: 12),
                      _buildStatRow(),
                      const SizedBox(height: 18),
                      _buildFocusButton(),
                      const SizedBox(height: 22),
                      _buildNextTaskSection(),
                      const SizedBox(height: 18),
                      if (_upcomingTasks.isNotEmpty) ...[
                        _buildUpcomingSection(),
                        const SizedBox(height: 18),
                      ],
                      _buildAICard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withOpacity(opacity), Colors.transparent],
      ),
    ),
  );

  // ── Top bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _violet.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: _violet.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: ClipOval(
              child: Image.asset('assets/aria_logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'ARIA',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.5,
            ),
          ),
        ],
      ),
      Row(
        children: [
          if (_streak > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _glass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak days',
                    style: GoogleFonts.spaceGrotesk(
                      color: _amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _glass,
                border: Border.all(color: _glassBorder),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: Colors.white.withOpacity(0.55),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  // ── Hero greeting card ────────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    final now = DateTime.now();
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
    final h = now.hour;
    final greeting = h < 12
        ? 'Good Morning'
        : h < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final name = widget.userName.isEmpty
        ? 'there'
        : widget.userName.split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _violetGlow.withOpacity(0.55),
            _violetDeep.withOpacity(0.30),
            _cardBg.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _violet.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: _violet.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dateStr.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.50),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            greeting,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withOpacity(0.60),
              fontSize: 13,
            ),
          ),
          Text(
            name,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          if (_total > 0) ...[
            Row(
              children: [
                Text(
                  '$_done of $_total tasks done',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(_progress * 100).toInt()}% complete',
                  style: GoogleFonts.spaceGrotesk(
                    color: _progress == 1.0 ? _mint : _violet,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation(
                    _progress == 1.0 ? _mint : _violet,
                  ),
                ),
              ),
            ),
          ] else
            Text(
              'No tasks scheduled today',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.38),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  // ── Stat row — today only ─────────────────────────────────────────────────────
  Widget _buildStatRow() {
    final remaining = _total - _done;
    return Row(
      children: [
        Expanded(
          child: _statTile(
            Icons.pending_actions_rounded,
            '$remaining',
            'Remaining',
            _violet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(Icons.bolt_rounded, '$_urgent', 'Urgent', _rose),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            Icons.check_circle_outline_rounded,
            '$_done',
            'Done Today',
            _mint,
          ),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: color.withOpacity(0.70),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  // ── Focus button — CENTERED ───────────────────────────────────────────────────
  Widget _buildFocusButton() {
    final task = _nextTask;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FocusScreen(initialTask: task?.title ?? 'Free Focus Session'),
        ),
      ).then((_) => setState(() {})),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Container(
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF6B3FC8), Color(0xFF8A6CD1), Color(0xFF5B2FB0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _violet.withOpacity(0.35 + 0.20 * _pulseAnim.value),
                blurRadius: 20 + 16 * _pulseAnim.value,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: _mint.withOpacity(0.06 + 0.06 * _pulseAnim.value),
                blurRadius: 30,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer layer
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      (_shimmerCtrl.value * 2 - 0.5) *
                          MediaQuery.of(context).size.width,
                      0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.09),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Content — perfectly centered in Stack
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_filled_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Start Focus Session',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _nextTask != null
                          ? _nextTask!.title
                          : 'Free mode · no task selected',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white.withOpacity(0.50),
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Next task ─────────────────────────────────────────────────────────────────
  Widget _buildNextTaskSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('NEXT TASK', onViewAll: () => widget.shellContext(1)),
      const SizedBox(height: 10),
      _nextTask == null
          ? _buildAllDoneCard()
          : _buildTaskCard(_nextTask!, large: true),
    ],
  );

  Widget _buildAllDoneCard() => GestureDetector(
    onTap: () => widget.shellContext(1),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _mint.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _mint.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _mint.withOpacity(0.15),
              border: Border.all(color: _mint.withOpacity(0.30)),
            ),
            child: Icon(Icons.check_rounded, color: _mint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All clear for today! 🎉',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap to add more tasks',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withOpacity(0.40),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.add_rounded, color: _mint.withOpacity(0.6), size: 20),
        ],
      ),
    ),
  );

  Widget _buildTaskCard(ARIATask task, {bool large = false}) {
    final priorityColor = task.priority == TaskPriority.high
        ? _rose
        : task.priority == TaskPriority.medium
        ? _amber
        : _mint;

    return GestureDetector(
      onTap: () => widget.shellContext(1),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cardBorder),
          boxShadow: large
              ? [
                  BoxShadow(
                    color: priorityColor.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar — separate widget avoids the border conflict
                Container(width: 4, color: priorityColor),
                // Card content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(large ? 16 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Priority badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: priorityColor.withOpacity(0.28),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: priorityColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.priority.label,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: priorityColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Category glass tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _glass,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _glassBorder),
                              ),
                              child: Text(
                                task.category.label,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white.withOpacity(0.60),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: large ? 10 : 8),
                        Text(
                          task.title,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: large ? 18 : 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: large ? 8 : 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _glass,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 10,
                                    color: Colors.white.withOpacity(0.40),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${task.startTime} – ${task.endTime}',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white.withOpacity(0.50),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withOpacity(0.25),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Upcoming tasks ────────────────────────────────────────────────────────────
  Widget _buildUpcomingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('UPCOMING', onViewAll: () => widget.shellContext(1)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: _upcomingTasks.asMap().entries.map((e) {
            final i = e.key;
            final task = e.value;
            final isLast = i == _upcomingTasks.length - 1;
            final priorityColor = task.priority == TaskPriority.high
                ? _rose
                : task.priority == TaskPriority.medium
                ? _amber
                : _mint;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Color dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
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
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.startTime,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.06),
                    indent: 36,
                    endIndent: 16,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    ],
  );

  // ── AI card ───────────────────────────────────────────────────────────────────
  Widget _buildAICard() => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AriaAIScreen(initialMessage: _insight)),
    ),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_violetGlow.withOpacity(0.40), _cardBg.withOpacity(0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _violet.withOpacity(0.26)),
        boxShadow: [
          BoxShadow(
            color: _violetGlow.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _violet.withOpacity(0.50),
                      _violetDeep.withOpacity(0.30),
                    ],
                  ),
                  border: Border.all(color: _violet.withOpacity(0.40)),
                  boxShadow: [
                    BoxShadow(color: _violet.withOpacity(0.22), blurRadius: 8),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/aria_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARIA INSIGHT',
                    style: GoogleFonts.spaceGrotesk(
                      color: _violet,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'Personalised for you',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _violet.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _violet.withOpacity(0.28)),
                ),
                child: Text(
                  'Chat with ARIA →',
                  style: GoogleFonts.spaceGrotesk(
                    color: _violet,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _violet.withOpacity(0.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [_violet, _mint.withOpacity(0.4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _insight,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ── Section label ─────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, {VoidCallback? onViewAll}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [_violet, _mint.withOpacity(0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withOpacity(0.50),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
      if (onViewAll != null)
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'View All',
            style: GoogleFonts.spaceGrotesk(
              color: _violet,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );
}

// ── Ring widget ───────────────────────────────────────────────────────────────
class _RingWidget extends StatefulWidget {
  final double progress;
  final int done, total;
  const _RingWidget({
    required this.progress,
    required this.done,
    required this.total,
  });

  @override
  State<_RingWidget> createState() => _RingWidgetState();
}

class _RingWidgetState extends State<_RingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _anim = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_RingWidget old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(
        begin: old.progress,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => CustomPaint(
      size: const Size(72, 72),
      painter: _RingPainter(_anim.value),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.total == 0 ? '–' : '${(_anim.value * 100).toInt()}%',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'done',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    const sw = 5.0;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: const [Color(0xFF8A6CD1), Color(0xFF3DD68C)],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );

    final angle = -math.pi / 2 + math.pi * 2 * progress;
    canvas.drawCircle(
      Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle)),
      3.5,
      Paint()..color = const Color(0xFF3DD68C),
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}
