// lib/screens/set_password_screen.dart
// ignore_for_file: unused_import

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import 'signup_screen.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isSkipping = false;

  String? _passwordError;
  String? _confirmError;
  String _password = '';

  // ── #1: Generate strong password ─────────────────────────────────────────
  void _generatePassword() {
    final generated = PasswordUtils.generate();
    _passwordCtrl.text = generated;
    _confirmCtrl.text = generated;
    setState(() {
      _password = generated;
      _obscurePassword = false;
      _passwordError = null;
      _confirmError = null;
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

  // ── #3: Validate with strength enforcement ───────────────────────────────
  bool _validate() {
    setState(() {
      _passwordError = null;
      _confirmError = null;
    });

    bool valid = true;

    if (_passwordCtrl.text.isEmpty) {
      _passwordError = 'Password is required';
      valid = false;
    } else if (_passwordCtrl.text.length < 8) {
      _passwordError = 'Minimum 8 characters required';
      valid = false;
    } else if (PasswordUtils.strength(_passwordCtrl.text) < 2) {
      _passwordError = 'Password too weak — add uppercase, numbers or symbols.';
      valid = false;
    }

    if (_confirmCtrl.text.isEmpty) {
      _confirmError = 'Please confirm your password';
      valid = false;
    } else if (_confirmCtrl.text != _passwordCtrl.text) {
      _confirmError = 'Passwords do not match';
      valid = false;
    }

    setState(() {});
    return valid;
  }

  Future<void> _setPassword() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    final error = await AuthService.instance.linkEmailPassword(
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

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

    _goNext();
  }

  Future<void> _skip() async {
    setState(() => _isSkipping = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _goNext();
  }

  void _goNext() {
    final name = AuthService.instance.userName;
    final email = AuthService.instance.userEmail;
    StorageService.instance.saveUserName(name);
    StorageService.instance.saveUserEmail(email);
    FirestoreService.instance.saveProfile(name: name, email: email);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = AuthService.instance.userName;
    final userEmail = AuthService.instance.userEmail;

    return Scaffold(
      backgroundColor: AC.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientGlow()),
          SafeArea(
            child: ScreenEntrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const AriaLogo(size: 64),
                  const SizedBox(height: 16),
                  Text('One Last Step', style: AText.headline),
                  const SizedBox(height: 6),
                  Text(
                    'Set a password so you can also\nsign in with email anytime',
                    style: AText.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // ── Google account badge ──
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AC.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AC.purple.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        color: Color(0xFF4285F4),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        userEmail,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.verified,
                                  color: AC.purple,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Main card ──
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AC.card,
                              border: Border.all(color: AC.cardBorder),
                            ),
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Password label + Generate button ──
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const FieldLabel('CREATE PASSWORD'),
                                    GestureDetector(
                                      onTap: _generatePassword,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AC.purple.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AC.purple.withValues(
                                              alpha: 0.4,
                                            ),
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
                                  obscureText: _obscurePassword,
                                  controller: _passwordCtrl,
                                  errorText: _passwordError,
                                  onChanged: (v) => setState(() {
                                    _password = v;
                                    _passwordError = null;
                                  }),
                                  suffix: GestureDetector(
                                    onTap: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    child: Icon(
                                      _obscurePassword
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

                                const FieldLabel('CONFIRM PASSWORD'),
                                const SizedBox(height: 8),
                                AriaInputField(
                                  hintText: '••••••••',
                                  prefixIcon: Icons.shield_outlined,
                                  obscureText: _obscureConfirm,
                                  controller: _confirmCtrl,
                                  errorText: _confirmError,
                                  onChanged: (_) =>
                                      setState(() => _confirmError = null),
                                  suffix: GestureDetector(
                                    onTap: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                    child: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AC.iconTint,
                                      size: 20,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                AriaButton(
                                  label: 'Set Password & Continue',
                                  isLoading: _isLoading,
                                  onTap: _setPassword,
                                ),

                                const SizedBox(height: 12),

                                Center(
                                  child: TextButton(
                                    onPressed: _isSkipping ? null : _skip,
                                    child: _isSkipping
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white38,
                                            ),
                                          )
                                        : const Text(
                                            'Skip for now, use Google only',
                                            style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Info note ──
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.white38,
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Setting a password lets you sign in with either Google or your email + password. You can always change it later in settings.',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
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
