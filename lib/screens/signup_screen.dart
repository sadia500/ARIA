import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';

class ARIASignUpScreen extends StatefulWidget {
  const ARIASignUpScreen({super.key});

  @override
  State<ARIASignUpScreen> createState() => _ARIASignUpScreenState();
}

class _ARIASignUpScreenState extends State<ARIASignUpScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _verifyCtrl   = TextEditingController();

  bool _obscureCreate   = true;
  bool _obscureVerify   = true;
  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  bool _showSuccess     = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _verifyError;
  String _password = '';

  bool _validate() {
    setState(() {
      _nameError = null; _emailError = null;
      _passwordError = null; _verifyError = null;
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

    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Minimum 6 characters');
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
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() { _isLoading = false; _showSuccess = true; });
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
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
                  const SizedBox(height: 16),

                  Text('Create Account', style: AText.title),
                  const SizedBox(height: 6),
                  Text(
                    'Start your AI-powered productivity journey',
                    textAlign: TextAlign.center,
                    style: AText.subtitle,
                  ),

                  const SizedBox(height: 22),

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
                            AriaInputField(
                              hintText: 'John Doe',
                              prefixIcon: Icons.person_outline,
                              borderColor: AC.purpleRing2,
                              controller: _nameCtrl,
                              errorText: _nameError,
                              onChanged: (_) => setState(() => _nameError = null),
                            ),

                            const SizedBox(height: 16),

                            const FieldLabel('EMAIL ADDRESS', purple: true),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: 'aria@intelligence.ai',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              controller: _emailCtrl,
                              errorText: _emailError,
                              onChanged: (_) => setState(() => _emailError = null),
                            ),

                            const SizedBox(height: 16),

                            const FieldLabel('CREATE PASSWORD', purple: true),
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

                            PasswordStrengthBar(password: _password),

                            const SizedBox(height: 16),

                            const FieldLabel('VERIFY PASSWORD', purple: true),
                            const SizedBox(height: 8),
                            AriaInputField(
                              hintText: '••••••••',
                              prefixIcon: Icons.shield_outlined,
                              obscureText: _obscureVerify,
                              controller: _verifyCtrl,
                              errorText: _verifyError,
                              onChanged: (_) => setState(() => _verifyError = null),
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

                            const SizedBox(height: 24),

                            AriaButton(
                              label: 'Create Account',
                              isLoading: _isLoading,
                              onTap: _signUp,
                            ),

                            const SizedBox(height: 16),

                            Row(children: [
                              const Expanded(child: Divider(color: AC.divider)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text('OR',
                                    style: GoogleFonts.spaceGrotesk(
                                        color: AC.hint,
                                        fontSize: 11,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w500)),
                              ),
                              const Expanded(child: Divider(color: AC.divider)),
                            ]),

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
                                      height: 1.6),
                                  children: [
                                    const TextSpan(
                                        text: 'By creating an account, you agree to our '),
                                    TextSpan(
                                        text: 'Terms of Intelligence',
                                        style: GoogleFonts.spaceGrotesk(
                                            color: AC.purple)),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                        text: 'Privacy Protocol',
                                        style: GoogleFonts.spaceGrotesk(
                                            color: AC.purple)),
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
                          onTap: () => Navigator.pushReplacementNamed(
                              context, '/login'),
                          child: Text('Sign In', style: AText.link),
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

          if (_showSuccess)
            Container(
              color: const Color(0xCC0D0B1A),
              alignment: Alignment.center,
              child: SuccessAnimation(
                onComplete: () {
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}