import 'package:flutter/material.dart';

import 'app_sidebar.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSidebar(),

          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Colors.grey.shade300,
          ),

          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}