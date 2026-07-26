import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aira_app/features/auth/domain/user_model.dart';
import 'package:aira_app/core/services/api_service.dart';

import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthNotifier extends StateNotifier<AuthStatus> {
  AuthNotifier() : super(AuthStatus.initial) {
    _initAuthListener();
  }

  final _supabase = Supabase.instance.client;
  String? errorMessage;

  void _initAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        ApiService().setAuthToken(data.session!.accessToken);
        state = AuthStatus.authenticated;
      } else {
        ApiService().clearAuthToken();
        state = AuthStatus.unauthenticated;
      }
    });
  }

  /// Check if user is already logged in (session persists).
  Future<void> checkAuthStatus() async {
    state = AuthStatus.loading;
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        state = AuthStatus.authenticated;
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_supabase.auth.currentSession == null) {
          state = AuthStatus.unauthenticated;
        } else {
          state = AuthStatus.authenticated;
        }
      }
    } catch (e) {
      state = AuthStatus.unauthenticated;
    }
  }

  /// Sign in with email and password via Supabase.
  Future<bool> signIn(String email, String password) async {
    state = AuthStatus.loading;
    errorMessage = null;
    try {
      if (email.trim().isEmpty || password.trim().isEmpty) {
        errorMessage = 'Please enter email and password';
        state = AuthStatus.error;
        return false;
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.session != null) {
        state = AuthStatus.authenticated;
        return true;
      } else {
        errorMessage = 'Invalid credentials';
        state = AuthStatus.error;
        return false;
      }
    } on AuthException catch (e) {
      errorMessage = e.message;
      state = AuthStatus.error;
      return false;
    } catch (e) {
      errorMessage = 'Sign in failed: $e';
      state = AuthStatus.error;
      return false;
    }
  }

  /// Sign up with email and password via Supabase.
  Future<bool> signUp(String email, String password) async {
    state = AuthStatus.loading;
    errorMessage = null;
    try {
      if (email.trim().isEmpty || password.trim().isEmpty) {
        errorMessage = 'Please fill all fields';
        state = AuthStatus.error;
        return false;
      }

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.user != null) {
        state = AuthStatus.authenticated;
        return true;
      } else {
        errorMessage = 'Sign up failed';
        state = AuthStatus.error;
        return false;
      }
    } on AuthException catch (e) {
      errorMessage = e.message;
      state = AuthStatus.error;
      return false;
    } catch (e) {
      errorMessage = 'Sign up failed: $e';
      state = AuthStatus.error;
      return false;
    }
  }

  /// Google Sign-In via Supabase OAuth.
  Future<bool> signInWithGoogle() async {
    state = AuthStatus.loading;
    errorMessage = null;
    try {
      const webClientId = '952571077863-8ucblk4et686f7t1hqeuj90mot2othgp.apps.googleusercontent.com';
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      // Force native Google account selection picker prompt
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = AuthStatus.unauthenticated;
        return false; // User canceled
      }
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Missing Google Auth Tokens';
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      state = AuthStatus.authenticated;
      return true;
    } catch (e) {
      errorMessage = 'Google sign in failed: $e';
      state = AuthStatus.error;
      return false;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
    state = AuthStatus.unauthenticated;
    errorMessage = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthStatus>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState == AuthStatus.authenticated) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] ??
            user.userMetadata?['name'] ??
            user.userMetadata?['full_name'] ??
            user.email?.split('@').first ??
            'User',
        timezone: 'Asia/Kolkata',
        aiPersonality: 'mentor',
        onboardingComplete: true,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );
    }
  }
  return null;
});
