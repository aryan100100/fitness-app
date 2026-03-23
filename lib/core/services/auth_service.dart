// [HEALTH APP] — Auth Service (Feature 12)
// Handles Google Sign In, Apple Sign In, and Email/Password auth via Supabase.
// AuthResult model communicates success, errors, and new-user state.

import 'dart:math';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── AuthResult ────────────────────────────────────────────────────────────────
class AuthResult {
  final bool success;
  final String? error;
  final bool isNewUser;

  const AuthResult({
    required this.success,
    this.error,
    this.isNewUser = false,
  });
}

// ── AuthService ───────────────────────────────────────────────────────────────
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Get current user ────────────────────────────────────────────────────────
  User? getCurrentUser() => _client.auth.currentUser;

  // ── Check if onboarding is complete ─────────────────────────────────────────
  // "Complete" = users table has a row for this uid with a non-null name.
  Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final res = await _client
          .from('users')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      return res != null && (res['name'] as String?)?.isNotEmpty == true;
    } catch (e) {
      debugPrint('[AUTH] hasCompletedOnboarding error: $e');
      return false;
    }
  }

  // ── Google Sign In ───────────────────────────────────────────────────────────
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult(success: false, error: 'Sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return const AuthResult(
            success: false, error: 'Could not get ID token from Google');
      }

      final AuthResponse response =
          await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        return const AuthResult(
            success: false, error: 'Google sign-in failed — please try again');
      }

      final isNew = !(await hasCompletedOnboarding(response.user!.id));
      return AuthResult(success: true, isNewUser: isNew);
    } on AuthException catch (e) {
      debugPrint('[AUTH] Google SignIn AuthException: ${e.message}');
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      debugPrint('[AUTH] Google SignIn error: $e');
      return AuthResult(success: false, error: 'Google sign-in failed — please try again');
    }
  }

  // ── Apple Sign In ────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return const AuthResult(
            success: false, error: 'Could not get identity token from Apple');
      }

      final AuthResponse response =
          await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.user == null) {
        return const AuthResult(
            success: false, error: 'Apple sign-in failed — please try again');
      }

      final isNew = !(await hasCompletedOnboarding(response.user!.id));
      return AuthResult(success: true, isNewUser: isNew);
    } on SignInWithAppleAuthorizationException catch (e) {
      // User cancelled
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult(success: false, error: 'Sign-in cancelled');
      }
      debugPrint('[AUTH] Apple SignIn error: ${e.message}');
      return AuthResult(success: false, error: 'Apple sign-in failed — please try again');
    } on AuthException catch (e) {
      debugPrint('[AUTH] Apple SignIn AuthException: ${e.message}');
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      debugPrint('[AUTH] Apple SignIn error: $e');
      return AuthResult(success: false, error: 'Apple sign-in failed — please try again');
    }
  }

  // ── Email Sign Up ────────────────────────────────────────────────────────────
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        return const AuthResult(
            success: false,
            error: 'Could not create account — please try again');
      }

      // New users always need onboarding
      return const AuthResult(success: true, isNewUser: true);
    } on AuthException catch (e) {
      debugPrint('[AUTH] signUpWithEmail error: ${e.message}');
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      debugPrint('[AUTH] signUpWithEmail unexpected error: $e');
      return const AuthResult(
          success: false, error: 'Could not create account — please try again');
    }
  }

  // ── Email Sign In ────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final AuthResponse response =
          await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        return const AuthResult(
            success: false, error: 'Sign-in failed — please try again');
      }

      final isNew = !(await hasCompletedOnboarding(response.user!.id));
      return AuthResult(success: true, isNewUser: isNew);
    } on AuthException catch (e) {
      debugPrint('[AUTH] signInWithEmail error: ${e.message}');
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      debugPrint('[AUTH] signInWithEmail unexpected error: $e');
      return const AuthResult(
          success: false, error: 'Sign-in failed — please try again');
    }
  }

  // ── Password Reset ───────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      // Sign out from Google if active
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    await _client.auth.signOut();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return 'Incorrect email or password';
    }
    if (lower.contains('email already registered') ||
        lower.contains('already')) {
      return 'An account with this email already exists';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please check your email and confirm your account first';
    }
    if (lower.contains('too many requests') || lower.contains('rate')) {
      return 'Too many attempts — please wait a moment and try again';
    }
    if (lower.contains('password')) {
      return 'Password must be at least 8 characters';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'No internet connection — please check your network';
    }
    return 'Something went wrong — please try again';
  }
}
