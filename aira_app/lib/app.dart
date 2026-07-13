import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_theme.dart';
import 'package:aira_app/routing/app_router.dart';

class AiraApp extends StatelessWidget {
  const AiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AIRA OS',
      debugShowCheckedModeBanner: false,
      theme: AiraTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
