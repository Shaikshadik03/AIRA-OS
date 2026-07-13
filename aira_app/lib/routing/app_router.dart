import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:aira_app/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:aira_app/features/auth/presentation/screens/login_screen.dart';
import 'package:aira_app/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:aira_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:aira_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:aira_app/features/planner/presentation/screens/planner_screen.dart';
import 'package:aira_app/features/finance/presentation/screens/finance_screen.dart';
import 'package:aira_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:aira_app/features/nav_shell/presentation/screens/main_shell_screen.dart';
import 'package:aira_app/features/memory/presentation/screens/memory_screen.dart';
import 'package:aira_app/features/study/presentation/screens/study_screen.dart';
import 'package:aira_app/features/coding/presentation/screens/coding_screen.dart';
import 'package:aira_app/features/voice/presentation/screens/voice_assistant_panel.dart';
import 'package:aira_app/features/creative/presentation/screens/creative_screen.dart';
import 'package:aira_app/features/business/presentation/screens/business_screen.dart';

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
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/study',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const StudyScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/coding',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CodingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/creative',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CreativeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/business',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const BusinessScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/voice',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const VoiceAssistantPanel(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ChatScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/planner',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PlannerScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/finance',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: FinanceScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'memory',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const MemoryScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
