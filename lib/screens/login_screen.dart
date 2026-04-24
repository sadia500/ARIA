// lib/screens/login_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unnecessary_underscores, unused_field, prefer_final_fields, unused_import
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'main_shell.dart';
import 'signup_screen.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class ARIALoginScreen extends StatefulWidget {
  const ARIALoginScreen({super.key});

  @override
  State<ARIALoginScreen> createState() => _ARIALoginScreenState();
}

class _ARIALoginScreenState extends State<ARIALoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _resetEmailCtrl = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  String? _emailError;
  String? _passwordError;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool valid = true;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _emailError = 'Email is required';
      valid = false;
    } else if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(email)) {
      _emailError = 'Enter a valid email address';
      valid = false;
    }

    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      _passwordError = 'Password is required';
      valid = false;
    } else if (password.length < 6) {
      _passwordError = 'Password must be at least 6 characters';
      valid = false;
    }

    setState(() {});

    if (!valid) {
      _shakeController.forward(from: 0);
    }

    return valid;
  }

  Future<void> _signIn() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    final error = await AuthService.instance.signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _isLoading = false);

      // Friendly error messages
      String friendlyError = error;
      if (error.toLowerCase().contains('too-many-requests')) {
        friendlyError = 'Too many attempts. Please try again later.';
      } else if (error.toLowerCase().contains('wrong-password') ||
          error.toLowerCase().contains('invalid-credential')) {
        try {
          final methods = await FirebaseAuth.instance
              .fetchSignInMethodsForEmail(_emailCtrl.text.trim());
          if (methods.contains('google.com') && !methods.contains('password')) {
            friendlyError =
                'This account was registered with Google. Please use "Continue with Google" to sign in, or tap "Forgot Password" to set a password.';
          } else {
            friendlyError =
                'Incorrect password. Try again or reset your password.';
          }
        } catch (_) {
          friendlyError =
              'Incorrect password. Try again or reset your password.';
        }
      } else if (error.toLowerCase().contains('no account found')) {
        friendlyError =
            'No account found with this email. Please create an account first.';
      }

      _showErrorSnack(friendlyError);
      _shakeController.forward(from: 0);
      return;
    }

    setState(() => _isLoading = false);

    final name = _displayName;
    final email = _emailCtrl.text.trim();
    StorageService.instance.saveUserName(name);
    StorageService.instance.saveUserEmail(email);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainShell(userName: name)),
      (route) => false,
    );
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);

    await AuthService.instance.signOutGoogle();

    final error = await AuthService.instance.signInWithGoogle();

    if (!mounted) return;

    setState(() => _isGoogleLoading = false);

    if (error != null) {
      _showErrorSnack(error);
      return;
    }

    final name = AuthService.instance.userName;
    final email = AuthService.instance.userEmail;

    StorageService.instance.saveUserName(name);
    StorageService.instance.saveUserEmail(email);
    await FirestoreService.instance.saveProfile(name: name, email: email);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainShell(userName: name)),
      (route) => false,
    );
  }

  Future<void> _forgotPassword() async {
    _resetEmailCtrl.text = _emailCtrl.text.trim();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(
        emailCtrl: _resetEmailCtrl,
        onSend: (email) async {
          final error = await AuthService.instance.sendPasswordReset(
            email: email,
          );
          if (!mounted) return;
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    error != null ? Icons.error_outline : Icons.check_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error ??
                          'Reset link sent! Check your inbox or spam folder.',
                    ),
                  ),
                ],
              ),
              backgroundColor: error != null
                  ? Colors.redAccent
                  : const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    );
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const ARIASignUpScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String get _displayName {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return 'User';
    final local = email.split('@').first;
    return local.isEmpty ? 'User' : local[0].toUpperCase() + local.substring(1);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _resetEmailCtrl.dispose();
    _shakeController.dispose();
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

                  // ── Main card ──
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          final offset = _shakeController.isAnimating
                              ? 6 * (0.5 - (_shakeAnimation.value - 0.5).abs())
                              : 0.0;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
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
                              // ── Email ──
                              const FieldLabel('EMAIL ADDRESS'),
                              const SizedBox(height: 8),
                              AriaInputField(
                                hintText: 'name@example.com',
                                prefixIcon: Icons.email_outlined,
                                controller: _emailCtrl,
                                errorText: _emailError,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (_) =>
                                    setState(() => _emailError = null),
                              ),
                              const SizedBox(height: 18),

                              // ── Password ──
                              const FieldLabel('PASSWORD'),
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
                                  ),
                                ),
                              ),

                              // ── Forgot Password ──
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 0,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: AC.purple,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ── Sign In Button ──
                              AriaButton(
                                label: 'Sign In',
                                isLoading: _isLoading,
                                onTap: _signIn,
                              ),

                              const SizedBox(height: 16),

                              // ── Divider ──
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AC.cardBorder,
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AC.cardBorder,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // ── Google Sign In ──
                              GoogleSignInButton(
                                isLoading: _isGoogleLoading,
                                onTap: _googleSignIn,
                              ),

                              const SizedBox(height: 24),

                              // ── Sign Up Link ──
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _goToSignUp,
                                      child: Text(
                                        'Create Account',
                                        style: TextStyle(
                                          color: AC.purple,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AC.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Terms footer ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    child: Text(
                      'By signing in, you agree to our Terms of Service\nand Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        height: 1.6,
                      ),
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

// ─────────────────────────────────────────────
// Forgot Password Bottom Sheet
// ─────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  final TextEditingController emailCtrl;
  final Future<void> Function(String email) onSend;

  const _ForgotPasswordSheet({required this.emailCtrl, required this.onSend});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  bool _isSending = false;
  String? _emailError;

  Future<void> _send() async {
    final email = widget.emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address');
      return;
    }
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }

    setState(() {
      _isSending = true;
      _emailError = null;
    });

    await widget.onSend(email);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AC.cardBorder),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AC.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: AC.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "We'll send a reset link to your email",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            const FieldLabel('EMAIL ADDRESS'),
            const SizedBox(height: 8),
            AriaInputField(
              hintText: 'name@example.com',
              prefixIcon: Icons.email_outlined,
              controller: widget.emailCtrl,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() => _emailError = null),
            ),

            const SizedBox(height: 20),

            AriaButton(
              label: 'Send Reset Link',
              isLoading: _isSending,
              onTap: _send,
            ),

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
