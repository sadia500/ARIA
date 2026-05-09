// lib/screens/main_shell.dart
// ignore_for_file: unnecessary_underscores

import 'dart:ui' as ui;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';

import 'dashboard.dart';
import 'Schedule_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'aria_chat_shell.dart'; // new wrapper that holds drawer + chat

class MainShell extends StatefulWidget {
  final String userName;
  final int initialIndex;

  const MainShell({super.key, required this.userName, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late int _currentIndex;
  bool _isOffline = false;
  StreamSubscription? _connectivitySub;

  late final List<Widget> _pages;

  late final AnimationController _indicatorCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 300),
  )..forward();

  late final List<AnimationController> _iconCtrls = List.generate(
    5, (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400)),
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _pages = [
      _KeepAlivePage(child: ARIADashboard(userName: widget.userName, shellContext: _navigateTo)),
      _KeepAlivePage(child: ARIAScheduleScreen(userName: widget.userName)),
      _KeepAlivePage(child: const AriaChatShell()), // drawer shell replaces ChatListScreen
      _KeepAlivePage(child: ARIAAnalyticsScreen(userName: widget.userName)),
      _KeepAlivePage(child: ARIAProfileScreen(userName: widget.userName, onNavigate: _navigateTo)),
    ];

    _iconCtrls[_currentIndex].forward();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final offline = result.contains(ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);
    });
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
    _connectivitySub?.cancel();
    _indicatorCtrl.dispose();
    for (final c in _iconCtrls) c.dispose();
    super.dispose();
  }

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded,         outlinedIcon: Icons.home_outlined,          label: 'Home'),
    _NavItem(icon: Icons.calendar_month_rounded,outlinedIcon: Icons.calendar_month_outlined,label: 'Schedule'),
    _NavItem(icon: null,                        outlinedIcon: null,                         label: 'AI'),
    _NavItem(icon: Icons.bar_chart_rounded,     outlinedIcon: Icons.bar_chart_outlined,     label: 'Analytics'),
    _NavItem(icon: Icons.person_rounded,        outlinedIcon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Column(children: [
        if (_isOffline)
          Container(
            width: double.infinity,
            color: const Color(0xFFE05C3A),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SafeArea(bottom: false, child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text('Offline — changes will sync when reconnected',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            )),
          ),
        Expanded(child: IndexedStack(index: _currentIndex, children: _pages)),
      ]),
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
            color: const Color(0xFF0D0B1A).withOpacity(0.92),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07), width: 0.8)),
          ),
          padding: EdgeInsets.only(top: 10, bottom: bottomPad > 0 ? bottomPad : 12, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item     = _navItems[i];
              final isActive = i == _currentIndex;
              final isCenter = i == 2;

              return GestureDetector(
                onTap: () => _navigateTo(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _iconCtrls[i],
                  builder: (_, __) {
                    final bounce = Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(parent: _iconCtrls[i], curve: Curves.elasticOut),
                    ).value;
                    final scale = isActive ? (0.85 + 0.15 * bounce) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (isCenter) _buildCenterTab(isActive)
                          else _buildRegularTab(item, isActive),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: GoogleFonts.spaceGrotesk(
                              color: isActive ? AC.purple : Colors.white.withOpacity(0.35),
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                            ),
                            child: Text(item.label),
                          ),
                        ]),
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
      width: 44, height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive ? AC.purple.withOpacity(0.15) : Colors.transparent,
      ),
      child: Icon(isActive ? item.icon : item.outlinedIcon,
        color: isActive ? AC.purple : Colors.white.withOpacity(0.35), size: 22),
    );
  }

  Widget _buildCenterTab(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 44, height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive ? AC.purple.withOpacity(0.15) : Colors.transparent,
        border: isActive
            ? Border.all(color: AC.purple.withOpacity(0.4), width: 1)
            : Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Padding(padding: const EdgeInsets.all(5),
        child: ClipOval(child: Image.asset('assets/aria_logo.png', fit: BoxFit.cover))),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) { super.build(context); return widget.child; }
}

class _NavItem {
  final IconData? icon;
  final IconData? outlinedIcon;
  final String label;
  const _NavItem({required this.icon, required this.outlinedIcon, required this.label});
}