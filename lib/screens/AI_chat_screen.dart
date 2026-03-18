import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const Color _bg = Color(0xFF0E0B1E);
const Color _glass = Color(0x14FFFFFF);
const Color _glassBorder = Color(0x28FFFFFF);
const Color _violet = Color(0xFF8A6CD1);
const Color _violetGlow = Color(0xFF4D3385);
const Color _mint = Color(0xFF3DD68C);
const Color _rose = Color(0xFFFF6B8A);

class AriaAIScreen extends StatefulWidget {
  const AriaAIScreen({super.key});
  @override
  State<AriaAIScreen> createState() => _AriaAIScreenState();
}

class _AriaAIScreenState extends State<AriaAIScreen>
    with TickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  bool _isTyping = false;
  bool _isThinking = false;
  bool _micActive = false;
  bool _showSuggestions = true;

  // ── Controllers
  late final AnimationController _nebulaCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  late final AnimationController _breathCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final AnimationController _dotCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  late final AnimationController _micCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  late final AnimationController _suggestionCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  late final Animation<double> _nebula = CurvedAnimation(
    parent: _nebulaCtrl,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _breath = CurvedAnimation(
    parent: _breathCtrl,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _suggestionFade = CurvedAnimation(
    parent: _suggestionCtrl,
    curve: Curves.easeOut,
  );

  // ── Suggested prompts (shown when idle)
  static const _suggestions = [
    ('📋', 'What\'s on my agenda today?'),
    ('⚡', 'Start a focus session now'),
    ('📊', 'Show my productivity stats'),
  ];

  // ── Messages
  final List<_Msg> _msgs = [
    _Msg.divider('Today'),
    _Msg.aria(
      'Hello! I\'ve analyzed your upcoming schedule — you have a clear gap at 2:00 PM. Want me to lock in a deep-focus session for the \'Project Synthesis\' report?',
      '10:24 AM',
      showSender: true,
    ),
    _Msg.user(
      'That sounds perfect. Can you also check if I have any pending tasks for the design review tomorrow?',
      '10:25 AM',
    ),
    _Msg.aria(
      'Checking... You have 3 pending items. I recommend completing the high-priority asset export first. Should I prepare the full task list?',
      '10:25 AM',
      showSender: false,
    ),
    _Msg.card(
      _TaskSuggestion(
        badge: 'New Task Suggestion',
        title: 'Project Synthesis',
        subtitle: 'Design report — final round',
        priority: 'High',
        priorityColor: _rose,
        duration: '45 min',
        time: '10:26 AM',
      ),
    ),
  ];

  int _cannedIdx = 0;
  static const _ariaCanned = [
    'Done! Project Synthesis is locked in at 2:00 PM with Focus Shield enabled.',
    'Your peak productivity window is 9–11 AM. I\'ve front-loaded your hard tasks there.',
    'You\'re on a 7-day focus streak — your best this month. Keep the momentum going.',
    'I\'ve noticed you perform best after a 10-minute break. Should I schedule one now?',
  ];

  void _send([String? prefilled]) {
    final text = prefilled ?? _inputCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _msgs.add(_Msg.user(text, _now()));
      _inputCtrl.clear();
      _isTyping = false;
      _isThinking = true;
      _showSuggestions = false;
    });
    _scrollLater();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _msgs.add(
          _Msg.aria(
            _ariaCanned[_cannedIdx++ % _ariaCanned.length],
            _now(),
            showSender: true,
          ),
        );
      });
      _scrollLater();
    });
  }

  void _onTextChanged(String v) {
    setState(() {
      _isTyping = v.isNotEmpty;
      if (v.isNotEmpty) {
        _showSuggestions = false;
      }
    });
  }

  void _toggleMic() {
    HapticFeedback.mediumImpact();
    setState(() => _micActive = !_micActive);
  }

  void _scrollLater() => Future.delayed(const Duration(milliseconds: 120), () {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  });

  String _now() {
    final n = DateTime.now();
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final m = n.minute.toString().padLeft(2, '0');
    return '$h:$m ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool get _hasMessages => _msgs.any((m) => !m.isDivider);

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _nebulaCtrl.dispose();
    _breathCtrl.dispose();
    _dotCtrl.dispose();
    _micCtrl.dispose();
    _suggestionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Nebula background
          AnimatedBuilder(
            animation: _nebula,
            builder: (_, _) => CustomPaint(
              painter: _NebulaPainter(_nebula.value),
              child: const SizedBox.expand(),
            ),
          ),
          // ── Grain texture
          Positioned.fill(child: CustomPaint(painter: _GrainPainter())),

          // ── Main layout
          Column(
            children: [
              SafeArea(bottom: false, child: _buildTopBar()),
              _buildLogoHeader(),
              Expanded(
                child: _hasMessages ? _buildMessageList() : _buildEmptyState(),
              ),
              _buildBottomArea(),
              // ← space for shell bottom nav
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ← FIXED: back button now actually works
          _iconBtn(Icons.arrow_back_ios_new_rounded, () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          }),
          Row(
            children: [
              _iconBtn(Icons.search_rounded, () {}),
              const SizedBox(width: 8),
              // User avatar
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_violet, Color(0xFF3A2470)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: _violet.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _mint,
                        border: Border.all(color: _bg, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: _glass,
        border: Border.all(color: _glassBorder),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 16),
    ),
  );

  // ── Logo header ───────────────────────────────────────────────────────────────
  Widget _buildLogoHeader() {
    return AnimatedBuilder(
      animation: _breath,
      builder: (_, _) => Column(
        children: [
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _violet.withValues(alpha: 0.3 + 0.15 * _breath.value),
                      _violet.withValues(alpha: 0.08 + 0.06 * _breath.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _violet.withValues(
                        alpha: 0.4 + 0.25 * _breath.value,
                      ),
                      blurRadius: 30 + 15 * _breath.value,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Image.asset(
                  'assets/aria_logo.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ARIA AI',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 12,
              letterSpacing: 3.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x208A6CD1),
                  Color(0x388A6CD1),
                  Color(0x208A6CD1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'Good Morning ☀️'
        : h < 17
        ? 'Good Afternoon 🎯'
        : 'Good Evening 🌙';
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        child: Column(
          children: [
            Text(
              greeting,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How can I help you focus today?',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ..._suggestions.map((s) => _buildStartCard(s.$1, s.$2)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartCard(String emoji, String text) {
    return GestureDetector(
      onTap: () => _send(text),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _glass,
          border: Border.all(color: _glassBorder),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      // ← FIXED: extra bottom padding so messages clear the shell nav
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _msgs.length + (_isThinking ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _msgs.length) return _buildTypingIndicator();
        return _buildMsgItem(_msgs[i]);
      },
    );
  }

  // ── Message item ──────────────────────────────────────────────────────────────
  Widget _buildMsgItem(_Msg msg) {
    if (msg.isDivider) return _buildDivider(msg.dividerLabel!);
    if (msg.isCard) return _buildTaskCard(msg.card!);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(msg.isAria ? -12 * (1 - t) : 12 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: msg.isAria
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.isAria) _ariaMiniAvatar(),
            Flexible(
              child: Column(
                crossAxisAlignment: msg.isAria
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  if (msg.isAria && msg.showSender)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 5),
                      child: Text(
                        'ARIA',
                        style: GoogleFonts.spaceGrotesk(
                          color: _violet.withValues(alpha: 0.55),
                          fontSize: 9,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(msg.isAria ? 4 : 20),
                      bottomRight: Radius.circular(msg.isAria ? 20 : 4),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(msg.isAria ? 4 : 20),
                            bottomRight: Radius.circular(msg.isAria ? 20 : 4),
                          ),
                          color: msg.isAria
                              ? Colors.white.withValues(alpha: 0.08)
                              : _violet.withValues(alpha: 0.28),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: msg.isAria ? 0.10 : 0.18,
                            ),
                          ),
                        ),
                        child: Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.time,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: 9,
                      letterSpacing: 0.3,
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

  Widget _buildDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ariaMiniAvatar() => Container(
    width: 26,
    height: 26,
    margin: const EdgeInsets.only(right: 8, bottom: 20),
    child: ClipOval(
      child: Image.asset(
        'assets/aria_logo.png',
        width: 26,
        height: 26,
        fit: BoxFit.cover,
      ),
    ),
  );

  // ── Task card ─────────────────────────────────────────────────────────────────
  Widget _buildTaskCard(_TaskSuggestion s) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(
        scale: 0.92 + 0.08 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _ariaMiniAvatar(),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _violet.withValues(alpha: 0.55),
                          _violetGlow.withValues(alpha: 0.70),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _violet.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(20),
                            ),
                            child: CustomPaint(painter: _CardShimmerPainter()),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      s.badge,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                s.title,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s.subtitle,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _cardStat(
                                    'PRIORITY',
                                    s.priority,
                                    Icons.bolt_rounded,
                                    s.priorityColor,
                                  ),
                                  const SizedBox(width: 10),
                                  _cardStat(
                                    'DURATION',
                                    s.duration,
                                    Icons.timer_outlined,
                                    Colors.white.withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.10),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ConfirmButton(
                                onConfirmed: () {
                                  setState(() {
                                    _msgs.add(
                                      _Msg.aria(
                                        'Done! Project Synthesis is locked in at 2:00 PM with Focus Shield active.',
                                        _now(),
                                        showSender: true,
                                      ),
                                    );
                                  });
                                  _scrollLater();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 7,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 5),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ariaMiniAvatar(),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(20),
                  ),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = ((_dotCtrl.value * 3) - i).clamp(0.0, 1.0);
                      final pulse = math.sin(phase * math.pi);
                      return Container(
                        margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                        width: 6,
                        height: 6 + 4 * pulse,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _violet.withValues(alpha: 0.4 + 0.55 * pulse),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom area ───────────────────────────────────────────────────────────────
  Widget _buildBottomArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: _showSuggestions && !_isThinking
              ? _buildSuggestions()
              : const SizedBox.shrink(),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildSuggestions() {
    return FadeTransition(
      opacity: _suggestionFade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          children: _suggestions.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + i * 80),
              curve: Curves.easeOut,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: child,
                ),
              ),
              child: GestureDetector(
                onTap: () => _send(s.$2),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _glass,
                    border: Border.all(color: _glassBorder),
                  ),
                  child: Row(
                    children: [
                      Text(s.$1, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.$2,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.north_west_rounded,
                        color: Colors.white.withValues(alpha: 0.18),
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: _isTyping
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: _isTyping
                              ? _violet.withValues(alpha: 0.50)
                              : Colors.white.withValues(alpha: 0.12),
                          width: _isTyping ? 1.5 : 1,
                        ),
                        boxShadow: _isTyping
                            ? [
                                BoxShadow(
                                  color: _violet.withValues(alpha: 0.12),
                                  blurRadius: 20,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputCtrl,
                              focusNode: _focusNode,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              onChanged: _onTextChanged,
                              onSubmitted: (_) => _send(),
                              textInputAction: TextInputAction.send,
                              decoration: InputDecoration(
                                hintText: 'Ask ARIA anything...',
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleMic,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: AnimatedBuilder(
                                animation: _micCtrl,
                                builder: (_, _) => _micActive
                                    ? CustomPaint(
                                        size: const Size(24, 20),
                                        painter: _WaveformPainter(
                                          _micCtrl.value,
                                          _violet,
                                        ),
                                      )
                                    : Icon(
                                        Icons.mic_none_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isTyping
                            ? LinearGradient(
                                colors: [_violet, _violetGlow],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _isTyping
                            ? null
                            : Colors.white.withValues(alpha: 0.07),
                        border: _isTyping
                            ? null
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                        boxShadow: _isTyping
                            ? [
                                BoxShadow(
                                  color: _violet.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _isTyping
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.22),
                        size: 20,
                      ),
                    ),
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

// ─── Confirm button ───────────────────────────────────────────────────────────
class _ConfirmButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  const _ConfirmButton({required this.onConfirmed});
  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton>
    with SingleTickerProviderStateMixin {
  bool _confirmed = false;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.95,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  void _tap() async {
    if (_confirmed) return;
    HapticFeedback.mediumImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    setState(() => _confirmed = true);
    await Future.delayed(const Duration(milliseconds: 700));
    widget.onConfirmed();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, _) => Transform.scale(
          scale: _scale.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _confirmed ? const Color(0xFF1A3D28) : Colors.white,
              border: _confirmed
                  ? Border.all(
                      color: const Color(0xFF34A853).withValues(alpha: 0.4),
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (_confirmed ? const Color(0xFF34A853) : Colors.white)
                      .withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _confirmed
                      ? const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF34A853),
                          size: 15,
                          key: ValueKey('check'),
                        )
                      : Icon(
                          Icons.check_circle_rounded,
                          color: _violetGlow,
                          size: 15,
                          key: const ValueKey('circle'),
                        ),
                ),
                const SizedBox(width: 7),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _confirmed ? 'Synced!' : 'Confirm & Sync',
                    key: ValueKey(_confirmed),
                    style: GoogleFonts.spaceGrotesk(
                      color: _confirmed ? const Color(0xFF34A853) : _violetGlow,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
}

// ─── Data models ──────────────────────────────────────────────────────────────
class _Msg {
  final bool isAria, isCard, isDivider, showSender;
  final String text, time;
  final String? dividerLabel;
  final _TaskSuggestion? card;

  const _Msg({
    required this.isAria,
    required this.text,
    required this.time,
    this.isCard = false,
    this.isDivider = false,
    this.showSender = false,
    this.dividerLabel,
    this.card,
  });

  factory _Msg.aria(String t, String time, {bool showSender = false}) =>
      _Msg(isAria: true, text: t, time: time, showSender: showSender);
  factory _Msg.user(String t, String time) =>
      _Msg(isAria: false, text: t, time: time);
  factory _Msg.card(_TaskSuggestion c) =>
      _Msg(isAria: true, text: '', time: c.time, isCard: true, card: c);
  factory _Msg.divider(String label) => _Msg(
    isAria: false,
    text: '',
    time: '',
    isDivider: true,
    dividerLabel: label,
  );
}

class _TaskSuggestion {
  final String badge, title, subtitle, priority, duration, time;
  final Color priorityColor;
  const _TaskSuggestion({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.priorityColor,
    required this.duration,
    required this.time,
  });
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
              colors: [const Color(0x458A6CD1), const Color(0x008A6CD1)],
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
      size.width * 0.60,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x386B4DA8), const Color(0x006B4DA8)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx * 1.65, cy * 0.85),
                radius: size.width * 0.60,
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
  final _rng = math.Random(42);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.015);
    for (int i = 0; i < 1000; i++) {
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

class _CardShimmerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(0.4, 1),
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CardShimmerPainter _) => false;
}

class _WaveformPainter extends CustomPainter {
  final double t;
  final Color color;
  _WaveformPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    const bars = 5;
    final barW = size.width / (bars * 2 - 1);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    for (int i = 0; i < bars; i++) {
      final phase = math.sin((t * 2 * math.pi) + i * 0.8);
      final h = size.height * (0.3 + 0.55 * ((phase + 1) / 2));
      final x = i * barW * 2 + barW / 2;
      final cy = size.height / 2;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.t != t;
}
