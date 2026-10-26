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
    if (c.receivedDate != null && c.caseNumber?.trim().isEmpty != false && c.policeDocumentsDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate!,5))) return 'Overdue';
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate!,3))) return 'Due Soon';
    }
    if (c.receivedDate != null && c.caseNumber?.trim().isEmpty != false && c.caseFiledDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate!,5))) return 'Overdue';
      if (!now.isBefore(DeadlineService.addMonths(c.receivedDate!,4))) return 'Due Soon';
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
        final now = DateTime.now();
        Map<String, int> countsFor(String stage) {
          var yellow = 0, orange = 0, red = 0;
          for (final c in cases) {
            if (c.isClosed) continue;
            DateTime? orangeAt, redAt;
            bool pending = false;
            switch (stage) {
              case 'police':
                pending = c.caseNumber?.trim().isEmpty != false && c.policeDocumentsDate == null;
                if (c.receivedDate != null) {
                  orangeAt = DeadlineService.addMonths(c.receivedDate!, 4);
                  redAt = DeadlineService.addMonths(c.receivedDate!, 5);
                }
                break;
              case 'filing':
                pending = c.caseNumber?.trim().isEmpty != false && c.policeDocumentsDate != null && c.caseFiledDate == null;
                if (c.receivedDate != null) redAt = DeadlineService.addMonths(c.receivedDate!, 5);
                break;
              case 'deposit':
                pending = c.awardDate != null && c.depositDate == null && c.executionDepositDate == null;
                if (c.awardDate != null) { orangeAt = DeadlineService.addMonths(c.awardDate!, 3); redAt = DeadlineService.addMonthsAndDays(c.awardDate!, 3, 15); }
                break;
              case 'fees':
                pending = c.depositDate != null && c.feesReceivedDate == null;
                if (c.depositDate != null) redAt = c.depositDate!.add(const Duration(days: 7));
                break;
              case 'ep':
                pending = c.awardDate != null && c.depositDate == null && c.executionDepositDate == null && c.epFiledDate == null && !now.isBefore(DeadlineService.addMonths(c.awardDate!, 4));
                if (c.awardDate != null) redAt = DeadlineService.addMonths(c.awardDate!, 4);
                break;
            }
            if (!pending) continue;
            if (redAt != null && !now.isBefore(redAt)) { red++; }
            else if (orangeAt != null && !now.isBefore(orangeAt)) { orange++; }
            else { yellow++; }
          }
          return {'yellow': yellow, 'orange': orange, 'red': red};
        }
        final police = countsFor('police'), filing = countsFor('filing'), deposit = countsFor('deposit'), fees = countsFor('fees'), ep = countsFor('ep');
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dashboard', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text("Here's what's happening today.", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            if (snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12,
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.8,
                children: [
                  StatCard(title: 'Active Cases', value: '$active', icon: Icons.folder_outlined, color: Colors.blue, onTap: () => context.go('/cases?view=active')),
                  StatCard(title: 'Urgent', value: '$urgent', icon: Icons.warning_amber_rounded, color: Colors.red, onTap: () => context.go('/cases?view=urgent')),
                  StatCard(title: 'Due Soon', value: '$due', icon: Icons.schedule, color: Colors.orange, onTap: () => context.go('/cases?view=dueSoon')),
                  StatCard(title: 'Healthy', value: '$healthy', icon: Icons.check_circle_outline, color: Colors.green, onTap: () => context.go('/cases?view=healthy')),
                ],
              );
            }),
            const SizedBox(height: 28),
            Text('Pending Work', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Card(clipBehavior: Clip.antiAlias, child: Column(children: [
              WorkflowTile(title: 'Police Documents', yellow: police['yellow']!, orange: police['orange']!, red: police['red']!, onTap: () => context.go('/cases?stage=police')),
              const Divider(height: 1),
              WorkflowTile(title: 'Case Filed', yellow: filing['yellow']!, orange: filing['orange']!, red: filing['red']!, onTap: () => context.go('/cases?stage=filing')),
              const Divider(height: 1),
              WorkflowTile(title: 'Deposit', yellow: deposit['yellow']!, orange: deposit['orange']!, red: deposit['red']!, onTap: () => context.go('/cases?stage=deposit')),
              const Divider(height: 1),
              WorkflowTile(title: 'Fees Received', yellow: fees['yellow']!, orange: fees['orange']!, red: fees['red']!, onTap: () => context.go('/cases?stage=fees')),
              const Divider(height: 1),
              WorkflowTile(title: 'EP Filing', yellow: ep['yellow']!, orange: ep['orange']!, red: ep['red']!, onTap: () => context.go('/cases?stage=ep')),
            ])),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: () => context.go('/cases?view=all'), icon: const Icon(Icons.arrow_forward), label: const Text('View all cases')),
          ]),
        );
      },
    );
  }
}
