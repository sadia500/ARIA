import 'package:flutter/material.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';

class ARIASplashScreen extends StatefulWidget {
  const ARIASplashScreen({super.key});

  @override
  State<ARIASplashScreen> createState() => _ARIASplashScreenState();
}

class _ARIASplashScreenState extends State<ARIASplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<double> _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fade, curve: Curves.easeIn);

  int _activeDot = 0;

  @override
  void initState() {
    super.initState();
    _dots.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _activeDot = (_activeDot + 1) % 3);
        _dots..reset()..forward();
      }
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _fade.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // Ambient breathing glow — no hard circles
            const Positioned.fill(child: AmbientGlow()),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Pulsing rings + logo
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          _ring(160 * _pulseAnim.value, AC.purpleRing1),
                          _ring(120 * _pulseAnim.value, AC.purpleRing2),
                          const AriaLogo(size: 100),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text('ARIA', style: AText.splashTitle),
                  const SizedBox(height: 10),
                  const Text('YOUR DAY, OPTIMIZED BY AI', style: AText.splashSub),
                  const SizedBox(height: 10),

                  Container(
                    width: 30, height: 2,
                    decoration: BoxDecoration(
                      color: AC.purpleDark,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),

                  const Spacer(flex: 2),

                  const Text('INITIALIZING CORE', style: AText.initCore),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = i == _activeDot;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 10 : 7,
                        height: active ? 10 : 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? AC.purple : AC.dotInactive,
                          boxShadow: active
                              ? const [BoxShadow(
                                  color: AC.purpleShadow3,
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )]
                              : null,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 48),
                  const Text('NEURAL ENGINE V4.0.2', style: AText.tiny),
                  const SizedBox(height: 4),
                  const Text(
                    '© 2024 ARIA Neural Systems. All rights reserved.',
                    style: AText.tinier,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1),
        ),
      );
}