import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:aira_app/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:aira_app/features/auth/presentation/screens/login_screen.dart';
import 'package:aira_app/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:aira_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:aira_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:aira_app/features/planner/presentation/screens/planner_screen.dart';
import 'package:aira_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:aira_app/features/voice/presentation/screens/voice_assistant_panel.dart';
import 'package:aira_app/features/vision/presentation/screens/vision_screen.dart';
import 'package:aira_app/features/voice_notes/presentation/screens/voice_note_screen.dart';
import 'package:aira_app/features/overlay/presentation/screens/overlay_settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/profile-setup',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ProfileSetupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    // ──── Main app: Chat is home ────
    GoRoute(
      path: '/chat',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: ChatScreen(),
      ),
    ),
    // ──── Tool screens (accessed from drawer) ────
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/planner',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const PlannerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/voice-panel',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const VoiceAssistantPanel(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/vision',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AiraVisionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/voice-note',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const VoiceNoteScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/overlay',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OverlaySettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
  ],
);
