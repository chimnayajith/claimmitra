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
  /// Keep this list in sync with every field supported by CaseRecord.
  static const headers = <String>[
    'Case Number',
    'Case Received Date',
    'Accident Date',
    'Client Name',
    'Address',
    'Phone Number',
    'Police Station',
    'Responsible Company or Person',
    'Court Filed',
    'Advocates',
    'Police Documents Received Date',
    'Case Filed Date',
    'Evidence Date',
    'Award Date',
    'Award Type',
    'Award Amount',
    'Award Amount + Interest and Cost',
    'Deposit Date',
    'Deposit Amount',
    'Fees Received Date',
    'Fees Amount',
    'EP Filed Date',
    'EP/RR Filing Type',
    'Deposit Against Execution Date',
    'Deposit Against Execution Amount',
  ];

  static String cellText(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final value = cell.value;
    return switch (value) {
      TextCellValue() => value.value.toString().trim(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value.toString(),
      DateCellValue() => _format(value.asDateTimeLocal()),
      DateTimeCellValue() => _format(value.asDateTimeLocal()),
      FormulaCellValue() => value.toString(),
      _ => value.toString().trim(),
    };
  }

  static Future<String?> exportCases(List<CaseRecord> cases) async {
    final excel = Excel.createExcel();
    final sheet = excel['Cases'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final c in cases) {
      sheet.appendRow([
        TextCellValue(c.displayCaseNumber ?? ''),
        TextCellValue(_format(c.receivedDate)),
        TextCellValue(_format(c.accidentDate)),
        TextCellValue(c.clientName),
        TextCellValue(c.address),
        TextCellValue(c.phone),
        TextCellValue(c.policeStation),
        TextCellValue(c.responsibleParty),
        TextCellValue(c.courtFiled),
        TextCellValue(c.advocates),
        TextCellValue(_format(c.policeDocumentsDate)),
        TextCellValue(_format(c.caseFiledDate)),
        TextCellValue(_format(c.evidenceDate)),
        TextCellValue(_format(c.awardDate)),
        TextCellValue(c.awardType ?? ''),
        TextCellValue(_formatAmount(c.awardAmount)),
        TextCellValue(_formatAmount(c.awardAmountInterestCost)),
        TextCellValue(_format(c.depositDate)),
        TextCellValue(_formatAmount(c.depositAmount)),
        TextCellValue(_format(c.feesReceivedDate)),
        TextCellValue(_formatAmount(c.feesAmount)),
        TextCellValue(_format(c.epFiledDate)),
        TextCellValue(c.epFilingType ?? ''),
        TextCellValue(_format(c.executionDepositDate)),
        TextCellValue(_formatAmount(c.executionDepositAmount)),
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

    final selected = picked.files.first;
    final bytes = selected.bytes ??
        (selected.path == null ? null : await File(selected.path!).readAsBytes());
    if (bytes == null) {
      throw Exception('Could not read the selected Excel file.');
    }

    final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (e) {
      throw const FormatException(
        'This Excel file could not be read by the importer. Open it in Excel '
        'or LibreOffice, choose Save As, save it as a new .xlsx file, and '
        'then retry. ClaimMitra exports can be imported directly.',
      );
    }

    if (workbook.tables.isEmpty) {
      throw Exception('The workbook has no worksheets.');
    }

    // Prefer Cases, but do not silently select Instructions if Cases is absent.
    final sheetName = workbook.tables.containsKey('Cases')
        ? 'Cases'
        : workbook.tables.keys.first;
    final sheet = workbook.tables[sheetName];
    if (sheet == null) throw Exception('Could not read worksheet "$sheetName".');
    if (sheet.rows.isEmpty) throw Exception('Worksheet "$sheetName" is empty.');

    String normalize(String value) => value
        .replaceAll('\uFEFF', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Find the header row instead of assuming it is always the first row.
    var headerRowIndex = -1;
    List<String> header = const [];
    for (var r = 0; r < sheet.rows.length; r++) {
      final candidate = sheet.rows[r].map((c) => normalize(cellText(c))).toList();
      final hasName = candidate.any((h) =>
          {'clientname', 'name', 'client'}.contains(h));
        if (hasName) {
        headerRowIndex = r;
        header = candidate;
        break;
      }
    }

    if (headerRowIndex < 0) {
      throw Exception(
        'Could not find the header row in "$sheetName". The sheet must contain '
        'a Client Name column. Case Received Date is only required when a '
        'row has no Case Number. Found sheets: '
        '${workbook.tables.keys.join(', ')}.',
      );
    }

    int col(List<String> names) {
      final normalizedNames = names.map(normalize).toSet();
      return header.indexWhere(normalizedNames.contains);
    }

    String val(List<Data?> row, List<String> names) {
      final index = col(names);
      if (index < 0 || index >= row.length) return '';
      return cellText(row[index]).trim();
    }

    double? amount(String input) {
      var s = input.trim();
      if (s.isEmpty) return null;
      // Supports ₹250,000.00, Rs. 250000, commas and accounting parentheses.
      final negative = s.startsWith('(') && s.endsWith(')');
      s = s.replaceAll(RegExp(r'[₹,\s]'), '');
      s = s.replaceAll(RegExp(r'^(rs\.?|inr)', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
      if (negative && !s.startsWith('-')) s = '-$s';
      return double.tryParse(s);
    }

    final existing = await CaseDatabase.instance.allCases(includeArchived: true);
    final knownNumbers = existing
        .map((c) => CaseDatabase.normalizeCaseNumber(c.displayCaseNumber))
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet();
    final records = <CaseRecord>[];
    final errors = <String>[];
    var skipped = 0;
    final now = DateTime.now();

    for (var i = headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => cellText(cell).isEmpty)) continue;
      final displayRow = i + 1;

      try {
        final name = val(row, ['client name', 'name', 'client']);
        final number = val(row, ['case number', 'case no', 'case no.']).trim();
        final received = _parseDate(
          val(row, ['case received date', 'received date', 'case received']),
        );
        if (name.isEmpty || (number.isEmpty && received == null)) {
          skipped++;
          errors.add(number.isEmpty
              ? 'Row $displayRow: Client Name and a valid Case Received Date are required.'
              : 'Row $displayRow: Client Name is required.');
          continue;
        }

        final effectiveReceived = received ??
            _dateFromCaseNumber(number) ??
            DateTime(now.year, now.month, now.day);
        final normalizedNumber = CaseDatabase.normalizeCaseNumber(
          CaseRecord.formatCaseNumber(number, effectiveReceived.year),
        ) ?? '';
        if (normalizedNumber.isNotEmpty && knownNumbers.contains(normalizedNumber)) {
          skipped++;
          errors.add('Row $displayRow: Case number "$number" already exists; skipped.');
          continue;
        }

        String optional(List<String> aliases) => val(row, aliases).trim();
        final awardType = optional(['award type']);

        records.add(CaseRecord(
          id: 'case_${now.microsecondsSinceEpoch}_${i}_${Random().nextInt(999999)}',
          caseNumber: number.isEmpty ? null : CaseRecord.formatCaseNumber(number, effectiveReceived.year),
          receivedDate: effectiveReceived,
          accidentDate: _parseDate(val(row, ['accident date', 'date of accident'])),
          clientName: name.trim(),
          address: val(row, ['address']),
          phone: val(row, ['phone', 'phone number', 'mobile', 'mobile number']),
          policeStation: val(row, ['police station']),
          responsibleParty: val(row, [
            'responsible company / person',
            'responsible company or person',
            'responsible party',
            'company',
            'responsible person',
          ]),
          courtFiled: optional(['court filed', 'court']),
          advocates: CaseRecord.normalizeAdvocates(optional(['advocates', 'advocate'])),
          policeDocumentsDate: _parseDate(val(row, [
            'police documents date',
            'police documents received date',
            'documents received date',
          ])),
          caseFiledDate: _parseDate(val(row, ['case filed date', 'filing date'])),
          evidenceDate: _parseDate(val(row, ['evidence date'])),
          awardDate: _parseDate(val(row, ['award date'])),
          awardType: awardType.isEmpty ? null : awardType,
          awardAmount: amount(val(row, ['award amount'])),
          awardAmountInterestCost: amount(val(row, [
            'award amount + interest and cost',
            'award amount interest and cost',
            'award amount + interest & cost',
          ])),
          depositDate: _parseDate(val(row, ['deposit date'])),
          depositAmount: amount(val(row, ['deposit amount'])),
          feesReceivedDate: _parseDate(val(row, ['fees received date', 'fees date'])),
          feesAmount: amount(val(row, ['fees amount'])),
          epFiledDate: _parseDate(val(row, ['ep filed date', 'ep filing date'])),
          epFilingType: (() {
            final type = optional(['ep/rr filing type', 'filing type']).toUpperCase();
            if (type.startsWith('RR')) return 'RR';
            if (type.startsWith('EP')) return 'EP';
            return _parseDate(val(row, ['ep filed date', 'ep filing date'])) == null ? null : 'EP';
          })(),
          executionDepositDate: _parseDate(val(row, [
            'deposit against execution date',
            'execution deposit date',
          ])),
          executionDepositAmount: amount(val(row, [
            'deposit against execution amount',
            'execution deposit amount',
          ])),
          createdAt: now,
          updatedAt: now,
        ));

        if (normalizedNumber.isNotEmpty) knownNumbers.add(normalizedNumber);
      } catch (e) {
        skipped++;
        errors.add('Row $displayRow: $e');
      }
    }

    return ExcelImportResult(records, skipped, errors);
  }

  static Future<int> commitImport(ExcelImportResult result) async {
    return CaseDatabase.instance.saveMany(result.records);
  }

  static String _format(DateTime? date) => date == null
      ? ''
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _formatAmount(double? value) => value == null ? '' : value.toString();

  static DateTime? _parseDate(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    // XLSX date cells may be represented as Excel serial numbers.
    final serial = num.tryParse(s);
    if (serial != null && serial >= 1 && serial < 2958466) {
      final date = DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
      return DateTime(date.year, date.month, date.day);
    }

    // ISO dates/datetimes.
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final yearFirst = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(s);
    if (yearFirst != null) {
      return _validatedDate(
        int.parse(yearFirst.group(1)!),
        int.parse(yearFirst.group(2)!),
        int.parse(yearFirst.group(3)!),
      );
    }

    final dayFirst = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(s);
    if (dayFirst != null) {
      return _validatedDate(
        int.parse(dayFirst.group(3)!),
        int.parse(dayFirst.group(2)!),
        int.parse(dayFirst.group(1)!),
      );
    }
    return null;
  }

  static DateTime? _dateFromCaseNumber(String input) {
    final year = RegExp(r'(?<!\d)(\d{4})(?!\d)').firstMatch(input)?.group(1);
    final parsedYear = year == null ? null : int.tryParse(year);
    if (parsedYear == null || parsedYear < 1 || parsedYear > 9999) return null;
    return DateTime(parsedYear, 1, 1);
  }

  static DateTime? _validatedDate(int year, int month, int day) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return DateTime(date.year, date.month, date.day);
  }
}
