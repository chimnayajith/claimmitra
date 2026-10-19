import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../../../database/case_database.dart';
import '../models/case.dart';

class ExcelImportResult {
  final List<CaseRecord> records;
  final int skipped;
  final List<String> errors;
  const ExcelImportResult(this.records, this.skipped, this.errors);
  int get imported => records.length;
}

class ExcelService {
  static const headers = [
    'Case Number', 'Case Received Date', 'Accident Date', 'Client Name',
    'Address', 'Phone', 'Police Station', 'Responsible Company / Person',
    'Police Documents Date', 'Case Filed Date', 'Evidence Date', 'Award Date', 'Award Type', 'Award Amount', 'Award Amount + Interest and Cost',
    'Deposit Date', 'Deposit Amount', 'Fees Received Date', 'Fees Amount',
    'EP Filed Date', 'Deposit Against Execution Date', 'Deposit Against Execution Amount',
  ];

  static Future<String?> exportCases(List<CaseRecord> cases) async {
    final excel = Excel.createExcel();
    final sheet = excel['Cases'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final c in cases) {
      sheet.appendRow([
        TextCellValue(c.caseNumber ?? ''),
        TextCellValue(_format(c.receivedDate)),
        TextCellValue(_format(c.accidentDate)),
        TextCellValue(c.clientName),
        TextCellValue(c.address),
        TextCellValue(c.phone),
        TextCellValue(c.policeStation),
        TextCellValue(c.responsibleParty),
        TextCellValue(_format(c.policeDocumentsDate)),
        TextCellValue(_format(c.caseFiledDate)),
        TextCellValue(_format(c.evidenceDate)),
        TextCellValue(_format(c.awardDate)),
        TextCellValue(c.awardType ?? ''),
        TextCellValue(c.awardAmount?.toString() ?? ''),
        TextCellValue(c.awardAmountInterestCost?.toString() ?? ''),
        TextCellValue(_format(c.depositDate)),
        TextCellValue(c.depositAmount?.toString() ?? ''),
        TextCellValue(_format(c.feesReceivedDate)),
        TextCellValue(c.feesAmount?.toString() ?? ''),
        TextCellValue(_format(c.epFiledDate)),
        TextCellValue(_format(c.executionDepositDate)),
        TextCellValue(c.executionDepositAmount?.toString() ?? ''),
      ]);
    }
    final bytes = excel.save();
    if (bytes == null) return null;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export ClaimMitra cases',
      fileName: 'claimmitra-cases.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (path == null) return null;
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<ExcelImportResult?> importCases() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Excel cases',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final bytes = picked.files.first.bytes ??
        (picked.files.first.path != null ? await File(picked.files.first.path!).readAsBytes() : null);
    if (bytes == null) throw Exception('Could not read the selected Excel file.');

    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw Exception('The workbook has no sheets.');
    }

    final sheetName = workbook.tables.containsKey('Cases')
        ? 'Cases'
        : workbook.tables.keys.first;

    final sheet = workbook.tables[sheetName];

    if (sheet == null) {
      throw Exception('Could not read the first worksheet: $sheetName');
    }
        
    if (sheet.rows.isEmpty) throw Exception('The selected sheet is empty.');

    final header = sheet.rows.first.map((c) => (c?.value?.toString() ?? '').trim().toLowerCase()).toList();
    int col(List<String> names) => header.indexWhere((h) => names.contains(h));
    String val(List<Data?> row, List<String> names) {
      final i = col(names);
      return i < 0 || i >= row.length ? '' : (row[i]?.value?.toString() ?? '').trim();
    }

    final existing = await CaseDatabase.instance.allCases();
    final knownNumbers = existing.map((c) => c.caseNumber?.trim().toLowerCase()).whereType<String>().where((s) => s.isNotEmpty).toSet();
    final records = <CaseRecord>[];
    final errors = <String>[];
    var skipped = 0;
    final now = DateTime.now();

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((c) => (c?.value?.toString() ?? '').trim().isEmpty)) continue;
      try {
        final name = val(row, ['client name', 'name', 'client']);
        final received = _parseDate(val(row, ['case received date', 'received date', 'case received']));
        if (name.isEmpty || received == null) {
          skipped++;
          errors.add('Row ${i + 1}: Client Name and a valid Case Received Date are required.');
          continue;
        }
        final number = val(row, ['case number', 'case no', 'case no.']);
        if (number.isNotEmpty && knownNumbers.contains(number.toLowerCase())) {
          skipped++;
          errors.add('Row ${i + 1}: Case number "$number" already exists; skipped.');
          continue;
        }
        double? amount(String s) {
          if (s.isEmpty) return null;
          return double.tryParse(s.replaceAll(',', '').replaceAll('₹', '').trim());
        }
        records.add(CaseRecord(
          id: 'case_${now.microsecondsSinceEpoch}_${i}_${Random().nextInt(999999)}',
          caseNumber: number.isEmpty ? null : number,
          receivedDate: received,
          accidentDate: _parseDate(val(row, ['accident date', 'date of accident'])),
          clientName: name,
          address: val(row, ['address']),
          phone: val(row, ['phone', 'phone number', 'mobile']),
          policeStation: val(row, ['police station']),
          responsibleParty: val(row, ['responsible company / person', 'responsible party', 'company', 'responsible person']),
          policeDocumentsDate: _parseDate(val(row, ['police documents date', 'documents received date'])),
          caseFiledDate: _parseDate(val(row, ['case filed date', 'filing date'])),
          evidenceDate: _parseDate(val(row, ['evidence date'])),
          awardDate: _parseDate(val(row, ['award date'])),
          awardType: val(row, ['award type']).isEmpty ? null : val(row, ['award type']),
          awardAmount: amount(val(row, ['award amount'])),
          awardAmountInterestCost: amount(val(row, ['award amount + interest and cost', 'award amount interest and cost'])),
          depositDate: _parseDate(val(row, ['deposit date'])),
          depositAmount: amount(val(row, ['deposit amount'])),
          feesReceivedDate: _parseDate(val(row, ['fees received date', 'fees date'])),
          feesAmount: amount(val(row, ['fees amount'])),
          epFiledDate: _parseDate(val(row, ['ep filed date', 'ep filing date'])),
          executionDepositDate: _parseDate(val(row, ['deposit against execution date', 'execution deposit date'])),
          executionDepositAmount: amount(val(row, ['deposit against execution amount', 'execution deposit amount'])),
          createdAt: now, updatedAt: now,
        ));
        if (number.isNotEmpty) knownNumbers.add(number.toLowerCase());
      } catch (e) {
        skipped++;
        errors.add('Row ${i + 1}: $e');
      }
    }
    return ExcelImportResult(records, skipped, errors);
  }

  static Future<void> commitImport(ExcelImportResult result) =>
      CaseDatabase.instance.saveMany(result.records);

  static String _format(DateTime? date) => date == null ? '' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;

    final s = value.trim();

    // Excel stores dates as serial numbers in some workbooks.
    final serial = num.tryParse(s);
    if (serial != null && serial >= 1 && serial < 2958466) {
      final date = DateTime(1899, 12, 30).add(
        Duration(days: serial.floor()),
      );
      return DateTime(date.year, date.month, date.day);
    }

    // ISO date format: YYYY-MM-DD
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }

    // DD/MM/YYYY or YYYY/MM/DD
    final parts = s.split(RegExp(r'[/.-]'));
    if (parts.length != 3) return null;

    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final c = int.tryParse(parts[2]);

    if (a == null || b == null || c == null) return null;

    final year = a > 31 ? a : (c < 100 ? 2000 + c : c);
    final month = b;
    final day = a > 31 ? c : a;

    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }
}
