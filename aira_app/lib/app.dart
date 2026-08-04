import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/theme/aira_theme_data.dart';
import 'package:aira_app/core/theme/theme_provider.dart';
import 'package:aira_app/routing/app_router.dart';

class AiraApp extends ConsumerWidget {
  const AiraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'AIRA OS',
      debugShowCheckedModeBanner: false,
      theme: AiraThemeData.lightTheme,
      darkTheme: AiraThemeData.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
