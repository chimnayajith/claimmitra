import 'package:flutter/material.dart';
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
  final _number = TextEditingController();
  final _received = TextEditingController();
  final _accident = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _station = TextEditingController();
  final _responsible = TextEditingController();
  final _police = TextEditingController();
  final _filed = TextEditingController();
  final _evidence = TextEditingController();
  final _award = TextEditingController();
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
    if (!_isNew) {
      _record = await CaseDatabase.instance.getCase(widget.caseId);
      final c = _record;
      if (c != null) {
        _number.text = c.caseNumber ?? '';
        _received.text = _fmt(c.receivedDate);
        _accident.text = _fmt(c.accidentDate);
        _name.text = c.clientName;
        _address.text = c.address;
        _phone.text = c.phone;
        _station.text = c.policeStation;
        _responsible.text = c.responsibleParty;
        _police.text = _fmt(c.policeDocumentsDate);
        _filed.text = _fmt(c.caseFiledDate);
        _evidence.text = _fmt(c.evidenceDate);
        _award.text = _fmt(c.awardDate);
        _deposit.text = _fmt(c.depositDate);
        _depositAmount.text = c.depositAmount?.toString() ?? '';
        _fees.text = _fmt(c.feesReceivedDate);
        _feesAmount.text = c.feesAmount?.toString() ?? '';
        _ep.text = _fmt(c.epFiledDate);
        _execution.text = _fmt(c.executionDepositDate);
        _executionAmount.text = c.executionDepositAmount?.toString() ?? '';
      }
    } else {
      _received.text = _fmt(DateTime.now());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _number,_received,_accident,_name,_address,_phone,_station,_responsible,
      _police,_filed,_evidence,_award,_deposit,_depositAmount,_fees,_feesAmount,_ep,_execution,_executionAmount,
    ]) { c.dispose(); }
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

  Future<void> _pickDate(TextEditingController controller) async {
    final current = _parse(controller.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => controller.text = _fmt(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final received = _parse(_received.text);
    if (received == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a valid Case Received Date.')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final old = _record;
    final record = CaseRecord(
      id: old?.id ?? 'case_${now.microsecondsSinceEpoch}',
      caseNumber: _number.text.trim().isEmpty ? null : _number.text.trim(),
      receivedDate: received,
      accidentDate: _parse(_accident.text),
      clientName: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      policeStation: _station.text.trim(),
      responsibleParty: _responsible.text.trim(),
      policeDocumentsDate: _parse(_police.text),
      caseFiledDate: _parse(_filed.text),
      evidenceDate: _parse(_evidence.text),
      awardDate: _parse(_award.text),
      depositDate: _parse(_deposit.text),
      depositAmount: _money(_depositAmount.text),
      feesReceivedDate: _parse(_fees.text),
      feesAmount: _money(_feesAmount.text),
      epFiledDate: _parse(_ep.text),
      executionDepositDate: _parse(_execution.text),
      executionDepositAmount: _money(_executionAmount.text),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await CaseDatabase.instance.save(record);
      if (!mounted) return;
      setState(() { _record = record; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case saved.')));
      if (_isNew) context.go('/cases/${record.id}');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save case: $e')));
      }
    }
  }

  bool get _detailsReady => _parse(_received.text) != null && _name.text.trim().isNotEmpty;
  bool get _policeReady => _parse(_police.text) != null;
  bool get _filedReady => _parse(_filed.text) != null;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(onPressed: () => context.go('/cases'), icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name.text.isEmpty ? (_isNew ? 'New Case' : 'Case Details') : _name.text, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text(_number.text.isEmpty ? 'No case number assigned' : 'Case No. ${_number.text}', style: Theme.of(context).textTheme.bodyMedium),
                ])),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save Case')),
              ]),
              const SizedBox(height: 28),
              _section(1, 'Case Details', 'Basic information and client contact details', completed: _detailsReady, child: Column(children: [
                _row(_field(_number,'Case Number (optional)'), _date(_received,'Case Received Date', requiredField: true)),
                const SizedBox(height: 16),
                _row(_date(_accident,'Date of Accident'), _field(_name,'Client Name', requiredField: true)),
                const SizedBox(height: 16),
                _field(_address,'Address', maxLines: 2),
                const SizedBox(height: 16),
                _row(_field(_phone,'Phone Number'), _field(_station,'Police Station')),
                const SizedBox(height: 16),
                _field(_responsible,'Responsible Company / Person'),
              ])),
              _connector(),
              _section(2, 'Police Documents', 'Deadline: 3 months yellow · 4 months orange · 5 months red', locked: !_detailsReady, completed: _policeReady, deadline: policeDeadline, status: received == null ? null : _dateStatus(received, _parse(_police.text), DeadlineService.addMonths(received,3), orange: DeadlineService.addMonths(received,4), red: DeadlineService.addMonths(received,5)), child: _date(_police,'Documents Received Date')),
              _connector(),
              _section(3, 'Case Filed', 'Deadline: 4 months yellow · 5 months red', locked: !_policeReady, completed: _filedReady, deadline: filingDeadline, status: received == null ? null : _filingStatus(received, _parse(_filed.text)), child: _date(_filed,'Case Filed Date')),
              _connector(),
              _section(4, 'Evidence', 'Record the evidence date', locked: !_filedReady, completed: _evidenceReady, child: _date(_evidence,'Evidence Date')),
              _connector(),
              _section(5, 'Award / Court Decision', 'Record the court decision date', locked: !_evidenceReady, completed: _awardReady, child: _date(_award,'Award Date')),
              _connector(),
              _section(6, 'Deposit', '2.5 months yellow · 3 months orange · 3.5 months red', locked: !_awardReady, completed: _depositReady, deadline: depositDeadline, status: award == null ? null : _dateStatus(award, deposit, DeadlineService.addMonthsAndDays(award,2,15), orange: DeadlineService.addMonths(award,3), red: DeadlineService.addMonthsAndDays(award,3,15)), child: Column(children: [
                _row(_date(_deposit,'Deposit Date'), _field(_depositAmount,'Deposit Amount (₹)', numeric: true)),
              ])),
              _connector(),
              _section(7, 'Fees Received', 'Due within 7 days of normal deposit', locked: !_depositReady, completed: _feesReady, deadline: deposit == null ? null : deposit.add(const Duration(days:7)), child: _row(_date(_fees,'Fees Received Date'), _field(_feesAmount,'Fees Amount (₹)', numeric: true))),
              _connector(),
              _section(8, 'EP Filing', 'Unlocks 4 months after award if normal deposit has not occurred', locked: !_awardReady || deposit != null || (award != null && DateTime.now().isBefore(DeadlineService.addMonths(award, 4))), completed: _epReady, deadline: epDeadline, child: _date(_ep,'EP Filed Date')),
              _connector(),
              _section(9, 'Deposit Against Execution', 'Final deposit after EP filing', locked: !_epReady, completed: _executionReady, child: _row(_date(_execution,'Deposit Against Execution Date'), _field(_executionAmount,'Amount (₹)', numeric: true))),
              const SizedBox(height: 28),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save all changes'))),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }

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
        if (dueText != null) ...[
          const SizedBox(height: 20),
          Container(width: double.infinity,padding: const EdgeInsets.all(14),decoration: BoxDecoration(color: Colors.amber.withValues(alpha:.08),border: Border.all(color:Colors.amber.withValues(alpha:.3)),borderRadius:BorderRadius.circular(10)),child: Row(children: [const Icon(Icons.schedule,size:18,color:Colors.orange),const SizedBox(width:10),Expanded(child: Text('Calculated deadline: $dueText'))])),
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
    controller:c, maxLines:maxLines, keyboardType:numeric ? const TextInputType.numberWithOptions(decimal:true) : TextInputType.text,
    validator: requiredField ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    decoration:InputDecoration(labelText:label),
    onChanged: (_) => setState(() {}),
  );

  Widget _date(TextEditingController c, String label, {bool requiredField = false}) => TextFormField(
    controller:c, readOnly:true, onTap:() => _pickDate(c),
    validator: requiredField ? (v) => _parse(v ?? '') == null ? 'Select a valid date' : null : null,
    decoration:InputDecoration(labelText:label,hintText:'Select date',suffixIcon:const Icon(Icons.calendar_today_outlined,size:19)),
  );
}
