import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aira_app/features/auth/domain/user_model.dart';
import 'package:aira_app/core/services/api_service.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthNotifier extends StateNotifier<AuthStatus> {
  AuthNotifier() : super(AuthStatus.initial) {
    _initAuthListener();
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
  String? errorMessage;

  void _initAuthListener() {
    final client = _supabase;
    if (client == null) {
      state = AuthStatus.unauthenticated;
      return;
    }
    client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        ApiService().setAuthToken(data.session!.accessToken);
        state = AuthStatus.authenticated;
      } else {
        ApiService().clearAuthToken();
        state = AuthStatus.unauthenticated;
      }
    });
  }

  static const String _kLocalAuthKey = 'aira_auth_logged_in';
  static const String _kLocalEmailKey = 'aira_auth_user_email';
  static const String _kLocalNameKey = 'aira_auth_user_name';

  /// Check if user is already logged in (session persists across restarts).
  Future<void> checkAuthStatus() async {
    state = AuthStatus.loading;
    final client = _supabase;
    if (client != null) {
      try {
        final session = client.auth.currentSession;
        if (session != null) {
          state = AuthStatus.authenticated;
          return;
        }
      } catch (_) {}
    }

    // Check offline / local auth persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLocallyLoggedIn = prefs.getBool(_kLocalAuthKey) ?? false;
      if (isLocallyLoggedIn) {
        state = AuthStatus.authenticated;
        return;
      }
    } catch (_) {}

    state = AuthStatus.unauthenticated;
  }

  /// Sign in with email and password via Supabase (or local offline persistence).
  Future<bool> signIn(String email, String password) async {
    state = AuthStatus.loading;
    errorMessage = null;

    if (email.trim().isEmpty || password.trim().isEmpty) {
      errorMessage = 'Please enter email and password';
      state = AuthStatus.error;
      return false;
    }

    final client = _supabase;
    if (client == null) {
      // Offline / Local auth mode when Supabase is unconfigured
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLocalAuthKey, true);
      await prefs.setString(_kLocalEmailKey, email.trim());
      final name = email.trim().split('@').first;
      await prefs.setString(_kLocalNameKey, name.isNotEmpty ? name : 'User');
      state = AuthStatus.authenticated;
      return true;
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.session != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kLocalAuthKey, true);
        await prefs.setString(_kLocalEmailKey, email.trim());
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

  /// Sign up with email and password via Supabase (or local offline persistence).
  Future<bool> signUp(String email, String password) async {
    state = AuthStatus.loading;
    errorMessage = null;

    if (email.trim().isEmpty || password.trim().isEmpty) {
      errorMessage = 'Please fill all fields';
      state = AuthStatus.error;
      return false;
    }

    final client = _supabase;
    if (client == null) {
      // Offline / Local account creation when Supabase is unconfigured
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLocalAuthKey, true);
      await prefs.setString(_kLocalEmailKey, email.trim());
      final name = email.trim().split('@').first;
      await prefs.setString(_kLocalNameKey, name.isNotEmpty ? name : 'User');
      state = AuthStatus.authenticated;
      return true;
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kLocalAuthKey, true);
        await prefs.setString(_kLocalEmailKey, email.trim());
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
    final client = _supabase;
    if (client == null) {
      errorMessage = 'Supabase is not configured';
      state = AuthStatus.error;
      return false;
    }
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

      await client.auth.signInWithIdToken(
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

  /// Instant Guest Demo mode entry (persisted locally across app restarts).
  Future<void> signInGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLocalAuthKey, true);
      await prefs.setString(_kLocalEmailKey, 'guest@aira.local');
      await prefs.setString(_kLocalNameKey, 'AIRA Explorer');
    } catch (_) {}
    state = AuthStatus.authenticated;
    errorMessage = null;
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await _supabase?.auth.signOut();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocalAuthKey);
      await prefs.remove(_kLocalEmailKey);
      await prefs.remove(_kLocalNameKey);
    } catch (_) {}
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
    try {
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
    } catch (_) {}
    return UserModel(
      id: 'local_user',
      email: 'user@aira.local',
      displayName: 'AIRA Explorer',
      timezone: 'Asia/Kolkata',
      aiPersonality: 'mentor',
      onboardingComplete: true,
      createdAt: DateTime.now(),
    );
  }
  return null;
});
