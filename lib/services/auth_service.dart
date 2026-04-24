// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final instance = AuthService._();
  AuthService._();

  final _auth = FirebaseAuth.instance;
  final _googleSignIn = kIsWeb
      ? GoogleSignIn(
          clientId:
              '840925347583-n68nvoh5o3umvp7cbejaf3pcbmfdrff6.apps.googleusercontent.com',
        )
      : GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String get userName => _auth.currentUser?.displayName ?? 'User';
  String get userEmail => _auth.currentUser?.email ?? '';
  String get userId => _auth.currentUser?.uid ?? '';

  // ── Email Sign Up ────────────────────────────────────────────────────────
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user?.updateDisplayName(name);
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Email Sign In ────────────────────────────────────────────────────────
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Google Sign In ───────────────────────────────────────────────────────
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google sign in was cancelled';
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} — ${e.message}');
      return _errorMessage(e.code);
    } catch (e) {
      print('Google Sign In Error: $e');
      return 'Google sign in failed. Please try again.';
    }
  }

  // ── Sign out Google only — forces account picker next time ───────────────
  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }

  // ── Link Email+Password to existing Google account ───────────────────────
  Future<String?> linkEmailPassword({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user signed in.';

      final email = user.email;
      if (email == null) return 'Could not retrieve email from Google account.';

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.linkWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        return 'A password is already set for this account.';
      } else if (e.code == 'weak-password') {
        return 'Password must be at least 6 characters.';
      }
      return _errorMessage(e.code);
    } catch (e) {
      return 'Failed to set password. Please try again.';
    }
  }

  // ── Password Reset ───────────────────────────────────────────────────────
  Future<String?> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Failed to send reset email. Please try again.';
    }
  }

  // ── Full Sign Out ────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Human readable errors ────────────────────────────────────────────────
  String _errorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'user-not-found':
        return 'No account found with this email. Please create an account first.';
      case 'wrong-password':
        return 'Incorrect password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'No internet connection. Please check your network';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email';
      default:
        return 'Something went wrong. Please try again';
    }
  }
}
