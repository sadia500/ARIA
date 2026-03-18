// lib/screens/analytics_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Full Analytics screen.
// Uses only Flutter built-ins + CustomPaint — NO new packages required.
// Pulls live data from TaskStore (schedule_screen.dart).
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'Schedule_screen.dart';

const Color _green = Color(0xFF34A853);
const Color _orange = Color(0xFFE05C3A);
const Color _amber = Color(0xFFFFAA44);
const Color _blue = Color(0xFF3B8BD4);

class ARIAAnalyticsScreen extends StatefulWidget {
  final String userName;
  const ARIAAnalyticsScreen({super.key, required this.userName});

  @override
  State<ARIAAnalyticsScreen> createState() => _ARIAAnalyticsScreenState();
}

class _ARIAAnalyticsScreenState extends State<ARIAAnalyticsScreen>
    with TickerProviderStateMixin {
  int _period = 0;

  late final AnimationController _enterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final AnimationController _barCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _ringCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final Animation<double> _enterAnim = CurvedAnimation(
    parent: _enterCtrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _barAnim = CurvedAnimation(
    parent: _barCtrl,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _ringAnim = CurvedAnimation(
    parent: _ringCtrl,
    curve: Curves.easeOutCubic,
  );

  int get _totalTasks => TaskStore.all.length;
  int get _doneTasks => TaskStore.all.where((t) => t.isDone).length;
  int get _highPriority =>
      TaskStore.all.where((t) => t.priority == TaskPriority.high).length;
  double get _completionRate => _totalTasks == 0 ? 0 : _doneTasks / _totalTasks;

  List<_DayBar> get _weekBars {
    final now = DateTime.now();
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final tasks = TaskStore.all
          .where(
            (t) =>
                t.date.year == day.year &&
                t.date.month == day.month &&
                t.date.day == day.day,
          )
          .toList();
      return _DayBar(
        label: labels[day.weekday - 1],
        total: tasks.length,
        done: tasks.where((t) => t.isDone).length,
        isToday:
            day.day == now.day &&
            day.month == now.month &&
            day.year == now.year,
      );
    });
  }

  Map<TaskCategory, int> get _categoryBreakdown {
    final map = <TaskCategory, int>{};
    for (final t in TaskStore.all) {
      map[t.category] = (map[t.category] ?? 0) + 1;
    }
    return map;
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _barCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  void _switchPeriod(int p) {
    if (p == _period) return;
    setState(() => _period = p);
    _barCtrl.reset();
    _barCtrl.forward();
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
            child: FadeTransition(
              opacity: _enterAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(_enterAnim),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 20),
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),
                      _buildBarChart(),
                      const SizedBox(height: 24),
                      _buildCompletionRing(),
                      const SizedBox(height: 24),
                      _buildCategoryBreakdown(),
                      const SizedBox(height: 24),
                      _buildStreakCard(),
                      const SizedBox(height: 24),
                      _buildAIInsight(),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Your productivity overview',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AC.purpleBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  '7 day streak',
                  style: GoogleFonts.spaceGrotesk(
                    color: _amber,
                    fontSize: 12,
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

  Widget _buildSummaryCards() {
    final cards = [
      _StatCard(
        label: 'Total Tasks',
        value: '$_totalTasks',
        icon: Icons.task_alt_rounded,
        color: AC.purple,
        sub: 'All time',
      ),
      _StatCard(
        label: 'Completed',
        value: '$_doneTasks',
        icon: Icons.check_circle_rounded,
        color: _green,
        sub: '${(_completionRate * 100).toInt()}% rate',
      ),
      _StatCard(
        label: 'High Priority',
        value: '$_highPriority',
        icon: Icons.bolt_rounded,
        color: _orange,
        sub: 'Urgent',
      ),
      _StatCard(
        label: 'Focus Hrs',
        value: '12.5',
        icon: Icons.timer_rounded,
        color: _blue,
        sub: 'This week',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.75,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _buildStatCard(cards[i], i),
      ),
    );
  }

  Widget _buildStatCard(_StatCard s, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: s.color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: s.color.withOpacity(0.12),
                  ),
                  child: Icon(s.icon, color: s.color, size: 16),
                ),
                Flexible(
                  child: Text(
                    s.sub,
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.value,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  s.label,
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.bodyText,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Task Activity',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AC.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['Week', 'Month', 'Year'].asMap().entries.map((e) {
                final sel = e.key == _period;
                return GestureDetector(
                  onTap: () => _switchPeriod(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: sel ? AC.purple : Colors.transparent,
                    ),
                    child: Text(
                      e.value,
                      style: GoogleFonts.spaceGrotesk(
                        color: sel ? Colors.white : AC.bodyText,
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final bars = _weekBars;
    final maxTotal = bars.map((b) => b.total).fold(1, math.max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Tasks',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    _legend(_green, 'Done'),
                    const SizedBox(width: 12),
                    _legend(AC.purple.withOpacity(0.4), 'Total'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _barAnim,
              builder: (_, _) => SizedBox(
                // ✅ FIXED: height increased so labels + bars + dots all fit
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: bars.map((bar) {
                    final totalH = maxTotal == 0
                        ? 0.0
                        : (bar.total / maxTotal) * 90 * _barAnim.value;
                    final doneH = bar.total == 0
                        ? 0.0
                        : (bar.done / bar.total) * totalH;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          bar.total > 0 ? '${bar.total}' : '',
                          style: GoogleFonts.spaceGrotesk(
                            color: AC.bodyText,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 28,
                          height: 90,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                width: 28,
                                height: math.max(totalH, 3.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: bar.isToday
                                      ? AC.purple.withOpacity(0.25)
                                      : AC.purple.withOpacity(0.12),
                                  border: bar.isToday
                                      ? Border.all(
                                          color: AC.purple.withOpacity(0.4),
                                          width: 1,
                                        )
                                      : null,
                                ),
                              ),
                              if (doneH > 0)
                                Container(
                                  width: 28,
                                  height: doneH,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [_green, _green.withOpacity(0.7)],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bar.label,
                          style: GoogleFonts.spaceGrotesk(
                            color: bar.isToday ? AC.purple : AC.bodyText,
                            fontSize: 11,
                            fontWeight: bar.isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        if (bar.isToday)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AC.purple,
                            ),
                          )
                        else
                          const SizedBox(height: 7),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildCompletionRing() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _ringAnim,
              builder: (_, _) => SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _RingChartPainter(
                    progress: _completionRate * _ringAnim.value,
                    trackColor: AC.bg,
                    fillColor: AC.purple,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_completionRate * 100 * _ringAnim.value).toInt()}%',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'done',
                          style: GoogleFonts.spaceGrotesk(
                            color: AC.bodyText,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Completion Rate',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on all your tasks',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ringStatRow('Completed', '$_doneTasks', _green),
                  const SizedBox(height: 8),
                  _ringStatRow(
                    'Remaining',
                    '${_totalTasks - _doneTasks}',
                    _orange,
                  ),
                  const SizedBox(height: 8),
                  _ringStatRow('Total', '$_totalTasks', AC.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ringStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 12),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    final breakdown = _categoryBreakdown;
    final total = breakdown.values.fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By Category',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AC.cardBorder),
            ),
            child: Column(
              children: TaskCategory.values.map((cat) {
                final count = breakdown[cat] ?? 0;
                final pct = total == 0 ? 0.0 : count / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildCategoryRow(cat, count, pct),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(TaskCategory cat, int count, double pct) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: pct),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, animPct, __) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: cat.color.withOpacity(0.12),
            ),
            child: Icon(cat.icon, color: cat.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat.label,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$count tasks',
                      style: GoogleFonts.spaceGrotesk(
                        color: AC.bodyText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 5, color: AC.bg),
                      FractionallySizedBox(
                        widthFactor: animPct.clamp(0.0, 1.0),
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: cat.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(pct * 100).toInt()}%',
            style: GoogleFonts.spaceGrotesk(
              color: cat.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    final now = DateTime.now();
    final cells = List.generate(14, (i) {
      final day = now.subtract(Duration(days: 13 - i));
      final count = TaskStore.all
          .where(
            (t) =>
                t.date.year == day.year &&
                t.date.month == day.month &&
                t.date.day == day.day &&
                t.isDone,
          )
          .length;
      return _HeatCell(
        day: day,
        count: count,
        isToday:
            day.day == now.day &&
            day.month == now.month &&
            day.year == now.year,
      );
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity Streak',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        '7 days',
                        style: GoogleFonts.spaceGrotesk(
                          color: _amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: cells.asMap().entries.map((e) {
                final cell = e.value;
                Color boxColor;
                if (cell.count == 0) {
                  boxColor = AC.bg;
                } else if (cell.count == 1) {
                  boxColor = AC.purple.withOpacity(0.3);
                } else if (cell.count <= 3) {
                  boxColor = AC.purple.withOpacity(0.6);
                } else {
                  boxColor = AC.purple;
                }
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + e.key * 40),
                  builder: (_, t, __) => Opacity(
                    opacity: t,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: boxColor,
                        border: cell.isToday
                            ? Border.all(color: AC.purple, width: 1.5)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '14 days ago',
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.bodyText,
                    fontSize: 9,
                  ),
                ),
                Text(
                  'Today',
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.purple,
                    fontSize: 9,
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

  Widget _buildAIInsight() {
    final insights = [
      'You complete most tasks between 10–12 AM. Schedule hard work then.',
      'Work tasks make up your largest category. Consider adding health goals.',
      'Your completion rate this week is above average. Keep it up!',
    ];
    final insight = insights[DateTime.now().day % insights.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AC.purpleBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AC.purpleGlow,
                border: Border.all(color: AC.purpleBorder),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/aria_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARIA INSIGHT',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    insight,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
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
}

class _StatCard {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
  });
}

class _DayBar {
  final String label;
  final int total, done;
  final bool isToday;
  const _DayBar({
    required this.label,
    required this.total,
    required this.done,
    required this.isToday,
  });
}

class _HeatCell {
  final DateTime day;
  final int count;
  final bool isToday;
  const _HeatCell({
    required this.day,
    required this.count,
    required this.isToday,
  });
}

class _RingChartPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  const _RingChartPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeW = 10.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [fillColor, fillColor.withOpacity(0.6)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_RingChartPainter old) => old.progress != progress;
}
