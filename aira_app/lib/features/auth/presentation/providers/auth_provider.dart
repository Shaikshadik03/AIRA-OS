import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/features/auth/domain/user_model.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial);

  String? errorMessage;

  Future<void> checkAuthStatus() async {
    state = AuthState.loading;
    await Future.delayed(const Duration(milliseconds: 500));
    state = AuthState.unauthenticated;
  }

  Future<bool> signIn(String email, String password) async {
    state = AuthState.loading;
    errorMessage = null;
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (email.isEmpty || password.isEmpty) {
        errorMessage = 'Please enter email and password';
        state = AuthState.error;
        return false;
      }

      // Mock successful authentication
      state = AuthState.authenticated;
      return true;
    } catch (e) {
      errorMessage = 'Sign in failed: $e';
      state = AuthState.error;
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = AuthState.loading;
    errorMessage = null;
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (email.isEmpty || password.isEmpty) {
        errorMessage = 'Please fill all fields';
        state = AuthState.error;
        return false;
      }

      state = AuthState.authenticated;
      return true;
    } catch (e) {
      errorMessage = 'Sign up failed: $e';
      state = AuthState.error;
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = AuthState.loading;
    errorMessage = null;
    try {
      await Future.delayed(const Duration(seconds: 1));
      state = AuthState.authenticated;
      return true;
    } catch (e) {
      errorMessage = 'Google sign in failed: $e';
      state = AuthState.error;
      return false;
    }
  }

  void signOut() {
    state = AuthState.unauthenticated;
    errorMessage = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = StateProvider<UserModel?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState == AuthState.authenticated) {
    return UserModel(
      id: 'mock-user-001',
      email: 'arshan@aira.os',
      displayName: 'Arshan',
      timezone: 'Asia/Kolkata',
      aiPersonality: 'mentor',
      onboardingComplete: true,
      createdAt: DateTime.now(),
    );
  }
  return null;
});

final isOnboardingCompleteProvider = StateProvider<bool>((ref) => false);
