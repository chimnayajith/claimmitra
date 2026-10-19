import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../database/case_database.dart';
import '../models/case.dart';
import '../services/deadline_service.dart';
import '../services/excel_service.dart';

enum CaseFilter { all, needsAttention, active, closed }

class CasesScreen extends StatefulWidget {
  final String? view;
  final String? stage;
  const CasesScreen({super.key, this.view, this.stage});
  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  CaseFilter _filter = CaseFilter.all;
  String _query = '';
  final Set<String> _selectedIds = <String>{};
  late Future<List<CaseRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = CaseDatabase.instance.allCases();
  }

  void _refresh() {
    setState(() {
      _future = CaseDatabase.instance.allCases();
    });
  }

  void _toggleSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${ids.length} case${ids.length == 1 ? '' : 's'}?'),
        content: const Text('This permanently deletes the selected cases and their saved details. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await CaseDatabase.instance.deleteMany(ids);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _future = CaseDatabase.instance.allCases();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${ids.length} case${ids.length == 1 ? '' : 's'}.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete cases: $e')));
      }
    }
  }

  DateTime? _deadlineFor(CaseRecord c) {
    switch (widget.stage) {
      case 'police':
        return c.policeDocumentsDate == null
            ? DeadlineService.addMonths(c.receivedDate, 5)
            : null;
      case 'filing':
        return c.caseFiledDate == null && c.policeDocumentsDate != null
            ? DeadlineService.addMonths(c.receivedDate, 5)
            : null;
      case 'deposit':
        return c.awardDate != null && c.depositDate == null && c.executionDepositDate == null
            ? DeadlineService.addMonthsAndDays(c.awardDate!, 3, 15)
            : null;
      case 'fees':
        return c.depositDate != null && c.feesReceivedDate == null && c.executionDepositDate == null
            ? c.depositDate!.add(const Duration(days: 7))
            : null;
      case 'ep':
        return c.awardDate != null && c.depositDate == null && c.executionDepositDate == null && c.epFiledDate == null
            ? DeadlineService.addMonths(c.awardDate!, 4)
            : null;
      default:
        if (c.awardDate != null && c.depositDate == null && c.executionDepositDate == null) {
          return DeadlineService.addMonthsAndDays(c.awardDate!, 3, 15);
        }
        if (c.depositDate != null && c.feesReceivedDate == null) {
          return c.depositDate!.add(const Duration(days: 7));
        }
        if (c.policeDocumentsDate == null) return DeadlineService.addMonths(c.receivedDate, 5);
        if (c.caseFiledDate == null) return DeadlineService.addMonths(c.receivedDate, 5);
        return null;
    }
  }

  String get _pageTitle {
    switch (widget.stage) {
      case 'police': return 'Police Documents Pending';
      case 'filing': return 'Case Filing Pending';
      case 'deposit': return 'Deposit Pending';
      case 'fees': return 'Fees Pending';
      case 'ep': return 'EP Filing Pending';
    }
    switch (widget.view) {
      case 'active': return 'Active Cases';
      case 'urgent': return 'Urgent Cases';
      case 'dueSoon': return 'Cases Due Soon';
      case 'healthy': return 'Healthy Cases';
      default: return 'All Cases';
    }
  }

  bool _matchesPreset(CaseRecord c) {
    if (widget.stage != null) {
      if (c.isClosed) return false;
      switch (widget.stage) {
        case 'police': return c.policeDocumentsDate == null;
        case 'filing': return c.caseFiledDate == null && c.policeDocumentsDate != null;
        case 'deposit': return c.awardDate != null && c.depositDate == null && c.executionDepositDate == null;
        case 'fees': return c.depositDate != null && c.feesReceivedDate == null && c.executionDepositDate == null;
        case 'ep':
          return c.awardDate != null && c.depositDate == null && c.executionDepositDate == null &&
              c.epFiledDate == null && !DateTime.now().isBefore(DeadlineService.addMonths(c.awardDate!, 4));
      }
    }
    switch (widget.view) {
      case 'active': return !c.isClosed;
      case 'urgent': return _status(c) == 'Overdue';
      case 'dueSoon': return _status(c) == 'Due Soon';
      case 'healthy': return _status(c) == 'Healthy';
      default: return true;
    }
  }

  String _stage(CaseRecord c) {
    if (c.isClosed) return 'Closed';
    if (c.executionDepositDate != null) return 'Deposit Against Execution';
    if (c.epFiledDate != null) return 'EP Filing';
    if (c.feesReceivedDate != null) return 'Fees Received';
    if (c.depositDate != null) return 'Fees Received';
    if (c.awardDate != null) return 'Deposit';
    if (c.evidenceDate != null) return 'Award';
    if (c.caseFiledDate != null) return 'Evidence';
    if (c.policeDocumentsDate != null) return 'Case Filed';
    return 'Police Documents';
  }

  String _status(CaseRecord c) {
    if (c.isClosed) return 'Completed';
    final now = DateTime.now();
    if (c.awardDate != null && c.depositDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(c.awardDate!, 4))) return 'Overdue';
    }
    if (c.awardDate != null && c.depositDate == null) {
      final d = DeadlineService.addMonthsAndDays(c.awardDate!, 2, 15);
      if (!now.isBefore(d)) return 'Due Soon';
    }
    if (c.depositDate != null && c.feesReceivedDate == null) {
      if (!now.isBefore(c.depositDate!.add(const Duration(days: 7)))) return 'Overdue';
      return 'Due Soon';
    }
    final start = c.receivedDate;
    if (c.policeDocumentsDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(start, 5))) return 'Overdue';
      if (!now.isBefore(DeadlineService.addMonths(start, 3))) return 'Due Soon';
    }
    if (c.caseFiledDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(start, 5))) return 'Overdue';
      if (!now.isBefore(DeadlineService.addMonths(start, 4))) return 'Due Soon';
    }
    return 'Healthy';
  }

  Color _statusColor(String s) => switch (s) {
    'Overdue' => Colors.red,
    'Due Soon' => Colors.orange,
    'Completed' => Colors.green,
    _ => Colors.blueGrey,
  };

  String _due(CaseRecord c) {
    DateTime? d;
    if (c.isClosed) return '—';
    if (c.awardDate != null && c.depositDate == null) {
      d = DeadlineService.addMonthsAndDays(c.awardDate!, 2, 15);
    } else if (c.depositDate != null && c.feesReceivedDate == null) {
      d = c.depositDate!.add(const Duration(days: 7));
    } else if (c.policeDocumentsDate == null) {
      d = DeadlineService.addMonths(c.receivedDate, 3);
    } else if (c.caseFiledDate == null) {
      d = DeadlineService.addMonths(c.receivedDate, 4);
    }
    if (d == null) return '—';
    final days = DateTime(d.year,d.month,d.day).difference(DateTime.now()).inDays;
    if (days < 0) return 'Overdue ${-days}d';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  Future<void> _import() async {
    try {
      final preview = await ExcelService.importCases();
      if (!mounted || preview == null) return;
      final detail = preview.errors.take(8).join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview Excel import'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${preview.imported} valid rows ready to import.'),
                  Text('${preview.skipped} rows will be skipped.'),
                  const SizedBox(height: 12),
                  const Text('Required columns: Client Name and Case Received Date. Existing case numbers are skipped.'),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Validation issues:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(detail),
                    if (preview.errors.length > 8) Text('…and ${preview.errors.length - 8} more issues.'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('Import ${preview.imported} rows')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ExcelService.commitImport(preview);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${preview.imported} cases; skipped ${preview.skipped} rows.')));
    } catch (e, stackTrace) {
      debugPrint('Excel import failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));

    }
  }

  Future<void> _export() async {
    try {
      final path = await ExcelService.exportCases(await CaseDatabase.instance.allCases());
      if (mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CaseRecord>>(
      future: _future,
      builder: (context, snapshot) {
        final all = snapshot.data ?? <CaseRecord>[];
        final q = _query.trim().toLowerCase();
        final cases = all.where((c) {
          final status = _status(c);
          final matchesPreset = _matchesPreset(c);
          final matchesQuery = q.isEmpty ||
              (c.caseNumber ?? '').toLowerCase().contains(q) ||
              c.clientName.toLowerCase().contains(q) ||
              _stage(c).toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q);
          final matchesFilter = switch (_filter) {
            CaseFilter.all => true,
            CaseFilter.needsAttention => status == 'Due Soon' || status == 'Overdue',
            CaseFilter.active => !c.isClosed,
            CaseFilter.closed => c.isClosed,
          };
          return matchesPreset && matchesQuery && matchesFilter;
        }).toList()
          ..sort((a,b) {
            if (widget.stage != null) {
              final ad = _deadlineFor(a);
              final bd = _deadlineFor(b);
              if (ad != null && bd != null) return ad.compareTo(bd);
              if (ad != null) return -1;
              if (bd != null) return 1;
            }
            final an = a.caseNumber?.trim().isNotEmpty ?? false;
            final bn = b.caseNumber?.trim().isNotEmpty ?? false;
            if (a.year != b.year) return b.year.compareTo(a.year);
            if (an != bn) return an ? -1 : 1;
            if (an && bn) return a.caseNumber!.compareTo(b.caseNumber!);
            return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
          });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(_pageTitle, style: Theme.of(context).textTheme.headlineLarge),
              FilledButton.icon(onPressed: () => context.go('/cases/new'), icon: const Icon(Icons.add), label: const Text('New Case')),
              OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.file_upload_outlined), label: const Text('Import Excel')),
              OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.file_download_outlined), label: const Text('Export Excel')),
            ]),
            const SizedBox(height: 24),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search case number, client, stage or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close)),
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<CaseFilter>(
                segments: const [
                  ButtonSegment(value: CaseFilter.all, label: Text('All')),
                  ButtonSegment(value: CaseFilter.needsAttention, label: Text('Needs Attention')),
                  ButtonSegment(value: CaseFilter.active, label: Text('Active')),
                  ButtonSegment(value: CaseFilter.closed, label: Text('Closed')),
                ],
                selected: {_filter},
                onSelectionChanged: (v) => setState(() => _filter = v.first),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: cases.isEmpty ? null : () {
                    setState(() {
                      final visibleIds = cases.map((c) => c.id).toSet();
                      if (visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains)) {
                        _selectedIds.removeAll(visibleIds);
                      } else {
                        _selectedIds.addAll(visibleIds);
                      }
                    });
                  },
                  icon: Icon(cases.isNotEmpty && cases.every((c) => _selectedIds.contains(c.id)) ? Icons.deselect : Icons.select_all),
                  label: Text(cases.isNotEmpty && cases.every((c) => _selectedIds.contains(c.id)) ? 'Deselect all visible' : 'Select all visible'),
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty) ...[
                  Text('${_selectedIds.length} selected'),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _deleteSelected,
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete selected'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              Text('Could not load cases: ${snapshot.error}')
            else if (cases.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
                const Icon(Icons.folder_open_outlined, size: 42, color: Colors.blueGrey),
                const SizedBox(height: 12),
                Text(all.isEmpty ? 'No cases yet' : 'No matching cases', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(all.isEmpty ? 'Create a case or import your existing spreadsheet.' : 'Try changing the search or filter.', style: Theme.of(context).textTheme.bodyMedium),
              ]))))
            else
              SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          showCheckboxColumn: false,
                          onSelectAll: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedIds.addAll(cases.map((c) => c.id));
                              } else {
                                _selectedIds.removeAll(cases.map((c) => c.id));
                              }
                            });
                          },
                          columns: const [
                            DataColumn(label: Text('Select')),
                            DataColumn(label: Text('Case No.')),
                            DataColumn(label: Text('Client Name')),
                            DataColumn(label: Text('Current Stage')),
                            DataColumn(label: Text('Due')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: cases.map((c) {
                            final status = _status(c);
                            return DataRow(
                              selected: _selectedIds.contains(c.id),
                              onSelectChanged: (_) => context.go('/cases/${c.id}'),
                              cells: [
                                DataCell(Checkbox(value: _selectedIds.contains(c.id), onChanged: (selected) => _toggleSelected(c.id, selected ?? false))),
                                DataCell(Text((c.caseNumber?.trim().isNotEmpty ?? false) ? c.caseNumber! : 'No case number')),
                                DataCell(Text(c.clientName)),
                                DataCell(Text(_stage(c))),
                                DataCell(Text(_due(c))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                                  child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w600)),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}
