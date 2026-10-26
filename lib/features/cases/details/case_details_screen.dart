import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../database/case_database.dart';
import '../models/case.dart';
import '../services/deadline_service.dart';

class CaseDetailsScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailsScreen({super.key, required this.caseId});
  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caseYear = TextEditingController();
  final _caseSequence = TextEditingController();
  final _received = TextEditingController();
  final _accident = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _station = TextEditingController();
  final _responsible = TextEditingController();
  final _courtFiled = TextEditingController();
  final _advocates = TextEditingController();
  final _police = TextEditingController();
  final _filed = TextEditingController();
  final _evidence = TextEditingController();
  final _award = TextEditingController();
  final _awardAmount = TextEditingController();
  final _awardAmountInterestCost = TextEditingController();
  String? _awardType;
  String? _epFilingType;
  Timer? _autosaveTimer;
  bool _autoSaving = false;
  final _deposit = TextEditingController();
  final _depositAmount = TextEditingController();
  final _fees = TextEditingController();
  final _feesAmount = TextEditingController();
  final _ep = TextEditingController();
  final _execution = TextEditingController();
  final _executionAmount = TextEditingController();

  CaseRecord? _record;
  bool _loading = true;
  bool _saving = false;
  bool get _isNew => widget.caseId == 'new';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final controller in [
      _caseYear,
      _caseSequence,
      _received,
      _accident,
      _name,
      _address,
      _phone,
      _station,
      _responsible,
      _courtFiled,
      _advocates,
      _police,
      _filed,
      _evidence,
      _award,
      _awardAmount,
      _awardAmountInterestCost,
      _deposit,
      _depositAmount,
      _fees,
      _feesAmount,
      _ep,
      _execution,
      _executionAmount,
    ]) {
      controller.clear();
    }
    _awardType = null;
    _epFilingType = null;
    if (!_isNew) {
      _record = await CaseDatabase.instance.getCase(widget.caseId);
      final c = _record;
      if (c != null) {
        final caseParts = (c.caseNumber ?? '').split('/');
        if (caseParts.length == 2) {
          _caseSequence.text = caseParts[0].trim();
          _caseYear.text = caseParts[1].trim();
        } else if (caseParts.length == 1 && caseParts[0].trim().isNotEmpty) {
          _caseSequence.text = caseParts[0].trim();
        }
        _received.text = _fmt(c.receivedDate);
        _accident.text = _fmt(c.accidentDate);
        _name.text = c.clientName;
        _address.text = c.address;
        _phone.text = c.phone;
        _station.text = c.policeStation;
        _responsible.text = c.responsibleParty;
        _courtFiled.text = c.courtFiled;
        _advocates.text = c.advocates;
        _police.text = _fmt(c.policeDocumentsDate);
        _filed.text = _fmt(c.caseFiledDate);
        _evidence.text = _fmt(c.evidenceDate);
        _award.text = _fmt(c.awardDate);
        _awardType = c.awardType;
        _awardAmount.text = c.awardAmount?.toString() ?? '';
        _awardAmountInterestCost.text = c.awardAmountInterestCost?.toString() ?? '';
        _deposit.text = _fmt(c.depositDate);
        _depositAmount.text = c.depositAmount?.toString() ?? '';
        _fees.text = _fmt(c.feesReceivedDate);
        _feesAmount.text = c.feesAmount?.toString() ?? '';
        _ep.text = _fmt(c.epFiledDate);
        _epFilingType = c.epFilingType ?? (c.epFiledDate == null ? null : 'EP');
        _execution.text = _fmt(c.executionDepositDate);
        _executionAmount.text = c.executionDepositAmount?.toString() ?? '';
      }
    } else {
      _received.text = _fmt(DateTime.now());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reload() async {
    if (_saving) return;
    _autosaveTimer?.cancel();
    if (mounted) setState(() => _loading = true);
    await _load();
  }

  @override
  void dispose() {
    for (final c in [
      _caseYear,_caseSequence,_received,_accident,_name,_address,_phone,_station,_responsible,_courtFiled,_advocates,
      _police,_filed,_evidence,_award,_awardAmount,_awardAmountInterestCost,_deposit,_depositAmount,_fees,_feesAmount,_ep,_execution,_executionAmount,
    ]) { c.dispose(); }
    _autosaveTimer?.cancel();
    super.dispose();
  }

  DateTime? _parse(String s) {
    if (s.trim().isEmpty) return null;
    final parts = s.trim().split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]); final m = int.tryParse(parts[1]); final y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null) return null;
      final date = DateTime(y,m,d);
      if (date.year == y && date.month == m && date.day == d) return date;
    }
    return DateTime.tryParse(s);
  }

  String _fmt(DateTime? d) => d == null ? '' : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  double? _money(String s) => s.trim().isEmpty ? null : double.tryParse(s.replaceAll(',', '').replaceAll('₹','').trim());

  DateTime _earliestFor(TextEditingController controller) {
    DateTime? prior;
    if (controller == _received) prior = _parse(_accident.text);
    if (controller == _police) prior = _parse(_received.text);
    if (controller == _filed) prior = _hasCaseNumber ? _parse(_received.text) : _parse(_police.text);
    if (controller == _evidence) prior = _hasCaseNumber ? _parse(_received.text) : _parse(_filed.text);
    if (controller == _award) prior = _parse(_evidence.text);
    if (controller == _deposit) prior = _parse(_award.text);
    if (controller == _fees) prior = _parse(_deposit.text);
    if (controller == _ep) {
      final award = _parse(_award.text);
      if (award != null) prior = DeadlineService.addMonths(award, 4);
    }
    if (controller == _execution) prior = _parse(_ep.text);
    return prior == null ? DateTime(1950) : DateTime(prior.year, prior.month, prior.day);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = _parse(controller.text);
    final first = _earliestFor(controller);
    final today = DateTime.now();
    final last = DateTime(today.year, today.month, today.day);
    if (first.isAfter(last)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This date cannot be selected until the preceding deadline has passed.')));
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first) && !current.isAfter(last) ? current : (first.isAfter(last) ? last : (first.isAfter(DateTime(1950)) ? first : last)),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => controller.text = _fmt(picked));
      _scheduleAutosave();
    }
  }

  void _scheduleAutosave() {
    if (_loading) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_saving) _save(silent: true);
    });
  }

  Future<void> _save({bool silent = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final accidentDateForValidation = _parse(_accident.text);
    final dates = <String, DateTime?>{
      'Case Received Date': _parse(_received.text),
      'Date of Accident': accidentDateForValidation,
      'Police Documents Date': _parse(_police.text),
      'Case Filed Date': _parse(_filed.text),
      'Evidence Date': _parse(_evidence.text),
      'Award Date': _parse(_award.text),
      'Deposit Date': _parse(_deposit.text),
      'Fees Received Date': _parse(_fees.text),
      'EP Filed Date': _parse(_ep.text),
      'Deposit Against Execution Date': _parse(_execution.text),
    };
    final today = DateTime.now();
    for (final entry in dates.entries) {
      final date = entry.value;
      if (date != null && date.isAfter(DateTime(today.year, today.month, today.day))) {
        if (!silent) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${entry.key} cannot be in the future.')));
        return;
      }
    }
    final accidentDate = _parse(_accident.text);
    if (accidentDate != null && dates['Case Received Date'] != null && accidentDate.isAfter(dates['Case Received Date']!)) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date of Accident cannot be after Case Received Date.')));
      return;
    }
    final receivedDate = dates['Case Received Date'];
    final policeDate = dates['Police Documents Date'];
    final filedDate = dates['Case Filed Date'];
    final evidenceDate = dates['Evidence Date'];
    final awardDate = dates['Award Date'];
    final depositDate = dates['Deposit Date'];
    final feesDate = dates['Fees Received Date'];
    final epDate = dates['EP Filed Date'];
    final executionDate = dates['Deposit Against Execution Date'];
    final timeline = <(String, DateTime?, String, DateTime?)>[
      ('Date of Accident', accidentDateForValidation, 'Case Received Date', receivedDate),
      if (!_hasCaseNumber) ('Case Received Date', receivedDate, 'Police Documents Date', policeDate),
      if (!_hasCaseNumber) ('Police Documents Date', policeDate, 'Case Filed Date', filedDate),
      (_hasCaseNumber ? 'Case Received Date' : 'Case Filed Date', _hasCaseNumber ? receivedDate : filedDate, 'Evidence Date', evidenceDate),
      ('Evidence Date', evidenceDate, 'Award Date', awardDate),
      ('Award Date', awardDate, 'Deposit Date', depositDate),
      ('Deposit Date', depositDate, 'Fees Received Date', feesDate),
      ('EP Filed Date', epDate, 'Deposit Against Execution Date', executionDate),
    ];
    for (final pair in timeline) {
      final earlier = pair.$2;
      final later = pair.$4;
      if (earlier != null && later != null && later.isBefore(earlier)) {
        if (!silent) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pair.$3} cannot be before ${pair.$1}.')));
        return;
      }
    }
    if (epDate != null && awardDate != null && epDate.isBefore(DeadlineService.addMonths(awardDate, 4))) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EP Filing Date cannot be before four months after the Award Date.')));
      return;
    }
    if (epDate != null && depositDate != null) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EP filing is only for cases without a normal deposit.')));
      return;
    }
    if (_caseYear.text.trim().isNotEmpty != _caseSequence.text.trim().isNotEmpty) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both Case Year and Case Number, or leave both blank.')));
      return;
    }
    if (_caseYear.text.trim().isNotEmpty && (!RegExp(r'^\d{4}$').hasMatch(_caseYear.text.trim()) || !RegExp(r'^\d+$').hasMatch(_caseSequence.text.trim()))) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case Year must be 4 digits and Case Number must be numeric.')));
      return;
    }
    if (_phone.text.trim().isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(_phone.text.trim())) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number must contain exactly 10 digits.')));
      return;
    }
    final received = _parse(_received.text);
    if (received == null && !_hasCaseNumber) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a valid Case Received Date.')));
      return;
    }
    setState(() { _saving = true; _autoSaving = silent; });
    final now = DateTime.now();
    final old = _record;
    final record = CaseRecord(
      id: old?.id ?? 'case_${now.microsecondsSinceEpoch}',
      caseNumber: _caseYear.text.trim().isEmpty && _caseSequence.text.trim().isEmpty
          ? null
          : '${_caseSequence.text.trim()}/${_caseYear.text.trim()}',
      receivedDate: received,
      accidentDate: _parse(_accident.text),
      clientName: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      policeStation: _station.text.trim(),
      responsibleParty: _responsible.text.trim(),
      courtFiled: _courtFiled.text.trim(),
      advocates: CaseRecord.normalizeAdvocates(_advocates.text),
      policeDocumentsDate: _parse(_police.text),
      caseFiledDate: _parse(_filed.text),
      evidenceDate: _parse(_evidence.text),
      awardDate: _parse(_award.text),
      awardType: _awardType,
      awardAmount: _money(_awardAmount.text),
      awardAmountInterestCost: _money(_awardAmountInterestCost.text),
      depositDate: _parse(_deposit.text),
      depositAmount: _money(_depositAmount.text),
      feesReceivedDate: _parse(_fees.text),
      feesAmount: _money(_feesAmount.text),
      epFiledDate: _parse(_ep.text),
      epFilingType: _epFilingType ?? (_parse(_ep.text) == null ? null : 'EP'),
      executionDepositDate: _parse(_execution.text),
      executionDepositAmount: _money(_executionAmount.text),
      isArchived: old?.isArchived ?? false,
      archivedAt: old?.archivedAt,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await CaseDatabase.instance.save(record);
      if (!mounted) return;
      setState(() { _record = record; _saving = false; _autoSaving = false; });
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case saved.')));
      if (_isNew) context.pop(record.id);
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; _autoSaving = false; });
        if (!silent) {
          final message = e is DuplicateCaseNumberException
              ? e.toString()
              : 'Could not save case: $e';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
  }

  bool get _detailsReady => (_hasCaseNumber || _parse(_received.text) != null) && _name.text.trim().isNotEmpty;
  bool get _hasCaseNumber => _caseYear.text.trim().isNotEmpty && _caseSequence.text.trim().isNotEmpty;
  String get _combinedCaseNumber => _hasCaseNumber ? '${_caseSequence.text.trim()}/${_caseYear.text.trim()}' : '';
  bool get _policeReady => _hasCaseNumber || _parse(_police.text) != null;
  bool get _filedReady => _hasCaseNumber || _parse(_filed.text) != null;
  bool get _evidenceReady => _parse(_evidence.text) != null;
  bool get _awardReady => _parse(_award.text) != null;
  bool get _depositReady => _parse(_deposit.text) != null && _money(_depositAmount.text) != null;
  bool get _feesReady => _parse(_fees.text) != null && _money(_feesAmount.text) != null;
  bool get _epReady => _parse(_ep.text) != null;
  bool get _executionReady => _parse(_execution.text) != null && _money(_executionAmount.text) != null;

  String _filingStatus(DateTime received, DateTime? completed) {
    if (completed != null) return 'Completed';
    final now = DateTime.now();
    if (now.isBefore(DeadlineService.addMonths(received, 4))) return 'Healthy';
    if (now.isBefore(DeadlineService.addMonths(received, 5))) return 'Yellow';
    return 'Overdue';
  }

  String _dateStatus(DateTime? start, DateTime? completed, DateTime deadline, {DateTime? orange, DateTime? red}) {
    if (completed != null) return 'Completed';
    final now = DateTime.now();
    if (now.isBefore(deadline)) return 'Healthy';
    if (orange != null && now.isBefore(orange)) return 'Yellow';
    if (red != null && now.isBefore(red)) return 'Orange';
    return 'Overdue';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_isNew && _record == null) return const Center(child: Text('Case not found.'));
    final received = _parse(_received.text);
    final award = _parse(_award.text);
    final deposit = _parse(_deposit.text);
    final policeDeadline = received == null ? null : DeadlineService.addMonths(received, 3);
    final filingDeadline = received == null ? null : DeadlineService.addMonths(received, 4);
    final depositDeadline = award == null ? null : DeadlineService.addMonthsAndDays(award, 2, 15);
    final epDeadline = award == null ? null : DeadlineService.addMonths(award, 4);

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        SingleActivator(LogicalKeyboardKey.keyR, control: true): _reload,
        SingleActivator(LogicalKeyboardKey.keyR, meta: true): _reload,
        const SingleActivator(LogicalKeyboardKey.escape): _goBack,
      },
      child: Focus(
        autofocus: true,
        child: Column(children: [
      Material(
        elevation: 2,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(children: [
            IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name.text.isEmpty ? (_isNew ? 'New Case' : 'Case Details') : _name.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
              Text([
                _combinedCaseNumber.isEmpty ? 'No case number assigned' : 'Case No. $_combinedCaseNumber',
                if (_courtFiled.text.trim().isNotEmpty) 'Court: ${_courtFiled.text.trim()}',
                if (_advocates.text.trim().isNotEmpty) 'Advocates: ${CaseRecord.normalizeAdvocates(_advocates.text)}',
              ].join('  •  '), style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            if (_autoSaving) const Padding(padding: EdgeInsets.only(right: 12), child: Text('Autosaving…')),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save')),
          ]),
        ),
      ),
      Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              _section(1, 'Case Details', 'Basic information and client contact details', completed: _detailsReady, child: Column(children: [
                _row(
                  Row(children: [
                    Expanded(child: _field(_caseSequence, 'Case Number', numeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_caseYear, 'Case Year', numeric: true)),
                  ]),
                  _date(_received,'Case Received Date', requiredField: true),
                ),
                const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 6), child: Text('Case number format: NUMBER/YEAR'))),
                const SizedBox(height: 16),
                _row(_date(_accident,'Date of Accident'), _field(_name,'Client Name', requiredField: true)),
                const SizedBox(height: 16),
                _field(_address,'Address', maxLines: 2),
                const SizedBox(height: 16),
                _row(_field(_phone,'Phone Number', numeric: true), _field(_station,'Police Station')),
                const SizedBox(height: 16),
                _field(_responsible,'Responsible Company / Person'),
                const SizedBox(height: 16),
                _row(_field(_courtFiled,'Court Filed'), _field(_advocates,'Advocate (comma-separated)', maxLines: 2)),
              ])),
              _connector(),
              _section(2, _hasCaseNumber ? 'Police Documents (Skipped)' : 'Police Documents', _hasCaseNumber ? 'Case number already assigned; continue with case filing and evidence' : 'Deadline: 3 months yellow · 4 months orange · 5 months red', locked: !_detailsReady, completed: _policeReady, deadline: policeDeadline, status: received == null ? null : _dateStatus(received, _parse(_police.text), DeadlineService.addMonths(received,3), orange: DeadlineService.addMonths(received,4), red: DeadlineService.addMonths(received,5)), child: _hasCaseNumber ? const SizedBox.shrink() : _date(_police,'Documents Received Date')),
              _connector(),
              _section(3, 'Case Filed', 'Deadline: 4 months yellow · 5 months red', locked: !_detailsReady || (!_hasCaseNumber && !_policeReady), completed: _filedReady, deadline: filingDeadline, status: received == null ? null : _filingStatus(received, _parse(_filed.text)), child: _date(_filed,'Case Filed Date')),
              _connector(),
              _section(4, 'Evidence', 'Record the evidence date', locked: !_filedReady, completed: _evidenceReady, child: _date(_evidence,'Evidence Date')),
              _connector(),
                _section(5, 'Award / Court Decision', 'Record the award date and amounts', locked: !_filedReady, completed: _awardReady, child: Column(children: [
                DropdownButtonFormField<String>(initialValue: _awardType, decoration: const InputDecoration(labelText: 'Type of Award'), items: const [DropdownMenuItem(value: 'Settlement', child: Text('Settlement')), DropdownMenuItem(value: 'Court', child: Text('Court'))], onChanged: (value) { setState(() => _awardType = value); _scheduleAutosave(); }),
                const SizedBox(height: 16),
                _row(_date(_award,'Award Date'), _field(_awardAmount,'Award Amount (₹)', numeric: true)),
                const SizedBox(height: 16),
                _field(_awardAmountInterestCost,'Award Amount + Interest and Cost (₹)', numeric: true),
              ])),
              _connector(),
              _section(6, 'Deposit', '2.5 months yellow · 3 months orange · 3.5 months red', locked: !_awardReady, completed: _depositReady, deadline: depositDeadline, status: award == null ? null : _dateStatus(award, deposit, DeadlineService.addMonthsAndDays(award,2,15), orange: DeadlineService.addMonths(award,3), red: DeadlineService.addMonthsAndDays(award,3,15)), child: Column(children: [
                _row(_date(_deposit,'Deposit Date'), _field(_depositAmount,'Deposit Amount (₹)', numeric: true)),
              ])),
              _connector(),
              _section(7, 'Fees Received', 'Due within 7 days of normal deposit', locked: !_depositReady, completed: _feesReady, deadline: deposit?.add(const Duration(days:7)), child: _row(_date(_fees,'Fees Received Date'), _field(_feesAmount,'Fees Amount (₹)', numeric: true))),
              _connector(),
              _section(
                8,
                'EP/RR Filing',
                'Available from 4 months after award when no normal deposit has been made',
                locked: !_awardReady ||
                    deposit != null ||
                    (award != null &&
                        DateTime.now().isBefore(
                          DeadlineService.addMonths(award, 4),
                        )),
                completed: _epReady,
                deadline: epDeadline,
                status: award == null || _epReady || deposit != null
                    ? null
                    : (DateTime.now().isBefore(
                            DeadlineService.addMonths(award, 4),
                          )
                        ? 'Waiting'
                        : 'Overdue'),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _epFilingType,
                      decoration: const InputDecoration(labelText: 'Filing Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'EP',
                          child: Text('EP — Execution Petition'),
                        ),
                        DropdownMenuItem(
                          value: 'RR',
                          child: Text('RR — Revenue Recovery'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _epFilingType = value);
                        _scheduleAutosave();
                      },
                    ),
                    const SizedBox(height: 16),
                    _date(_ep, 'Filing Date'),
                  ],
                ),
              ),
              _connector(),
              _section(9, 'Deposit Against Execution', 'Final deposit after EP filing', locked: !_epReady, completed: _executionReady, child: _row(_date(_execution,'Deposit Against Execution Date'), _field(_executionAmount,'Amount (₹)', numeric: true))),
              const SizedBox(height: 28),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save all changes'))),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    )),
        ]),
      ),
    );
  }

  void _goBack() => context.pop();

  Widget _section(int n, String title, String subtitle, {required Widget child, bool locked = false, bool completed = false, DateTime? deadline, String? status}) {
    final color = completed ? Colors.green : locked ? Colors.blueGrey : Theme.of(context).colorScheme.primary;
    final dueText = deadline == null ? null : _fmt(deadline);
    final shownStatus = completed ? 'Completed' : (status ?? (deadline == null ? null : _genericStatus(deadline)));
    return Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38,height:38,decoration: BoxDecoration(color: color.withValues(alpha:.12),shape: BoxShape.circle),child: Center(child: completed ? const Icon(Icons.check,color:Colors.green) : locked ? const Icon(Icons.lock_outline,size:18) : Text('$n',style:TextStyle(color:color,fontWeight:FontWeight.bold)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ])),
        if (shownStatus != null) _pill(shownStatus),
      ]),
      if (locked) ...[
        const SizedBox(height: 20),
        Container(width: double.infinity,padding: const EdgeInsets.all(16),decoration: BoxDecoration(color: Colors.grey.shade50,borderRadius: BorderRadius.circular(10)),child: const Row(children: [Icon(Icons.lock_outline,size:18,color:Colors.grey),SizedBox(width:10),Expanded(child: Text('Complete the previous step to unlock this section.'))])),
      ] else ...[
        if (dueText != null && !completed) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: .08),
              border: Border.all(
                color: Colors.amber.withValues(alpha: .3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text('Calculated deadline: $dueText')),
              ])),
        ],
        const SizedBox(height: 20),
        child,
      ],
    ])));
  }

  String _genericStatus(DateTime deadline) {
    if (DateTime.now().isAfter(deadline)) return 'Overdue';
    if (deadline.difference(DateTime.now()).inDays <= 30) return 'Due Soon';
    return 'Healthy';
  }

  Widget _pill(String label) {
    final c = switch (label) {
      'Completed' => Colors.green,
      'Overdue' || 'Red' => Colors.red,
      'Orange' => Colors.deepOrange,
      'Yellow' || 'Due Soon' => Colors.orange,
      _ => Colors.blueGrey,
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:c.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(label,style:TextStyle(color:c,fontWeight:FontWeight.w600,fontSize:12)));
  }

  Widget _connector() => Container(margin: const EdgeInsets.only(left:42),height:22,width:2,color:Colors.grey.shade300);

  Widget _row(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child:a),const SizedBox(width:16),Expanded(child:b)]);

  Widget _field(TextEditingController c, String label, {bool requiredField = false, bool numeric = false, int maxLines = 1}) => TextFormField(
    controller:c, maxLines:maxLines, keyboardType:numeric ? (label == 'Phone Number' ? TextInputType.number : const TextInputType.numberWithOptions(decimal:true)) : TextInputType.text,
    validator: (v) {
      if (requiredField && (v == null || v.trim().isEmpty)) return 'Required';
      if (label == 'Phone Number' && v != null && v.trim().isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Enter exactly 10 digits';
      if ((label == 'Case Year' && v != null && v.trim().isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(v.trim()))) return 'Enter a 4-digit year';
      if (label == 'Case Number' && v != null && v.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(v.trim())) return 'Enter digits only';
      if (numeric && v != null && v.trim().isNotEmpty && _money(v) == null) return 'Enter a valid amount';
      return null;
    },
    decoration:InputDecoration(labelText:label),
    onChanged: (_) { setState(() {}); _scheduleAutosave(); },
  );

  Widget _date(
    TextEditingController c,
    String label, {
    bool requiredField = false,
  }) =>
      TextFormField(
        controller: c,
        readOnly: true,
        onTap: () => _pickDate(c),
        validator: requiredField
            ? (v) => _parse(v ?? '') == null
                ? 'Select a valid date'
                : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Select date',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      c.clear();
                    });
                    _scheduleAutosave();
                  },
                ),
              IconButton(
                tooltip: 'Select date',
                icon: const Icon(Icons.calendar_today_outlined, size: 19),
                onPressed: () => _pickDate(c),
              ),
            ],
          ),
        ),
      );
}
