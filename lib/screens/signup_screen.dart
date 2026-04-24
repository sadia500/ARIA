// lib/screens/signup_screen.dart
// ignore_for_file: unused_field, unused_import, deprecated_member_use

import 'dart:math';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'main_shell.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'set_password_screen.dart';

// ── Password utility ─────────────────────────────────────────────────────────
class PasswordUtils {
  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _digits = '0123456789';
  static const _special = r'!@#$%^&*()_+-=[]{}|;:,.<>?';

  static String generate({int length = 14}) {
    final rng = Random.secure();
    final all = _upper + _lower + _digits + _special;
    final required = [
      _upper[rng.nextInt(_upper.length)],
      _lower[rng.nextInt(_lower.length)],
      _digits[rng.nextInt(_digits.length)],
      _special[rng.nextInt(_special.length)],
    ];
    final rest = List.generate(
      length - required.length,
      (_) => all[rng.nextInt(all.length)],
    );
    final combined = [...required, ...rest]..shuffle(rng);
    return combined.join();
  }

  // 0 = empty, 1 = weak, 2 = medium, 3 = strong
  static int strength(String p) {
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?]'))) score++;
    if (score <= 1) return 1;
    if (score == 2) return 2;
    return 3;
  }
}

class ARIASignUpScreen extends StatefulWidget {
  const ARIASignUpScreen({super.key});

  @override
  State<ARIASignUpScreen> createState() => _ARIASignUpScreenState();
}

class _ARIASignUpScreenState extends State<ARIASignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _verifyCtrl = TextEditingController();

  bool _obscureCreate = true;
  bool _obscureVerify = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _showSuccess = false;
  bool _isGoogleUser = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _verifyError;
  String _password = '';

  // ── #1: Generate strong password ─────────────────────────────────────────
  void _generatePassword() {
    final generated = PasswordUtils.generate();
    _passwordCtrl.text = generated;
    _verifyCtrl.text = generated;
    setState(() {
      _password = generated;
      _obscureCreate = false;
      _passwordError = null;
      _verifyError = null;
    });
    Clipboard.setData(ClipboardData(text: generated));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text('Strong password generated & copied to clipboard!'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Validate with #3: strength enforcement ───────────────────────────────
  bool _validate() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _verifyError = null;
    });
    bool valid = true;

    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name is required');
      valid = false;
    } else if (_nameCtrl.text.trim().length < 2) {
      setState(() => _nameError = 'Enter your full name');
      valid = false;
    }

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      valid = false;
    } else if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      valid = false;
    }

    if (_passwordCtrl.text.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    } else if (_passwordCtrl.text.length < 8) {
      setState(() => _passwordError = 'Minimum 8 characters required');
      valid = false;
    } else if (PasswordUtils.strength(_passwordCtrl.text) < 2) {
      setState(
        () => _passwordError =
            'Password too weak — add uppercase, numbers or symbols.',
      );
      valid = false;
    }

    if (_verifyCtrl.text.isEmpty) {
      setState(() => _verifyError = 'Please confirm your password');
      valid = false;
    } else if (_verifyCtrl.text != _passwordCtrl.text) {
      setState(() => _verifyError = 'Passwords do not match');
      valid = false;
    }

    return valid;
  }

  Future<void> _signUp() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    final error = await AuthService.instance.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      name: _nameCtrl.text.trim(),
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _isLoading = false);
      if (error.toLowerCase().contains('please sign in instead')) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AC.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Account Already Exists',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'An account with this email already exists. Would you like to sign in instead?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white38)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _goToLogin();
                },
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    color: AC.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        setState(() => _emailError = error);
      }
    } else {
      setState(() {
        _isLoading = false;
        _isGoogleUser = false;
        _showSuccess = true;
      });
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    await AuthService.instance.signOutGoogle();
    final error = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final user = AuthService.instance.currentUser;
    final providerIds =
        user?.providerData.map((p) => p.providerId).toList() ?? [];

    if (providerIds.contains('password')) {
      await AuthService.instance.signOut();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AC.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Account Already Exists',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This Google account is already registered. Would you like to sign in instead?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _goToLogin();
              },
              child: Text(
                'Sign In',
                style: TextStyle(color: AC.purple, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SetPasswordScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToDashboard() async {
    if (!mounted) return;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    StorageService.instance.saveUserName(name);
    StorageService.instance.saveUserEmail(email);
    await FirestoreService.instance.saveProfile(name: name, email: email);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ARIALoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _verifyCtrl.dispose();
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
                children: [
                  const SizedBox(height: 20),
                  const AriaLogo(size: 64),
                  const SizedBox(height: 12),
                  Text('Create Account', style: AText.title),
                  const SizedBox(height: 4),
                  Text(
                    'Start your AI-powered productivity journey',
                    textAlign: TextAlign.center,
                    style: AText.subtitle,
                  ),
                  const SizedBox(height: 20),

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
                            // ── Name ──
                            const FieldLabel('FULL NAME', purple: true),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: 'John Doe',
                              prefixIcon: Icons.person_outline,
                              borderColor: AC.purpleRing2,
                              controller: _nameCtrl,
                              errorText: _nameError,
                              onChanged: (_) =>
                                  setState(() => _nameError = null),
                            ),

                            const SizedBox(height: 16),

                            // ── Email ──
                            const FieldLabel('EMAIL ADDRESS', purple: true),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: 'aria@intelligence.ai',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              controller: _emailCtrl,
                              errorText: _emailError,
                              onChanged: (_) =>
                                  setState(() => _emailError = null),
                            ),

                            const SizedBox(height: 16),

                            // ── Password label + Generate button ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const FieldLabel(
                                  'CREATE PASSWORD',
                                  purple: true,
                                ),
                                GestureDetector(
                                  onTap: _generatePassword,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AC.purple.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AC.purple.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          color: AC.purple,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Generate',
                                          style: TextStyle(
                                            color: AC.purple,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscureCreate,
                              controller: _passwordCtrl,
                              errorText: _passwordError,
                              onChanged: (v) => setState(() {
                                _password = v;
                                _passwordError = null;
                              }),
                              suffix: GestureDetector(
                                onTap: () => setState(
                                  () => _obscureCreate = !_obscureCreate,
                                ),
                                child: Icon(
                                  _obscureCreate
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AC.iconTint,
                                  size: 20,
                                ),
                              ),
                            ),

                            // ── Strength bar ──
                            PasswordStrengthBar(password: _password),

                            // ── #2: Requirements checklist ──
                            if (_password.isNotEmpty)
                              _PasswordChecklist(password: _password),

                            const SizedBox(height: 16),

                            // ── Confirm password ──
                            const FieldLabel('VERIFY PASSWORD', purple: true),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: '••••••••',
                              prefixIcon: Icons.shield_outlined,
                              obscureText: _obscureVerify,
                              controller: _verifyCtrl,
                              errorText: _verifyError,
                              onChanged: (_) =>
                                  setState(() => _verifyError = null),
                              suffix: GestureDetector(
                                onTap: () => setState(
                                  () => _obscureVerify = !_obscureVerify,
                                ),
                                child: Icon(
                                  _obscureVerify
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AC.iconTint,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            AriaButton(
                              label: 'Create Account',
                              isLoading: _isLoading,
                              onTap: _signUp,
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

                            const SizedBox(height: 18),

                            Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AC.iconTint,
                                    fontSize: 11,
                                    height: 1.6,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text:
                                          'By creating an account, you agree to our ',
                                    ),
                                    TextSpan(
                                      text: 'Terms of Intelligence',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: AC.purple,
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Protocol',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: AC.purple,
                                      ),
                                    ),
                                    const TextSpan(text: '.'),
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
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already a member? ', style: AText.muted),
                        GestureDetector(
                          onTap: _goToLogin,
                          child: Text('Sign In', style: AText.link),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          color: AC.purple,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showSuccess)
            Container(
              color: const Color(0xCC0D0B1A),
              alignment: Alignment.center,
              child: SuccessAnimation(onComplete: _navigateToDashboard),
            ),
        ],
      ),
    );
  }
}

// ── #2: Password requirements checklist ─────────────────────────────────────
class _PasswordChecklist extends StatelessWidget {
  final String password;
  const _PasswordChecklist({required this.password});

  @override
  Widget build(BuildContext context) {
    final checks = [
      (label: '8+ characters', met: password.length >= 8),
      (
        label: 'Uppercase letter (A-Z)',
        met: password.contains(RegExp(r'[A-Z]')),
      ),
      (label: 'Number (0-9)', met: password.contains(RegExp(r'[0-9]'))),
      (
        label: 'Special character (!@#\$...)',
        met: password.contains(RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?]')),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: checks.map((c) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.met ? const Color(0xFF2E7D32) : Colors.transparent,
                    border: Border.all(
                      color: c.met ? const Color(0xFF2E7D32) : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: c.met
                      ? const Icon(Icons.check, color: Colors.white, size: 10)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  c.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.met ? Colors.white60 : Colors.white30,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
