import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for splash animation
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // Check if user has an existing session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // User is already logged in — go straight to chat
      context.go('/chat');
    } else {
      // No session — show login
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing backdrop
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AiraColors.electricCyan.withValues(alpha: 0.15),
                    AiraColors.purple.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AiraColors.cyanPurpleGradient.createShader(bounds),
                  child: Text(
                    'AIRA',
                    style: AiraTypography.h1.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 600.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 12),
            Text(
              'Your Personal AI Assistant',
              style: AiraTypography.bodyMedium.copyWith(
                color: AiraColors.textSecondary,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
