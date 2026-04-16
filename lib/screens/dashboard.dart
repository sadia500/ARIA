// lib/screens/dashboard.dart
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'schedule_screen.dart';
import 'focus_screen.dart';
import '../services/storage_service.dart';

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

class _ARIADashboardState extends State<ARIADashboard> {
  static const Color _orange = Color(0xFFE05C3A);

  // ── Stream subscription — cancelled in dispose ──────────────────────────
  StreamSubscription<List<ARIATask>>? _taskSub;
  List<ARIATask> _allTasks = [];

  @override
  void initState() {
    super.initState();
    _taskSub = TaskStore.stream().listen((tasks) {
      if (mounted) setState(() => _allTasks = tasks);
    });
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    super.dispose();
  }

  // ── Computed from local _allTasks ────────────────────────────────────────
  List<ARIATask> get _todayTasks {
    final now = DateTime.now();
    return _allTasks.where((t) =>
      t.date.year == now.year &&
      t.date.month == now.month &&
      t.date.day == now.day
    ).toList();
  }

  int get _todayTotal => _todayTasks.length;
  int get _todayDone  => _todayTasks.where((t) => t.isDone).length;
  int get _highPriority => _todayTasks
      .where((t) => t.priority == TaskPriority.high && !t.isDone).length;
  int get _streak => StorageService.instance.loadStreak();

  ARIATask? get _nextTask {
    final hp = _todayTasks
        .where((t) => !t.isDone && t.priority == TaskPriority.high).toList();
    if (hp.isNotEmpty) return hp.first;
    final any = _todayTasks.where((t) => !t.isDone).toList();
    return any.isNotEmpty ? any.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Stack(children: [
        const Positioned.fill(child: AmbientGlow()),
        SafeArea(
          bottom: false,
          child: ScreenEntrance(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildTopBar(),
                  const SizedBox(height: 24),
                  _buildDateGreeting(),
                  const SizedBox(height: 20),
                  _buildFocusButton(),
                  const SizedBox(height: 24),
                  _buildNextTaskSection(),
                  const SizedBox(height: 20),
                  _buildAIInsightCard(),
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildTodayProgress(),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AC.purpleBorder, width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset('assets/aria_logo.png',
                  width: 38, height: 38, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Text('ARIA', style: GoogleFonts.spaceGrotesk(
              color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w700, letterSpacing: 2)),
        ]),
        Row(children: [
          if (_todayTotal > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AC.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AC.purpleBorder),
              ),
              child: Text('$_todayDone/$_todayTotal today',
                  style: GoogleFonts.spaceGrotesk(
                      color: AC.purple, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          if (_streak > 1)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFAA44).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFFAA44).withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔥', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text('$_streak', style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFFFFAA44),
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AC.cardBorder),
            ),
            child: Icon(Icons.notifications_outlined,
                color: Colors.white.withValues(alpha: 0.5), size: 18),
          ),
        ]),
      ],
    );
  }

  Widget _buildDateGreeting() {
    final now = DateTime.now();
    final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final months = ['','January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    final dayStr = '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}, ${now.year}';
    final h = now.hour;
    final greeting = h < 12 ? 'Good Morning' : h < 17 ? 'Good Afternoon' : 'Good Evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AC.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dayStr, style: GoogleFonts.spaceGrotesk(
            color: AC.bodyText, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          '$greeting, ${widget.userName.isEmpty ? "there" : widget.userName}',
          style: AText.title.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _chip('$_todayTotal tasks today', AC.purple),
          const SizedBox(width: 8),
          Container(width: 4, height: 4,
              decoration: const BoxDecoration(
                  color: AC.bodyText, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          _chip('$_highPriority high priority', _orange),
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.30)),
    ),
    child: Text(label, style: GoogleFonts.spaceGrotesk(
        color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _buildFocusButton() {
    final task = _nextTask;
    return Column(children: [
      GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => FocusScreen(
              initialTask: task?.title ?? 'Free Focus Session',
            ),
          )).then((_) => setState(() {}));
        },
        child: Container(
          width: double.infinity, height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AC.purple, AC.purpleDeep],
                begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(
                color: AC.purpleShadow1, blurRadius: 22,
                offset: Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text('Start Focus Session', style: AText.button),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (task != null)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.task_alt_rounded, size: 12, color: AC.purple),
          const SizedBox(width: 5),
          Flexible(child: Text(task.title,
              style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
        ])
      else
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bolt_rounded, size: 13, color: AC.purple),
          const SizedBox(width: 4),
          Text('FREE FOCUS MODE', style: GoogleFonts.spaceGrotesk(
              color: AC.purple, fontSize: 10,
              fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        ]),
    ]);
  }

  Widget _buildNextTaskSection() {
    final task = _nextTask;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('NEXT TASK', style: GoogleFonts.spaceGrotesk(
            color: AC.bodyText, fontSize: 11,
            fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        GestureDetector(
          onTap: () => widget.shellContext(1),
          child: Text('View All', style: AText.purpleLabel),
        ),
      ]),
      const SizedBox(height: 12),
      if (task == null)
        GestureDetector(
          onTap: () => widget.shellContext(1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF34A853).withOpacity(0.3)),
            ),
            child: Column(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF34A853).withOpacity(0.12),
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF34A853), size: 28),
              ),
              const SizedBox(height: 12),
              Text('All done for today! 🎉',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Tap to add more tasks or start a free focus session',
                  style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText, fontSize: 12),
                  textAlign: TextAlign.center),
            ]),
          ),
        )
      else
        GestureDetector(
          onTap: () => widget.shellContext(1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: task.priority.color.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: task.priority.color,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(task.priority.label,
                          style: GoogleFonts.spaceGrotesk(
                              color: task.priority.color, fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                    ]),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: AC.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AC.cardBorder)),
                      child: const Icon(Icons.chevron_right_rounded,
                          color: AC.iconTint, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(task.title, style: AText.title.copyWith(fontSize: 17)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: AC.iconTint),
                  const SizedBox(width: 5),
                  Text('${task.startTime} – ${task.endTime}',
                      style: GoogleFonts.spaceGrotesk(
                          color: AC.bodyText, fontSize: 12)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: task.category.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(task.category.label,
                        style: GoogleFonts.spaceGrotesk(
                            color: task.category.color, fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _buildAIInsightCard() {
    final insights = [
      'Your peak focus window is 10–12 AM. Start deep work now.',
      'You have $_highPriority high-priority tasks. Tackle the hardest one first.',
      'Consistent focus sessions boost productivity by up to 40%.',
      'Break large tasks into 25-minute sprints for best results.',
    ];
    final insight = insights[DateTime.now().hour % insights.length];

    return GestureDetector(
      onTap: () => widget.shellContext(2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AC.purpleBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AC.purpleGlow,
              border: Border.all(color: AC.purpleBorder),
            ),
            child: ClipOval(child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset('assets/aria_logo.png', fit: BoxFit.contain),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI INSIGHT', style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText, fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 1.8)),
              const SizedBox(height: 6),
              Text(insight, style: GoogleFonts.spaceGrotesk(
                  color: Colors.white, fontSize: 14,
                  height: 1.55, fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Text('Ask ARIA for more insights →',
                  style: GoogleFonts.spaceGrotesk(
                      color: AC.purple.withValues(alpha: 0.7),
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('QUICK ACTIONS', style: GoogleFonts.spaceGrotesk(
          color: AC.bodyText, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Row(children: [
        _quickAction(Icons.add_task_rounded, 'Add Task',
            AC.purple, () => widget.shellContext(1)),
        const SizedBox(width: 12),
        _quickAction(Icons.auto_awesome_rounded, 'Ask ARIA',
            const Color(0xFF3DD68C), () => widget.shellContext(2)),
        const SizedBox(width: 12),
        _quickAction(Icons.bar_chart_rounded, 'Analytics',
            const Color(0xFFFFAA44), () => widget.shellContext(3)),
      ]),
    ]);
  }

  Widget _quickAction(IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.spaceGrotesk(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildTodayProgress() {
    if (_todayTotal == 0) return const SizedBox.shrink();
    final pct = _todayDone / _todayTotal;
    final cats = <TaskCategory, int>{};
    for (final t in _todayTasks) {
      cats[t.category] = (cats[t.category] ?? 0) + 1;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("TODAY'S PROGRESS", style: GoogleFonts.spaceGrotesk(
          color: AC.bodyText, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$_todayDone of $_todayTotal completed',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Text('${(pct * 100).toInt()}%',
                style: GoogleFonts.spaceGrotesk(
                    color: AC.purple, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v, minHeight: 8,
                backgroundColor: AC.bg,
                valueColor: const AlwaysStoppedAnimation(AC.purple),
              ),
            ),
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: cats.entries.map((e) {
              final f = (e.value / _todayTotal * 100).toInt().clamp(1, 100);
              return Expanded(flex: f, child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                    color: e.key.color,
                    borderRadius: BorderRadius.circular(2)),
              ));
            }).toList()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12, runSpacing: 6,
              children: cats.entries.map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: e.key.color)),
                  const SizedBox(width: 4),
                  Text('${e.key.label} (${e.value})',
                      style: GoogleFonts.spaceGrotesk(
                          color: AC.bodyText, fontSize: 10)),
                ],
              )).toList(),
            ),
          ],
        ]),
      ),
    ]);
  }
}