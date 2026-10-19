import 'package:go_router/go_router.dart';

import '../core/widgets/main_scaffold.dart';
import '../features/cases/details/case_details_screen.dart';
import '../features/cases/list/cases_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const DashboardScreen();
          },
        ),
        GoRoute(
          path: '/cases',
          builder: (context, state) {
            return const CasesScreen();
          },
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final caseId = state.pathParameters['id']!;

                return CaseDetailsScreen(
                  caseId: caseId,
                );
              },
            ),
          ],
        ),
      ],
    ),
  ],
);