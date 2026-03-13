import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/aria_theme.dart';

// ─── Logo ─────────────────────────────────────────────────────────────────────
class AriaLogo extends StatelessWidget {
  final double size;
  const AriaLogo({super.key, this.size = 78});

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset(
      'assets/aria_logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

// ─── Small logo badge ─────────────────────────────────────────────────────────
class AriaLogoBadge extends StatelessWidget {
  const AriaLogoBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AC.bg,
      border: Border.all(color: AC.purpleBorder, width: 1),
    ),
    padding: const EdgeInsets.all(6),
    child: Image.asset('assets/aria_logo.png', fit: BoxFit.contain),
  );
}

// ─── Ambient breathing glow ───────────────────────────────────────────────────
class AmbientGlow extends StatefulWidget {
  const AmbientGlow({super.key});
  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  late final Animation<double> _glow = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glow,
    builder: (_, _) => CustomPaint(
      painter: _GlowPainter(_glow.value),
      child: const SizedBox.expand(),
    ),
  );
}

class _GlowPainter extends CustomPainter {
  final double t;
  const _GlowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _blob(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.18),
      radius: size.width * 0.85,
      color: const Color(0xFF6B35C8),
      opacity: 0.25 + 0.20 * t,
    );
    _blob(
      canvas,
      center: Offset(size.width * 0.15, size.height * 0.82),
      radius: size.width * 0.55,
      color: const Color(0xFF4A1F9A),
      opacity: 0.12 + 0.10 * (1 - t),
    );
  }

  void _blob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    canvas.drawRect(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.6),
            color.withValues(alpha: opacity * 0.25),
            color.withValues(alpha: opacity * 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.55, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

// ─── Field label ──────────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String text;
  final bool purple;
  const FieldLabel(this.text, {super.key, this.purple = false});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: purple ? AText.purpleLabel : AText.fieldLabel);
}

// ─── Input field with animated focus glow + error ─────────────────────────────
class AriaInputField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Color borderColor;
  final TextEditingController? controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const AriaInputField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.borderColor = AC.inputBorder,
    this.controller,
    this.errorText,
    this.onChanged,
  });

  @override
  State<AriaInputField> createState() => _AriaInputFieldState();
}

class _AriaInputFieldState extends State<AriaInputField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(
      () => _focus.hasFocus ? _ctrl.forward() : _ctrl.reverse(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, child) {
            final border = hasError
                ? AC.error
                : Color.lerp(widget.borderColor, AC.purple, _anim.value)!;
            final glow = hasError
                ? AC.error.withValues(alpha: 0.15 * _anim.value)
                : AC.purple.withValues(alpha: 0.12 * _anim.value);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AC.input,
                border: Border.all(color: border, width: 1.5),
                boxShadow: [
                  BoxShadow(color: glow, blurRadius: 12, spreadRadius: 1),
                ],
              ),
              child: child,
            );
          },
          child: TextField(
            focusNode: _focus,
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.spaceGrotesk(color: AC.hint, fontSize: 15),
              prefixIcon: Icon(widget.prefixIcon, color: AC.iconTint, size: 20),
              suffixIcon: widget.suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: widget.suffix,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, color: AC.error, size: 13),
              const SizedBox(width: 5),
              Text(
                widget.errorText!,
                style: GoogleFonts.spaceGrotesk(
                  color: AC.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Gradient button with loading ─────────────────────────────────────────────
class AriaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const AriaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isLoading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isLoading
            ? const LinearGradient(
                colors: [Color(0xFF5A3BAA), Color(0xFF7B52CC)],
              )
            : AGrad.button,
        boxShadow: isLoading ? [] : AShadow.button,
      ),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(label, style: AText.button),
    ),
  );
}

// ─── Google Sign-In button ────────────────────────────────────────────────────
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isLoading ? null : onTap,
    child: Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A1830),
        border: Border.all(color: AC.cardBorder, width: 1.5),
      ),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(painter: _GoogleIconPainter()),
                ),
                const SizedBox(width: 10),
                Text(
                  'Continue with Google',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1;
    final sw = size.width * 0.18;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    for (final e in [
      [-1.57, 1.57, 0xFFEA4335],
      [1.57, 3.14, 0xFF4285F4],
      [-1.57, -1.57, 0xFFFBBC05],
      [0.0, 1.57, 0xFF34A853],
    ]) {
      canvas.drawArc(
        rect,
        e[0] as double,
        e[1] as double,
        false,
        Paint()
          ..color = Color(e[2] as int)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Password strength bar ────────────────────────────────────────────────────
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  int get _strength {
    if (password.isEmpty) return 0;
    int s = 0;
    if (password.length >= 8) s++;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s++;
    return s;
  }

  Color get _color => switch (_strength) {
    1 => const Color(0xFFEA4335),
    2 => const Color(0xFFFBBC05),
    3 => const Color(0xFF4285F4),
    4 => const Color(0xFF34A853),
    _ => Colors.transparent,
  };

  String get _label => switch (_strength) {
    1 => 'Weak',
    2 => 'Fair',
    3 => 'Good',
    4 => 'Strong',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i < _strength ? _color : const Color(0xFF2A2550),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _label,
            key: ValueKey(_label),
            style: GoogleFonts.spaceGrotesk(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Success animation ────────────────────────────────────────────────────────
class SuccessAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  const SuccessAnimation({super.key, required this.onComplete});

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  late final Animation<double> _fade = Tween<double>(begin: 0.0, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        ),
      );

  @override
  void initState() {
    super.initState();
    _ctrl.forward().then(
      (_) =>
          Future.delayed(const Duration(milliseconds: 700), widget.onComplete),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, _) => FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0D2B0D),
            border: Border.all(color: const Color(0xFF34A853), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34A853).withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF34A853),
            size: 36,
          ),
        ),
      ),
    ),
  );
}

// ─── Screen entrance ──────────────────────────────────────────────────────────
class ScreenEntrance extends StatefulWidget {
  final Widget child;
  const ScreenEntrance({super.key, required this.child});
  @override
  State<ScreenEntrance> createState() => _ScreenEntranceState();
}

class _ScreenEntranceState extends State<ScreenEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
