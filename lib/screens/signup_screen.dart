import 'package:flutter/material.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';

class ARIASignUpScreen extends StatefulWidget {
  const ARIASignUpScreen({super.key});

  @override
  State<ARIASignUpScreen> createState() => _ARIASignUpScreenState();
}

class _ARIASignUpScreenState extends State<ARIASignUpScreen> {
  bool _obscureCreate = true;
  bool _obscureVerify = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Stack(
        children: [
          // Ambient breathing glow
          const Positioned.fill(child: AmbientGlow()),

          SafeArea(
            child: ScreenEntrance(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  const AriaLogo(size: 64),

                  const SizedBox(height: 18),

                  const Text('Create Account', style: AText.title),
                  const SizedBox(height: 6),
                  const Text(
                    'Start your AI-powered productivity\njourney',
                    textAlign: TextAlign.center,
                    style: AText.subtitle,
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AC.card,
                          border: Border.all(color: AC.cardBorder, width: 1),
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('FULL NAME', purple: true),
                            const SizedBox(height: 8),
                            const AriaInputField(
                              hintText: 'John Doe',
                              prefixIcon: Icons.person_outline,
                              borderColor: AC.purpleRing2,
                            ),

                            const SizedBox(height: 18),

                            const FieldLabel('EMAIL ADDRESS', purple: true),
                            const SizedBox(height: 8),
                            const AriaInputField(
                              hintText: 'aria@intelligence.ai',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 18),

                            const FieldLabel('CREATE PASSWORD', purple: true),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscureCreate,
                              suffix: GestureDetector(
                                onTap: () => setState(
                                    () => _obscureCreate = !_obscureCreate),
                                child: Icon(
                                  _obscureCreate
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AC.iconTint,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            const FieldLabel('VERIFY PASSWORD', purple: true),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: '••••••••',
                              prefixIcon: Icons.shield_outlined,
                              obscureText: _obscureVerify,
                              suffix: GestureDetector(
                                onTap: () => setState(
                                    () => _obscureVerify = !_obscureVerify),
                                child: Icon(
                                  _obscureVerify
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AC.iconTint,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            AriaButton(label: 'Create Account', onTap: () {}),

                            const SizedBox(height: 20),

                            Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                      color: AC.iconTint,
                                      fontSize: 11,
                                      height: 1.6),
                                  children: [
                                    TextSpan(
                                        text:
                                            'By creating an account, you agree to our '),
                                    TextSpan(
                                        text: 'Terms of\nIntelligence',
                                        style: TextStyle(color: AC.purple)),
                                    TextSpan(text: ' and '),
                                    TextSpan(
                                        text: 'Privacy Protocol',
                                        style: TextStyle(color: AC.purple)),
                                    TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already a member? ', style: AText.muted),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Sign In', style: AText.link),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            color: AC.purple, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}