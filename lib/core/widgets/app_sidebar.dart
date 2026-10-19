import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'sidebar_item.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    final isDashboard = location == '/';
    final isCases = location.startsWith('/cases');

    return Container(
      width: 240,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Image.asset('assets/branding/claimmitra_icon.png', width: 48, height: 48),

            const SizedBox(height: 10),

            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
                children: const [
                  TextSpan(text: 'Claim', style: TextStyle(color: Color(0xFF0F2A56))),
                  TextSpan(text: 'Mitra', style: TextStyle(color: Color(0xFF2563EB))),
                ],
              ),
            ),

            const SizedBox(height: 30),

            SidebarItem(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              selected: isDashboard,
              onTap: () {
                context.go('/');
              },
            ),

            SidebarItem(
              icon: Icons.folder_outlined,
              title: 'Cases',
              selected: isCases,
              onTap: () {
                context.go('/cases');
              },
            ),

            const Spacer(),

            const Divider(),

          ],
        ),
      ),
    );
  }
}