import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class CaseManagerApp extends StatelessWidget {
  const CaseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Case Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}