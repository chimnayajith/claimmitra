import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../database/case_database.dart';
import '../models/case.dart';
import '../services/deadline_service.dart';
import '../services/excel_service.dart';
import 'case_sort.dart';

enum CaseFilter { all, needsAttention, active, closed }

enum CaseSearchScope { all, client, advocate }

enum CaseSortOrder { oldestFirst, newestFirst }

class CasesScreen extends StatefulWidget {
  final String? view;
  final String? stage;
  final bool archived;
  const CasesScreen({super.key, this.view, this.stage, this.archived = false});
  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  bool get archived => widget.archived;
  CaseFilter _filter = CaseFilter.all;
  CaseSearchScope _searchScope = CaseSearchScope.all;
  CaseSortOrder _sortOrder = CaseSortOrder.oldestFirst;
  String _query = '';
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;
  late Future<List<CaseRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = CaseDatabase.instance.allCases(includeArchived: true);
  }

  void _refresh() {
    setState(() {
      _future = CaseDatabase.instance.allCases(includeArchived: true);
    });
  }

  Future<void> _restoreCase(String id) async {
    try {
      await CaseDatabase.instance.restore(id);
      if (mounted) _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not restore case: $e')));
      }
    }
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

  Future<void> _processSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${archived ? 'Restore' : 'Archive'} ${ids.length} case${ids.length == 1 ? '' : 's'}?',
        ),
        content: Text(
          archived
              ? 'The selected cases will return to active lists and dashboard counts.'
              : 'Archived cases are hidden from active lists and dashboard counts. You can restore them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: archived
                ? null
                : FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(archived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await CaseDatabase.instance.setArchived(ids, archived: !archived);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedIds.clear();
        _future = CaseDatabase.instance.allCases(includeArchived: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${archived ? 'Restored' : 'Archived'} ${ids.length} case${ids.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not ${archived ? 'restore' : 'archive'} cases: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedArchived() async {
    if (!archived || _selectedIds.isEmpty) {
      return;
    }
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Permanently delete ${ids.length} archived case${ids.length == 1 ? '' : 's'}?',
        ),
        content: const Text(
          'This cannot be undone. The selected archived cases and their audit history will be deleted, allowing their case numbers to be imported again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await CaseDatabase.instance.permanentlyDelete(ids);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedIds.clear();
        _future = CaseDatabase.instance.allCases(includeArchived: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${ids.length} archived case${ids.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete archived cases: $e')),
        );
      }
    }
  }

  DateTime? _deadlineFor(CaseRecord c) {
    final received = c.receivedDate;
    switch (widget.stage) {
      case 'police':
        return received != null &&
                c.caseNumber?.trim().isEmpty != false &&
                c.policeDocumentsDate == null
            ? DeadlineService.addMonths(received, 5)
            : null;
      case 'filing':
        return received != null &&
                c.caseNumber?.trim().isEmpty != false &&
                c.caseFiledDate == null &&
                c.policeDocumentsDate != null
            ? DeadlineService.addMonths(received, 5)
            : null;
      case 'deposit':
        return c.awardDate != null &&
                c.depositDate == null &&
                c.executionDepositDate == null
            ? DeadlineService.addMonthsAndDays(c.awardDate!, 3, 15)
            : null;
      case 'fees':
        return c.depositDate != null &&
                c.feesReceivedDate == null &&
                c.executionDepositDate == null
            ? c.depositDate!.add(const Duration(days: 7))
            : null;
      case 'ep':
        return c.awardDate != null &&
                c.depositDate == null &&
                c.executionDepositDate == null &&
                c.epFiledDate == null
            ? DeadlineService.addMonths(c.awardDate!, 4)
            : null;
      default:
        if (c.awardDate != null &&
            c.depositDate == null &&
            c.executionDepositDate == null) {
          return DeadlineService.addMonthsAndDays(c.awardDate!, 3, 15);
        }
        if (c.depositDate != null && c.feesReceivedDate == null) {
          return c.depositDate!.add(const Duration(days: 7));
        }
        if (received != null &&
            c.caseNumber?.trim().isEmpty != false &&
            c.policeDocumentsDate == null) {
          return DeadlineService.addMonths(received, 5);
        }
        if (received != null &&
            c.caseNumber?.trim().isEmpty != false &&
            c.caseFiledDate == null) {
          return DeadlineService.addMonths(received, 5);
        }
        return null;
    }
  }

  String get _pageTitle {
    switch (widget.stage) {
      case 'police':
        return 'Police Documents Pending';
      case 'filing':
        return 'Case Filing Pending';
      case 'deposit':
        return 'Deposit Pending';
      case 'fees':
        return 'Fees Pending';
      case 'ep':
        return 'EP Filing Pending';
    }
    switch (widget.view) {
      case 'active':
        return 'Active Cases';
      case 'urgent':
        return 'Urgent Cases';
      case 'dueSoon':
        return 'Cases Due Soon';
      case 'healthy':
        return 'Healthy Cases';
      default:
        return 'All Cases';
    }
  }

  bool _matchesPreset(CaseRecord c) {
    if (widget.stage != null) {
      if (c.isClosed) {
        return false;
      }
      switch (widget.stage) {
        case 'police':
          return c.caseNumber?.trim().isEmpty != false &&
              c.policeDocumentsDate == null;
        case 'filing':
          return c.caseNumber?.trim().isEmpty != false &&
              c.caseFiledDate == null &&
              c.policeDocumentsDate != null;
        case 'deposit':
          return c.awardDate != null &&
              c.depositDate == null &&
              c.executionDepositDate == null;
        case 'fees':
          return c.depositDate != null &&
              c.feesReceivedDate == null &&
              c.executionDepositDate == null;
        case 'ep':
          return c.awardDate != null &&
              c.depositDate == null &&
              c.executionDepositDate == null &&
              c.epFiledDate == null &&
              !DateTime.now().isBefore(
                DeadlineService.addMonths(c.awardDate!, 4),
              );
      }
    }
    switch (widget.view) {
      case 'active':
        return !c.isClosed;
      case 'urgent':
        return _status(c) == 'Overdue';
      case 'dueSoon':
        return _status(c) == 'Due Soon';
      case 'healthy':
        return _status(c) == 'Healthy';
      default:
        return true;
    }
  }

  String _stage(CaseRecord c) {
    if (c.isClosed) {
      return 'Closed';
    }
    if (c.executionDepositDate != null) {
      return 'Deposit Against Execution';
    }
    if (c.epFiledDate != null) {
      return c.epFilingType == 'RR' ? 'RR Filing' : 'EP Filing';
    }
    if (c.feesReceivedDate != null) {
      return 'Fees Received';
    }
    if (c.depositDate != null) {
      return 'Fees Received';
    }
    if (c.awardDate != null) {
      return 'Deposit';
    }
    if (c.evidenceDate != null) {
      return 'Award';
    }
    if (c.caseFiledDate != null || c.caseNumber?.trim().isNotEmpty == true) {
      return 'Evidence';
    }
    if (c.policeDocumentsDate != null) {
      return 'Case Filed';
    }
    return 'Police Documents';
  }

  String _status(CaseRecord c) {
    if (c.isClosed) {
      return 'Completed';
    }
    final now = DateTime.now();
    if (c.awardDate != null && c.depositDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(c.awardDate!, 4))) {
        return 'Overdue';
      }
    }
    if (c.awardDate != null && c.depositDate == null) {
      final d = DeadlineService.addMonthsAndDays(c.awardDate!, 2, 15);
      if (!now.isBefore(d)) {
        return 'Due Soon';
      }
    }
    if (c.depositDate != null && c.feesReceivedDate == null) {
      if (!now.isBefore(c.depositDate!.add(const Duration(days: 7)))) {
        return 'Overdue';
      }
      return 'Due Soon';
    }
    final start = c.receivedDate;
    if (start != null &&
        c.caseNumber?.trim().isEmpty != false &&
        c.policeDocumentsDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(start, 5))) {
        return 'Overdue';
      }
      if (!now.isBefore(DeadlineService.addMonths(start, 3))) {
        return 'Due Soon';
      }
    }
    if (start != null &&
        c.caseNumber?.trim().isEmpty != false &&
        c.caseFiledDate == null) {
      if (!now.isBefore(DeadlineService.addMonths(start, 5))) {
        return 'Overdue';
      }
      if (!now.isBefore(DeadlineService.addMonths(start, 4))) {
        return 'Due Soon';
      }
    }
    return 'Healthy';
  }

  bool _matchesSearch(CaseRecord c, String query, String caseNumberQuery) {
    if (query.isEmpty) {
      return true;
    }
    final matchesClient = c.clientName.toLowerCase().contains(query);
    final matchesAdvocate = CaseRecord.matchesAdvocateQuery(c.advocates, query);
    switch (_searchScope) {
      case CaseSearchScope.client:
        return matchesClient;
      case CaseSearchScope.advocate:
        return matchesAdvocate;
      case CaseSearchScope.all:
        return (c.displayCaseNumber ?? '').toLowerCase().contains(
              caseNumberQuery,
            ) ||
            matchesClient ||
            matchesAdvocate ||
            _stage(c).toLowerCase().contains(query) ||
            c.phone.toLowerCase().contains(query);
    }
  }

  Color _statusColor(String s) => switch (s) {
    'Overdue' => Colors.red,
    'Due Soon' => Colors.orange,
    'Completed' => Colors.green,
    _ => Colors.blueGrey,
  };

  String _due(CaseRecord c) {
    DateTime? d;
    if (c.isClosed) {
      return '—';
    }
    if (c.awardDate != null && c.depositDate == null) {
      d = DeadlineService.addMonthsAndDays(c.awardDate!, 2, 15);
    } else if (c.depositDate != null && c.feesReceivedDate == null) {
      d = c.depositDate!.add(const Duration(days: 7));
    } else if (c.receivedDate != null &&
        c.caseNumber?.trim().isEmpty != false &&
        c.policeDocumentsDate == null) {
      d = DeadlineService.addMonths(c.receivedDate!, 3);
    } else if (c.receivedDate != null &&
        c.caseNumber?.trim().isEmpty != false &&
        c.caseFiledDate == null) {
      d = DeadlineService.addMonths(c.receivedDate!, 4);
    }
    if (d == null) {
      return '—';
    }
    final days = DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime.now()).inDays;
    if (days < 0) {
      return 'Overdue ${-days}d';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _import() async {
    try {
      final preview = await ExcelService.importCases();
      if (!mounted || preview == null) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ExcelImportDialog(preview: preview),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      final imported = await ExcelService.commitImport(preview);
      _refresh();
      final skipped = preview.skipped + preview.imported - imported;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $imported cases; skipped $skipped rows.'),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Excel import failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        final message = e is FormatException
            ? e.message
            : e is DuplicateCaseNumberException
            ? 'Import could not be saved: ${e.caseNumber} already exists.'
            : 'Import could not be saved: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _export() async {
    try {
      final records = (await CaseDatabase.instance.allCases(
        includeArchived: true,
      )).where((c) => archived || !c.isArchived).toList();
      final path = await ExcelService.exportCases(records);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${archived ? 'archived' : 'active'} cases to $path',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  DateTime? _closedDate(CaseRecord c) {
    if (c.executionDepositDate != null) {
      return c.executionDepositDate;
    }
    if (c.depositDate != null && c.feesReceivedDate != null) {
      return c.feesReceivedDate;
    }
    return null;
  }

  Future<void> _exportClosedMonth() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Choose any date in the month to export',
    );
    if (selectedDate == null || !mounted) {
      return;
    }

    try {
      final records =
          (await CaseDatabase.instance.allCases(includeArchived: true)).where((
            c,
          ) {
            if (!c.isClosed || (!archived && c.isArchived)) {
              return false;
            }
            final closedDate = _closedDate(c);
            return closedDate?.year == selectedDate.year &&
                closedDate?.month == selectedDate.month;
          }).toList();
      final month = selectedDate.month.toString().padLeft(2, '0');
      final path = await ExcelService.exportCases(
        records,
        fileName: 'claimmitra-closed-${selectedDate.year}-$month.xlsx',
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${records.length} closed case${records.length == 1 ? '' : 's'} to $path',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Closed-case export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => context.go('/'),
      },
      child: Focus(
        autofocus: true,
        child: FutureBuilder<List<CaseRecord>>(
          future: _future,
          builder: (context, snapshot) {
            final all = snapshot.data ?? <CaseRecord>[];
            final q = _query
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ')
                .toLowerCase();
            final caseNumberQuery = q.replaceAll(RegExp(r'\s+'), '');
            final cases =
                all.where((c) {
                  if (c.isArchived != archived) {
                    return false;
                  }
                  final status = _status(c);
                  final matchesPreset = _matchesPreset(c);
                  final matchesQuery = _matchesSearch(c, q, caseNumberQuery);
                  final matchesFilter = switch (_filter) {
                    CaseFilter.all => true,
                    CaseFilter.needsAttention =>
                      status == 'Due Soon' || status == 'Overdue',
                    CaseFilter.active => !c.isClosed,
                    CaseFilter.closed => c.isClosed,
                  };
                  return matchesPreset && matchesQuery && matchesFilter;
                }).toList()..sort((a, b) {
                  if (_filter == CaseFilter.closed) {
                    final ad = _closedDate(a);
                    final bd = _closedDate(b);
                    if (ad != null && bd != null) return bd.compareTo(ad);
                    if (ad != null) return -1;
                    if (bd != null) return 1;
                  }
                  if (widget.stage != null) {
                    final ad = _deadlineFor(a);
                    final bd = _deadlineFor(b);
                    if (ad != null && bd != null) return ad.compareTo(bd);
                    if (ad != null) {
                      return -1;
                    }
                    if (bd != null) {
                      return 1;
                    }
                  }
                  return compareCasesForChronologicalList(
                    a,
                    b,
                    descending: _sortOrder == CaseSortOrder.newestFirst,
                  );
                });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        archived ? 'Archived Cases' : _pageTitle,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go(
                          archived ? '/cases?view=all' : '/cases?archived=true',
                        ),
                        icon: Icon(
                          archived ? Icons.folder_open : Icons.archive_outlined,
                        ),
                        label: Text(
                          archived ? 'Active cases' : 'Archived cases',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.go('/cases/new'),
                        icon: const Icon(Icons.add),
                        label: const Text('New Case'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Import Excel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(
                          archived
                              ? 'Export archived Excel'
                              : 'Export active Excel',
                        ),
                      ),
                      if (_filter == CaseFilter.closed)
                        OutlinedButton.icon(
                          onPressed: _exportClosedMonth,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Export closed month'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: switch (_searchScope) {
                        CaseSearchScope.all =>
                          'Search case number, client, advocate, stage or phone...',
                        CaseSearchScope.client => 'Search client name...',
                        CaseSearchScope.advocate => 'Search advocate name...',
                      },
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Search in',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<CaseSearchScope>(
                        value: _searchScope,
                        items: const [
                          DropdownMenuItem(
                            value: CaseSearchScope.all,
                            child: Text('All fields'),
                          ),
                          DropdownMenuItem(
                            value: CaseSearchScope.client,
                            child: Text('Client only'),
                          ),
                          DropdownMenuItem(
                            value: CaseSearchScope.advocate,
                            child: Text('Advocate only'),
                          ),
                        ],
                        onChanged: (scope) {
                          if (scope != null) {
                            setState(() => _searchScope = scope);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<CaseFilter>(
                      segments: const [
                        ButtonSegment(
                          value: CaseFilter.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: CaseFilter.needsAttention,
                          label: Text('Needs Attention'),
                        ),
                        ButtonSegment(
                          value: CaseFilter.active,
                          label: Text('Active'),
                        ),
                        ButtonSegment(
                          value: CaseFilter.closed,
                          label: Text('Closed'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (v) =>
                          setState(() => _filter = v.first),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!_selectionMode)
                        OutlinedButton.icon(
                          onPressed: cases.isEmpty
                              ? null
                              : () => setState(() => _selectionMode = true),
                          icon: const Icon(Icons.check_box_outlined),
                          label: const Text('Select'),
                        )
                      else
                        TextButton.icon(
                          onPressed: cases.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    final visibleIds = cases
                                        .map((c) => c.id)
                                        .toSet();
                                    if (visibleIds.isNotEmpty &&
                                        visibleIds.every(
                                          _selectedIds.contains,
                                        )) {
                                      _selectedIds.removeAll(visibleIds);
                                    } else {
                                      _selectedIds.addAll(visibleIds);
                                    }
                                  });
                                },
                          icon: Icon(
                            cases.isNotEmpty &&
                                    cases.every(
                                      (c) => _selectedIds.contains(c.id),
                                    )
                                ? Icons.deselect
                                : Icons.select_all,
                          ),
                          label: Text(
                            cases.isNotEmpty &&
                                    cases.every(
                                      (c) => _selectedIds.contains(c.id),
                                    )
                                ? 'Deselect all visible'
                                : 'Select all visible',
                          ),
                        ),
                      if (widget.stage == null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _sortOrder = _sortOrder == CaseSortOrder.oldestFirst
                                ? CaseSortOrder.newestFirst
                                : CaseSortOrder.oldestFirst;
                          }),
                          icon: const Icon(Icons.swap_vert),
                          label: Text(
                            _sortOrder == CaseSortOrder.oldestFirst
                                ? 'Oldest first'
                                : 'Newest first',
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_selectedIds.isNotEmpty) ...[
                        Text('${_selectedIds.length} selected'),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _processSelected,
                          icon: Icon(
                            archived ? Icons.restore : Icons.archive_outlined,
                          ),
                          label: Text(
                            archived ? 'Restore selected' : 'Archive selected',
                          ),
                        ),
                        if (archived) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _deleteSelectedArchived,
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Delete permanently'),
                          ),
                        ],
                      ],
                      if (_selectionMode) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectionMode = false;
                            _selectedIds.clear();
                          }),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    Text('Could not load cases: ${snapshot.error}')
                  else if (cases.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.folder_open_outlined,
                                size: 42,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                all.isEmpty
                                    ? 'No cases yet'
                                    : 'No matching cases',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                all.isEmpty
                                    ? 'Create a case or import your existing spreadsheet.'
                                    : 'Try changing the search or filter.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) => Card(
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                showCheckboxColumn: false,
                                onSelectAll: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedIds.addAll(
                                        cases.map((c) => c.id),
                                      );
                                    } else {
                                      _selectedIds.removeAll(
                                        cases.map((c) => c.id),
                                      );
                                    }
                                  });
                                },
                                columns: [
                                  if (_selectionMode)
                                    DataColumn(label: Text('Select')),
                                  DataColumn(label: Text('Case No.')),
                                  DataColumn(
                                    label: SizedBox(
                                      width: 220,
                                      child: Text('Client Name'),
                                    ),
                                  ),
                                  DataColumn(label: Text('Current Stage')),
                                  DataColumn(label: Text('Due')),
                                  DataColumn(label: Text('Status')),
                                  if (archived)
                                    DataColumn(label: Text('Action')),
                                ],
                                rows: cases.map((c) {
                                  final status = _status(c);
                                  return DataRow(
                                    selected: _selectedIds.contains(c.id),
                                    onSelectChanged: (_) async {
                                      if (_selectionMode) {
                                        _toggleSelected(
                                          c.id,
                                          !_selectedIds.contains(c.id),
                                        );
                                        return;
                                      }
                                      await context.push('/cases/${c.id}');
                                      if (mounted) _refresh();
                                    },
                                    cells: [
                                      if (_selectionMode)
                                        DataCell(
                                          Checkbox(
                                            value: _selectedIds.contains(c.id),
                                            onChanged: (selected) =>
                                                _toggleSelected(
                                                  c.id,
                                                  selected ?? false,
                                                ),
                                          ),
                                        ),
                                      DataCell(
                                        Text(
                                          (c.displayCaseNumber
                                                      ?.trim()
                                                      .isNotEmpty ??
                                                  false)
                                              ? c.displayCaseNumber!
                                              : 'No case number',
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 220,
                                          child: Text(
                                            c.clientName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(_stage(c))),
                                      DataCell(Text(_due(c))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusColor(
                                              status,
                                            ).withValues(alpha: .12),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: _statusColor(status),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (archived)
                                        DataCell(
                                          TextButton.icon(
                                            onPressed: () => _restoreCase(c.id),
                                            icon: const Icon(Icons.restore),
                                            label: const Text('Restore'),
                                          ),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExcelImportDialog extends StatefulWidget {
  final ExcelImportResult preview;

  const _ExcelImportDialog({required this.preview});

  @override
  State<_ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<_ExcelImportDialog> {
  final Map<int, List<TextEditingController>> _controllers = {};
  final ScrollController _horizontalScrollController = ScrollController();
  bool _checking = false;
  bool _confirmPossibleDuplicates = false;

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  void _createControllers() {
    for (final row in widget.preview.invalidRows) {
      _controllers.putIfAbsent(
        row.sourceRow,
        () => [
          TextEditingController(text: row.clientName),
          TextEditingController(text: row.caseNumber),
          TextEditingController(text: row.receivedDate),
          TextEditingController(text: row.accidentDate),
        ],
      );
    }
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);
    for (final row in widget.preview.invalidRows) {
      final fields = _controllers[row.sourceRow]!;
      row.update(
        clientName: fields[0].text,
        caseNumber: fields[1].text,
        receivedDate: fields[2].text,
        accidentDate: fields[3].text,
      );
    }
    await ExcelService.revalidate(
      widget.preview,
      allowPossibleDuplicates: _confirmPossibleDuplicates,
    );
    if (mounted) {
      _createControllers();
      setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    for (final fields in _controllers.values) {
      for (final controller in fields) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final hasPossibleDuplicates = preview.invalidRows.any(
      (row) => row.problems.any(
        (problem) => problem.startsWith('Possible duplicate:'),
      ),
    );
    return AlertDialog(
      title: const Text('Preview Excel import'),
      content: SizedBox(
        width: 900,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${preview.imported} valid rows ready to import.'),
                Text(
                  '${preview.skipped} rows need correction or confirmation.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Edit the problem rows below, then select Recheck. Other spreadsheet data in these rows will be kept. Rows without a Case Number are checked against Client Name and Accident Date.',
                ),
                if (hasPossibleDuplicates)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmPossibleDuplicates,
                    onChanged: _checking
                        ? null
                        : (value) => setState(
                            () => _confirmPossibleDuplicates = value ?? false,
                          ),
                    title: const Text(
                      'These possible duplicates are different cases',
                    ),
                    subtitle: const Text(
                      'Confirm this before importing rows that have no Case Number.',
                    ),
                  ),
                if (preview.invalidRows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('Excel row')),
                          DataColumn(label: Text('Client Name')),
                          DataColumn(label: Text('Case Number')),
                          DataColumn(label: Text('Received Date')),
                          DataColumn(label: Text('Accident Date')),
                          DataColumn(label: Text('Problem')),
                        ],
                        rows: preview.invalidRows.map((row) {
                          final fields = _controllers[row.sourceRow]!;
                          return DataRow(
                            cells: [
                              DataCell(Text('${row.sourceRow}')),
                              DataCell(
                                SizedBox(
                                  width: 170,
                                  child: TextField(
                                    controller: fields[0],
                                    decoration: const InputDecoration(
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: TextField(
                                    controller: fields[1],
                                    decoration: const InputDecoration(
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: TextField(
                                    controller: fields[3],
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'DD/MM/YYYY',
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: TextField(
                                    controller: fields[2],
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'DD/MM/YYYY',
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(row.problems.join('\n'))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (preview.invalidRows.isNotEmpty)
          OutlinedButton(
            onPressed: _checking ? null : _recheck,
            child: Text(_checking ? 'Checking...' : 'Recheck'),
          ),
        FilledButton(
          onPressed: preview.imported == 0
              ? null
              : () => Navigator.pop(context, true),
          child: Text('Import ${preview.imported} rows'),
        ),
      ],
    );
  }
}
