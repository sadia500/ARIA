import 'package:flutter/material.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';

class ARIALoginScreen extends StatefulWidget {
  const ARIALoginScreen({super.key});

  @override
  State<ARIALoginScreen> createState() => _ARIALoginScreenState();
}

class _ARIALoginScreenState extends State<ARIALoginScreen> {
  bool _obscure = true;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: AriaLogoBadge(),
                  ),

                  const SizedBox(height: 36),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Welcome Back', style: AText.headline),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Sign in to continue to ARIA AI', style: AText.subtitle),
                  ),

                  const SizedBox(height: 32),

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
                            const FieldLabel('EMAIL ADDRESS'),
                            const SizedBox(height: 8),
                            const AriaInputField(
                              hintText: 'name@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const FieldLabel('PASSWORD'),
                                GestureDetector(
                                  onTap: () {},
                                  child: const Text('Forgot password?',
                                      style: TextStyle(
                                          color: AC.purple,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscure,
                              suffix: GestureDetector(
                                onTap: () => setState(() => _obscure = !_obscure),
                                child: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AC.iconTint,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),
                            AriaButton(label: 'Sign In', onTap: () {}),

                            const SizedBox(height: 24),

                            const Row(children: [
                              Expanded(child: Divider(color: AC.divider)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text('OR CONTINUE WITH',
                                    style: TextStyle(
                                        color: AC.hint,
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w500)),
                              ),
                              Expanded(child: Divider(color: AC.divider)),
                            ]),

                            const SizedBox(height: 20),

                            Center(
                              child: Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AC.sso,
                                  border: Border.all(color: AC.purpleBorder, width: 1.5),
                                  boxShadow: AShadow.sso,
                                ),
                                child: const Icon(Icons.shield_outlined,
                                    color: AC.purple, size: 24),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ", style: AText.muted),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/signup'),
                            child: const Text('Create account', style: AText.link),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(color: AC.footerA, fontSize: 11),
                          children: [
                            TextSpan(text: 'Secure, encrypted authentication by '),
                            TextSpan(
                              text: 'ARIA Vault',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ]),
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