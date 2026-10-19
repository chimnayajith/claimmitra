import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../database/case_database.dart';
import '../../features/cases/models/case.dart';
import '../../features/cases/services/deadline_service.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/workflow_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<CaseRecord>> _future;
  @override
  void initState() { super.initState(); _future = CaseDatabase.instance.allCases(); }

  String _status(CaseRecord c) {
    if (c.isClosed) return 'Completed';
    final now = DateTime.now();
    if (c.awardDate != null && c.depositDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(c.awardDate!,4))) return 'Overdue';
      if (!now.isBefore(DeadlineService.addMonthsAndDays(c.awardDate!,2,15))) return 'Due Soon';
    }
    if (c.depositDate != null && c.feesReceivedDate == null) {
      if (!now.isBefore(c.depositDate!.add(const Duration(days:7)))) return 'Overdue';
      return 'Due Soon';
    }
    if (c.policeDocumentsDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate,5))) return 'Overdue';
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate,3))) return 'Due Soon';
    }
    if (c.caseFiledDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate,5))) return 'Overdue';
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate,4))) return 'Due Soon';
    }
    return 'Healthy';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CaseRecord>>(
      future: _future,
      builder: (context, snapshot) {
        final cases = snapshot.data ?? <CaseRecord>[];
        final active = cases.where((c) => !c.isClosed).length;
        final urgent = cases.where((c) => _status(c) == 'Overdue').length;
        final due = cases.where((c) => _status(c) == 'Due Soon').length;
        final healthy = cases.where((c) => _status(c) == 'Healthy').length;
        int police = 0, filing = 0, deposit = 0, fees = 0, ep = 0;
        for (final c in cases) {
          if (!c.isClosed && c.policeDocumentsDate == null) police++;
          if (!c.isClosed && c.caseFiledDate == null && c.policeDocumentsDate != null) filing++;
          if (!c.isClosed && c.awardDate != null && c.depositDate == null) deposit++;
          if (!c.isClosed && c.depositDate != null && c.feesReceivedDate == null) fees++;
          if (!c.isClosed && c.awardDate != null && c.depositDate == null && !DateTime.now().isBefore(DeadlineService.addMonths(c.awardDate!,4))) ep++;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dashboard', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text("Here's what's happening today.", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            if (snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns, crossAxisSpacing: 20, mainAxisSpacing: 20,
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 2.2,
                children: [
                  StatCard(title: 'Active Cases', value: '$active', icon: Icons.folder_outlined, color: Colors.blue),
                  StatCard(title: 'Urgent', value: '$urgent', icon: Icons.warning_amber_rounded, color: Colors.red),
                  StatCard(title: 'Due Soon', value: '$due', icon: Icons.schedule, color: Colors.orange),
                  StatCard(title: 'Healthy', value: '$healthy', icon: Icons.check_circle_outline, color: Colors.green),
                ],
              );
            }),
            const SizedBox(height: 40),
            Text('Pending Work', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Card(clipBehavior: Clip.antiAlias, child: Column(children: [
              WorkflowTile(title: 'Police Documents', yellow: police, onTap: () => context.go('/cases')),
              const Divider(height: 1),
              WorkflowTile(title: 'Case Filed', yellow: filing, onTap: () => context.go('/cases')),
              const Divider(height: 1),
              WorkflowTile(title: 'Deposit', yellow: deposit, onTap: () => context.go('/cases')),
              const Divider(height: 1),
              WorkflowTile(title: 'Fees Received', yellow: fees, onTap: () => context.go('/cases')),
              const Divider(height: 1),
              WorkflowTile(title: 'EP Filing', red: ep, onTap: () => context.go('/cases')),
            ])),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: () => context.go('/cases'), icon: const Icon(Icons.arrow_forward), label: const Text('View all cases')),
          ]),
        );
      },
    );
  }
}
