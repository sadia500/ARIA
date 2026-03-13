import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';

class ARIASplashScreen extends StatefulWidget {
  const ARIASplashScreen({super.key});

  @override
  State<ARIASplashScreen> createState() => _ARIASplashScreenState();
}

class _ARIASplashScreenState extends State<ARIASplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _logoCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1000),
  );

  late final List<AnimationController> _letterCtrls = List.generate(
    4, (i) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460),
    ),
  );

  late final AnimationController _subtitleCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 600),
  );

  late final AnimationController _bottomCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 500),
  );

  late final AnimationController _exitCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

  late final Animation<double> _logoScale =
      Tween<double>(begin: 0.88, end: 1.0).animate(
          CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));

  late final Animation<double> _exitFade =
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut);

  static const _letters = ['A', 'R', 'I', 'A'];

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));

    for (int i = 0; i < _letterCtrls.length; i++) {
      _letterCtrls[i].forward();
      await Future.delayed(const Duration(milliseconds: 75));
    }

    await Future.delayed(const Duration(milliseconds: 120));
    _subtitleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _bottomCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 2000));
    await _exitCtrl.forward();

    if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    for (final c in _letterCtrls) {
      c.dispose();
    }
    _subtitleCtrl.dispose();
    _bottomCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: AnimatedBuilder(
        animation: _exitCtrl,
        builder: (_, child) => Opacity(
          opacity: 1.0 - _exitFade.value,
          child: child,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: AmbientGlow()),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: const AriaLogo(size: 92),
                    ),
                  ),

                  const SizedBox(height: 44),

                  // ── ARIA staggered letters — Space Grotesk Bold
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_letters.length, (i) {
                      final fade = CurvedAnimation(
                          parent: _letterCtrls[i], curve: Curves.easeOut);
                      final slide = Tween<double>(begin: 14, end: 0).animate(
                          CurvedAnimation(
                              parent: _letterCtrls[i],
                              curve: Curves.easeOutCubic));
                      return AnimatedBuilder(
                        animation: _letterCtrls[i],
                        builder: (_, _) => Opacity(
                          opacity: fade.value,
                          child: Transform.translate(
                            offset: Offset(0, slide.value),
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFCBAAFF),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                _letters[i],
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 54,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 8,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  // ── Thin divider + subtitle
                  AnimatedBuilder(
                    animation: _subtitleCtrl,
                    builder: (_, _) {
                      final fade = CurvedAnimation(
                          parent: _subtitleCtrl, curve: Curves.easeOut);
                      final slide = Tween<double>(begin: 8, end: 0).animate(
                          CurvedAnimation(
                              parent: _subtitleCtrl,
                              curve: Curves.easeOutCubic));
                      return Opacity(
                        opacity: fade.value,
                        child: Transform.translate(
                          offset: Offset(0, slide.value),
                          child: Column(
                            children: [
                              Container(
                                width: 32,
                                height: 1,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(1),
                                  gradient: const LinearGradient(colors: [
                                    Colors.transparent,
                                    Color(0x44FFFFFF),
                                    Colors.transparent,
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'YOUR DAY, OPTIMIZED BY AI',
                                style: GoogleFonts.spaceGrotesk(
                                  color: const Color(0x55FFFFFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 3.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Bottom
            Positioned(
              bottom: 38,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _bottomCtrl, curve: Curves.easeOut),
                child: Column(
                  children: [
                    Text(
                      'NEURAL ENGINE V4.0.2',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0x28FFFFFF),
                        fontSize: 9,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '© 2025 ARIA Neural Systems',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0x18FFFFFF),
                        fontSize: 9,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}