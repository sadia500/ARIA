// lib/screens/main_shell.dart
// ─────────────────────────────────────────────────────────────────────────────
// Central navigation shell — wraps all 5 tabs with a shared bottom nav bar.
// Replace all individual bottom navs in each screen with this shell.
// ─────────────────────────────────────────────────────────────────────────────

// ignore_for_file: unnecessary_underscores

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';

// Import all tab screens
import 'dashboard.dart';
import 'Schedule_screen.dart';
import 'AI_chat_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  final String userName;
  final int initialIndex;

  const MainShell({super.key, required this.userName, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late int _currentIndex;

  // Keep all pages alive with AutomaticKeepAlive
  late final List<Widget> _pages;

  // Animation controller for tab switch indicator
  late final AnimationController _indicatorCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  // Per-tab animation controllers for icon bounce
  late final List<AnimationController> _iconCtrls = List.generate(
    5,
    (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    ),
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _pages = [
      _KeepAlivePage(
        child: ARIADashboard(
          userName: widget.userName,
          shellContext: _navigateTo,
        ),
      ),
      _KeepAlivePage(child: ARIAScheduleScreen(userName: widget.userName)),
      _KeepAlivePage(child: const AriaAIScreen()),
      _KeepAlivePage(child: ARIAAnalyticsScreen(userName: widget.userName)),
      _KeepAlivePage(
        child: ARIAProfileScreen(
          userName: widget.userName,
          onNavigate: _navigateTo,
        ),
      ),
    ];

    // Bounce the initial tab icon
    _iconCtrls[_currentIndex].forward();
  }

  void _navigateTo(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    _iconCtrls[index].reset();
    _iconCtrls[index].forward();
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    for (final c in _iconCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Nav items config ──────────────────────────────────────────────────────
  static const _navItems = [
    _NavItem(
      icon: Icons.home_rounded,
      outlinedIcon: Icons.home_outlined,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.calendar_month_rounded,
      outlinedIcon: Icons.calendar_month_outlined,
      label: 'Schedule',
    ),
    _NavItem(icon: null, outlinedIcon: null, label: 'AI'), // center ARIA logo
    _NavItem(
      icon: Icons.bar_chart_rounded,
      outlinedIcon: Icons.bar_chart_outlined,
      label: 'Analytics',
    ),
    _NavItem(
      icon: Icons.person_rounded,
      outlinedIcon: Icons.person_outline_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0B1A).withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
                width: 0.8,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            top: 10,
            bottom: bottomPad > 0 ? bottomPad : 12,
            left: 4,
            right: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final isActive = i == _currentIndex;
              final isCenter = i == 2; // ARIA logo tab

              return GestureDetector(
                onTap: () => _navigateTo(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _iconCtrls[i],
                  builder: (_, __) {
                    final bounce = Tween<double>(begin: 0.0, end: 1.0)
                        .animate(
                          CurvedAnimation(
                            parent: _iconCtrls[i],
                            curve: Curves.elasticOut,
                          ),
                        )
                        .value;
                    final scale = isActive ? (0.85 + 0.15 * bounce) : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCenter)
                              _buildCenterTab(isActive)
                            else
                              _buildRegularTab(item, isActive),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: GoogleFonts.spaceGrotesk(
                                color: isActive
                                    ? AC.purple
                                    : Colors.white.withValues(alpha: 0.35),
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              child: Text(item.label),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildRegularTab(_NavItem item, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive
            ? AC.purple.withValues(alpha: 0.15)
            : Colors.transparent,
      ),
      child: Icon(
        isActive ? item.icon : item.outlinedIcon,
        color: isActive ? AC.purple : Colors.white.withValues(alpha: 0.35),
        size: 22,
      ),
    );
  }

  Widget _buildCenterTab(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive
            ? AC.purple.withValues(alpha: 0.15)
            : Colors.transparent,
        border: isActive
            ? Border.all(color: AC.purple.withValues(alpha: 0.4), width: 1)
            : Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ClipOval(
          child: Image.asset('assets/aria_logo.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}

// ─── Keep-alive wrapper ───────────────────────────────────────────────────────
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─── Nav item model ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData? icon;
  final IconData? outlinedIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });
}
