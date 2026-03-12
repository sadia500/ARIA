import 'package:flutter/material.dart';
import '../theme/aria_theme.dart';

// ─── Logo ─────────────────────────────────────────────────────────────────────
class AriaLogo extends StatelessWidget {
  final double size;
  const AriaLogo({super.key, this.size = 78});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/aria_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

// ─── Small logo badge (top-left on Login) ─────────────────────────────────────
class AriaLogoBadge extends StatelessWidget {
  const AriaLogoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AC.logoBadge,
        border: Border.all(color: AC.purpleBorder, width: 1),
      ),
      padding: const EdgeInsets.all(5),
      child: Image.asset('assets/aria_logo.png', fit: BoxFit.contain),
    );
  }
}

// ─── Animated ambient glow background ────────────────────────────────────────
// A soft, blurred blob of purple light that slowly breathes in and out.
// No hard edges, no visible circle outlines — pure ambient atmosphere.
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

  late final Animation<double> _glow =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => CustomPaint(
        painter: _AmbientGlowPainter(_glow.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AmbientGlowPainter extends CustomPainter {
  final double t; // 0.0 → 1.0 breathing value
  const _AmbientGlowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Top glow — breathes between 25% and 45% opacity
    final topAlpha = (0.25 + 0.20 * t);
    _drawBlob(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.18),
      radius: size.width * 0.85,
      color: const Color(0xFF6B35C8),
      opacity: topAlpha,
    );

    // Bottom-left accent glow — subtle, breathes opposite phase
    final bottomAlpha = (0.12 + 0.10 * (1 - t));
    _drawBlob(
      canvas,
      center: Offset(size.width * 0.15, size.height * 0.82),
      radius: size.width * 0.55,
      color: const Color(0xFF4A1F9A),
      opacity: bottomAlpha,
    );
  }

  void _drawBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    // Use 5-stop gradient so the falloff is ultra-smooth — no hard edge at all
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.6),
          color.withValues(alpha: opacity * 0.25),
          color.withValues(alpha: opacity * 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.55, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Draw as a rect so the gradient fills edge-to-edge with no clipped circle
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: radius * 2,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AmbientGlowPainter old) => old.t != t;
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

// ─── Input field ──────────────────────────────────────────────────────────────
class AriaInputField extends StatelessWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Color borderColor;

  const AriaInputField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.borderColor = AC.inputBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AC.input,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: TextField(
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AC.hint, fontSize: 15),
          prefixIcon: Icon(prefixIcon, color: AC.iconTint, size: 20),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Gradient button ──────────────────────────────────────────────────────────
class AriaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AriaButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: AGrad.button,
          boxShadow: AShadow.button,
        ),
        alignment: Alignment.center,
        child: Text(label, style: AText.button),
      ),
    );
  }
}

// ─── Screen entrance animation ────────────────────────────────────────────────
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

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

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