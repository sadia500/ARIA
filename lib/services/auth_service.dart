import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // add this import

class AuthService {
  static final instance = AuthService._();
  AuthService._();

  final _auth = FirebaseAuth.instance;
  final _googleSignIn = kIsWeb
      ? GoogleSignIn(
          clientId:
              '840925347583-n68nvoh5o3umvp7cbejaf3pcbmfdrff6.apps.googleusercontent.com',
        )
      : GoogleSignIn(); // mobile uses google-services.json automatically

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
      print('Google Sign In Error: $e'); // ← this prints the real error
      return 'Google sign in failed. Please try again.';
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Human readable errors ────────────────────────────────────────────────
  String _errorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'user-not-found':
        return 'No account found with this email';
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
