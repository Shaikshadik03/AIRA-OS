import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/core/widgets/aira_text_field.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);

    final notifier = ref.read(authProvider.notifier);
    bool success;

    if (_isSignUp) {
      success = await notifier.signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await notifier.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      if (_isSignUp) {
        context.go('/profile-setup');
      } else {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).signInWithGoogle();
    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AiraColors.cyanPurpleGradient.createShader(bounds),
                  child: Text(
                    'AIRA',
                    style: AiraTypography.h1.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your Personal AI OS',
                  style: AiraTypography.caption.copyWith(
                    letterSpacing: 2,
                    color: AiraColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Title
              Text(
                _isSignUp ? 'Create Account' : 'Welcome Back',
                style: AiraTypography.h3,
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? 'Start your AI-powered journey'
                    : 'Sign in to continue your journey',
                style: AiraTypography.bodyMedium.copyWith(
                  color: AiraColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              // Email field
              AiraTextField(
                controller: _emailController,
                hintText: 'Email address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              // Password field
              AiraTextField(
                controller: _passwordController,
                hintText: 'Password',
                prefixIcon: Icons.lock_outlined,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AiraColors.textMuted,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                AiraTextField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm password',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 24),
              // Submit button
              AiraButton(
                label: _isSignUp ? 'Create Account' : 'Sign In',
                onPressed: _handleSubmit,
                isLoading: _isLoading,
                isFullWidth: true,
                icon: _isSignUp
                    ? Icons.person_add_rounded
                    : Icons.login_rounded,
              ),
              const SizedBox(height: 24),
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AiraColors.glassBorder)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: AiraTypography.caption,
                    ),
                  ),
                  Expanded(child: Divider(color: AiraColors.glassBorder)),
                ],
              ),
              const SizedBox(height: 24),
              // Google sign in
              AiraButton(
                label: 'Continue with Google',
                onPressed: _handleGoogleSignIn,
                isLoading: _isLoading,
                isFullWidth: true,
                isPrimary: false,
                icon: Icons.g_mobiledata_rounded,
              ),
              const SizedBox(height: 24),
              // Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'Already have an account?'
                        : "Don't have an account?",
                    style: AiraTypography.bodySmall.copyWith(
                      color: AiraColors.textMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Sign In' : 'Sign Up',
                      style: AiraTypography.bodySmall.copyWith(
                        color: AiraColors.electricCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
