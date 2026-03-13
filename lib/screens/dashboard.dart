// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'Schedule_screen.dart';

class ARIADashboard extends StatefulWidget {
  final String userName;
  const ARIADashboard({super.key, required this.userName});

  @override
  State<ARIADashboard> createState() => _ARIADashboardState();
}

class _ARIADashboardState extends State<ARIADashboard> {
  int _selectedNav = 0;

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home_rounded, 'label': 'Home'},
    {'icon': Icons.calendar_today_rounded, 'label': 'Schedule'},
    {'icon': null, 'label': 'AI'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Analytics'},
    {'icon': Icons.person_rounded, 'label': 'Profile'},
  ];

  static const Color _orange = Color(0xFFE05C3A);

  void _navigateToTab(int index) {
    setState(() => _selectedNav = index);
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ARIAScheduleScreen(userName: widget.userName),
        ),
      ).then((_) => setState(() => _selectedNav = 0));
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
            bottom: false,
            child: ScreenEntrance(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AC.purpleBorder, width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/aria_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ARIA',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AC.cardBorder),
          ),
          child: Text(
            'Active',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── DATE + GREETING ────────────────────────────────────────────────────────
  Widget _buildDateGreeting() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AC.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monday, February 23, 2026',
            style: GoogleFonts.spaceGrotesk(
              color: AC.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Good Morning, ${widget.userName.isEmpty ? "Ayesha" : widget.userName}',
            style: AText.title.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildChip('4 tasks today', AC.purple),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AC.bodyText,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              _buildChip('2 high priority', _orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── FOCUS BUTTON ───────────────────────────────────────────────────────────
  Widget _buildFocusButton() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AC.purple, AC.purpleDeep],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AC.purpleShadow1,
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text('Start Focus Session', style: AText.button),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Recommended: ',
              style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 13),
            ),
            Text(
              '45 min',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 13, color: AC.purple),
            const SizedBox(width: 4),
            Text(
              'PEAK ENERGY TIME',
              style: GoogleFonts.spaceGrotesk(
                color: AC.purple,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── NEXT TASK ──────────────────────────────────────────────────────────────
  Widget _buildNextTaskSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NEXT TASK',
              style: GoogleFonts.spaceGrotesk(
                color: AC.bodyText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ARIAScheduleScreen(userName: widget.userName),
                ),
              ),
              child: Text('View All', style: AText.purpleLabel),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'HIGH PRIORITY',
                        style: GoogleFonts.spaceGrotesk(
                          color: _orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AC.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AC.cardBorder),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AC.iconTint,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Complete Product Roadmap',
                style: AText.title.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AC.iconTint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '10:00 AM - 12:00 PM',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '60%',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const LinearProgressIndicator(
                  value: 0.6,
                  minHeight: 5,
                  backgroundColor: AC.bg,
                  valueColor: AlwaysStoppedAnimation(AC.purple),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── AI INSIGHT ─────────────────────────────────────────────────────────────
  Widget _buildAIInsightCard() {
    return Container(
      width: double.infinity,
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AC.purpleGlow,
              border: Border.all(color: AC.purpleBorder),
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/aria_logo.png', fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI INSIGHT',
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.bodyText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      const TextSpan(text: 'Your peak focus is '),
                      TextSpan(
                        text: '10–12 AM',
                        style: GoogleFonts.spaceGrotesk(
                          color: _orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const TextSpan(
                        text: '. Start deep work now for maximum productivity.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AC.card,
        border: Border(top: BorderSide(color: AC.cardBorder, width: 0.8)),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        left: 4,
        right: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isActive = index == _selectedNav;
          final isAI = index == 2;

          return GestureDetector(
            onTap: () => _navigateToTab(index),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAI)
                    // Logo in a circle for the AI tab
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? AC.purple : AC.purpleBorder,
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/aria_logo.png',
                          width: 26,
                          height: 26,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Icon(
                      item['icon'] as IconData,
                      size: 22,
                      color: isActive ? AC.purple : AC.iconTint,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.spaceGrotesk(
                      color: isActive ? AC.purple : AC.bodyText,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
