// lib/screens/login_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Final login screen.
// • _signIn() navigates to MainShell after success animation ✓
// • _googleSignIn() navigates to MainShell ✓
// • Works correctly when returned to after sign-out from Profile ✓
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'main_shell.dart';
import '../services/storage_service.dart';

class ARIALoginScreen extends StatefulWidget {
  const ARIALoginScreen({super.key});

  @override
  State<ARIALoginScreen> createState() => _ARIALoginScreenState();
}

class _ARIALoginScreenState extends State<ARIALoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _showSuccess = false;

  String? _emailError;
  String? _passwordError;

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    bool valid = true;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      valid = false;
    } else if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      valid = false;
    }

    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      valid = false;
    }

    return valid;
  }

  Future<void> _signIn() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _showSuccess = true;
    });
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _goToDashboard('User');
  }

  void _goToDashboard(String name) {
    // Step 6 — restore saved name if available
    final savedName = StorageService.instance.loadUserName();
    final effectiveName = savedName.isNotEmpty ? savedName : name;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainShell(userName: effectiveName)),
      (route) => false,
    );
  }

  String get _displayName {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return 'User';
    final local = email.split('@').first;
    if (local.isEmpty) return 'User';
    return local[0].toUpperCase() + local.substring(1);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientGlow()),
          SafeArea(
            child: ScreenEntrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  const AriaLogo(size: 80),
                  const SizedBox(height: 20),
                  Text('Welcome Back', style: AText.headline),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue to ARIA AI',
                    style: AText.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AC.card,
                          border: Border.all(color: AC.cardBorder),
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('EMAIL ADDRESS'),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: 'name@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              controller: _emailCtrl,
                              errorText: _emailError,
                              onChanged: (_) =>
                                  setState(() => _emailError = null),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const FieldLabel('PASSWORD'),
                                GestureDetector(
                                  onTap: () {},
                                  child: Text(
                                    'Forgot password?',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: AC.purple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscure,
                              controller: _passwordCtrl,
                              errorText: _passwordError,
                              onChanged: (_) =>
                                  setState(() => _passwordError = null),
                              suffix: GestureDetector(
                                onTap: () =>
                                    setState(() => _obscure = !_obscure),
                                child: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AC.iconTint,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: _rememberMe
                                          ? AC.purple
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _rememberMe
                                            ? AC.purple
                                            : AC.iconTint,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _rememberMe
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 13,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Remember me',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: AC.hint,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            AriaButton(
                              label: 'Sign In',
                              isLoading: _isLoading,
                              onTap: _signIn,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(color: AC.divider),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: AC.hint,
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(color: AC.divider),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GoogleSignInButton(
                              isLoading: _isGoogleLoading,
                              onTap: _googleSignIn,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ", style: AText.muted),
                            GestureDetector(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/signup'),
                              child: Text('Create account', style: AText.link),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.spaceGrotesk(
                              color: AC.footerA,
                              fontSize: 11,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Secure, encrypted authentication by ',
                              ),
                              TextSpan(
                                text: 'ARIA Vault',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Success overlay ─────────────────────────────────────────────
          if (_showSuccess)
            Container(
              color: const Color(0xCC0D0B1A),
              alignment: Alignment.center,
              child: SuccessAnimation(
                onComplete: () => _goToDashboard(_displayName),
              ),
            ),
        ],
      ),
    );
  }
}
