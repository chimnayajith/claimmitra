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

            Image.asset('assets/branding/claimmitra.png', width: 64, height: 64),

            const SizedBox(height: 10),

            Text(
              'ClaimMitra',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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

            SidebarItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {},
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}