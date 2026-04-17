// lib/screens/login_screen.dart
// ignore_for_file: unused_field, prefer_final_fields, unused_import

import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'main_shell.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = false);

    // Save email user data to local storage
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

    // Force account picker to show every time
    await AuthService.instance.signOutGoogle();

    final error = await AuthService.instance.signInWithGoogle();

    if (!mounted) return;

    setState(() => _isGoogleLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ── Save Google user data to local storage + Firestore ──
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
                              controller: _emailCtrl,
                              errorText: _emailError,
                              onChanged: (_) =>
                                  setState(() => _emailError = null),
                            ),
                            const SizedBox(height: 18),

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

                            const SizedBox(height: 24),

                            AriaButton(
                              label: 'Sign In',
                              isLoading: _isLoading,
                              onTap: _signIn,
                            ),

                            const SizedBox(height: 16),

                            GoogleSignInButton(
                              isLoading: _isGoogleLoading,
                              onTap: _googleSignIn,
                            ),
                          ],
                        ),
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
