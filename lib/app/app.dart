import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';
import '../licensing/update_prompt.dart';

class CaseManagerApp extends StatelessWidget {
  const CaseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ClaimMitra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) => UpdatePrompt(child: child ?? const SizedBox.shrink()),
    );
  }
}