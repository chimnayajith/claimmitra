import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/case.dart';
import 'case_list_row.dart';

class CaseList extends StatelessWidget {
  final List<CaseRecord> cases;

  const CaseList({
    super.key,
    required this.cases,
  });

  String _stage(CaseRecord c) {
    if (c.isClosed) return 'Closed';
    if (c.executionDepositDate != null) return 'Deposit Against Execution';
    if (c.epFiledDate != null) return 'EP Filing';
    if (c.feesReceivedDate != null) return 'Fees Received';
    if (c.depositDate != null) return 'Fees Received';
    if (c.awardDate != null) return 'Deposit';
    if (c.evidenceDate != null) return 'Award';
    if (c.caseFiledDate != null || c.caseNumber?.trim().isNotEmpty == true) return 'Evidence';
    if (c.policeDocumentsDate != null) return 'Case Filed';
    return c.caseNumber?.trim().isNotEmpty == true ? 'Evidence' : 'Police Documents';
  }

  String _status(CaseRecord c) {
    if (c.isClosed) return 'Completed';
    final now = DateTime.now();
    if (c.awardDate != null && c.depositDate == null && !now.isBefore(DateTime(c.awardDate!.year, c.awardDate!.month + 4, c.awardDate!.day))) return 'Overdue';
    if (c.depositDate != null && c.feesReceivedDate == null) return 'Due Soon';
    if (c.caseNumber?.trim().isEmpty != false && c.policeDocumentsDate == null && !now.isBefore(DateTime(c.receivedDate.year, c.receivedDate.month + 5, c.receivedDate.day))) return 'Overdue';
    if (c.caseNumber?.trim().isEmpty != false && c.caseFiledDate == null && !now.isBefore(DateTime(c.receivedDate.year, c.receivedDate.month + 4, c.receivedDate.day))) return 'Due Soon';
    return 'Healthy';
  }

  Color _statusColor(String status) => switch (status) {
    'Overdue' => Colors.red,
    'Due Soon' => Colors.orange,
    'Completed' => Colors.green,
    _ => Colors.blueGrey,
  };

  String _due(CaseRecord c) {
    DateTime? d;
    if (c.isClosed) return '—';
    if (c.awardDate != null && c.depositDate == null) {
      d = DateTime(c.awardDate!.year, c.awardDate!.month + 2, c.awardDate!.day + 15);
    } else if (c.depositDate != null && c.feesReceivedDate == null) {
      d = c.depositDate!.add(const Duration(days: 7));
    } else if (c.caseNumber?.trim().isEmpty != false && c.policeDocumentsDate == null) {
      d = DateTime(c.receivedDate.year, c.receivedDate.month + 3, c.receivedDate.day);
    } else if (c.caseNumber?.trim().isEmpty != false && c.caseFiledDate == null) {
      d = DateTime(c.receivedDate.year, c.receivedDate.month + 4, c.receivedDate.day);
    }
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.grey.shade50,
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Case No.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Client Name',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Current Stage',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Due',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 20),
              ],
            ),
          ),

          for (final caseItem in cases)
            CaseListRow(
              caseNumber: caseItem.caseNumber?.trim().isNotEmpty == true
                  ? caseItem.caseNumber!
                  : 'N/A',
              clientName: caseItem.clientName,
              currentStage: _stage(caseItem),
              due: _due(caseItem),
              status: _status(caseItem),
              statusColor: _statusColor(_status(caseItem)),
              onTap: () {
                context.go('/cases/${caseItem.id}');
              },
            ),
        ],
      ),
    );
  }
}