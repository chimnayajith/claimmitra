class CaseRecord {
  final String id;
  final String? caseNumber;
  final DateTime? receivedDate;
  final DateTime? accidentDate;
  final String clientName;
  final String address;
  final String phone;
  final String policeStation;
  final String responsibleParty;
  final DateTime? policeDocumentsDate;
  final DateTime? caseFiledDate;
  final DateTime? evidenceDate;
  final DateTime? awardDate;
  final String? awardType;
  final double? awardAmount;
  final double? awardAmountInterestCost;
  final DateTime? depositDate;
  final double? depositAmount;
  final DateTime? feesReceivedDate;
  final double? feesAmount;
  final DateTime? epFiledDate;
  final DateTime? executionDepositDate;
  final double? executionDepositAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String courtFiled;
  final String advocates;
  final String? epFilingType;
  final bool isArchived;
  final DateTime? archivedAt;

  const CaseRecord({
    required this.id,
    this.caseNumber,
    required this.receivedDate,
    this.accidentDate,
    required this.clientName,
    this.address = '',
    this.phone = '',
    this.policeStation = '',
    this.responsibleParty = '',
    this.policeDocumentsDate,
    this.caseFiledDate,
    this.evidenceDate,
    this.awardDate,
    this.awardType,
    this.awardAmount,
    this.awardAmountInterestCost,
    this.depositDate,
    this.depositAmount,
    this.feesReceivedDate,
    this.feesAmount,
    this.epFiledDate,
    this.executionDepositDate,
    this.executionDepositAmount,
    required this.createdAt,
    required this.updatedAt,
    this.courtFiled = '',
    this.advocates = '',
    this.epFilingType,
    this.isArchived = false,
    this.archivedAt,
  });

  bool get isClosed => depositDate != null && feesReceivedDate != null ||
      executionDepositDate != null;

  int? get year => receivedDate?.year;

  String? get displayCaseNumber => formatCaseNumber(caseNumber, receivedDate?.year);
  static String? formatCaseNumber(String? value, int? receivedYear) {
    final s = value?.trim();
    if (s == null || s.isEmpty) return null;
    final date = RegExp(r'^\d{1,2}/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (date != null) {
      return '${date.group(1)!.padLeft(2, '0')}/${date.group(2)!}';
    }
    final m = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(s);
    if (m == null) return s;
    final a = m.group(1)!, b = m.group(2)!;
    if (a.length == 4 && b.length == 4) return '$a/$b';
    if (receivedYear != null && a.length == 4 && int.tryParse(a) == receivedYear) return '$b/$a';
    if (receivedYear != null && b.length == 4 && int.tryParse(b) == receivedYear) return '$a/$b';
    // Historic databases used YEAR/NUMBER; preserve that interpretation for
    // unambiguous four-digit year prefixes.
    if (a.length == 4) return '$b/$a';
    return '$a/$b';
  }

  static String normalizeAdvocates(String? value) {
    final names = <String>[];
    final seen = <String>{};
    for (final raw in (value ?? '').split(',')) {
      final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.isNotEmpty && seen.add(name.toLowerCase())) names.add(name);
    }
    return names.join(', ');
  }

  static bool matchesAdvocateQuery(String? advocates, String query) {
    final needle = query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (needle.isEmpty) return false;
    return normalizeAdvocates(advocates).split(',').any((rawName) {
      final name = rawName.trim().toLowerCase();
      if (name == needle) return true;
      // A single-word search can match a complete name word (for example,
      // "Doe" in "John Doe"), but never a substring such as "Ann" in "Anna".
      if (!needle.contains(' ')) {
        return name.split(RegExp(r'\s+')).contains(needle);
      }
      return false;
    });
  }

  Map<String, Object?> toMap() => {
    'id': id, 'case_number': _clean(displayCaseNumber),
    'received_date': _date(receivedDate), 'accident_date': _date(accidentDate),
    'client_name': clientName, 'address': address, 'phone': phone,
    'police_station': policeStation, 'responsible_party': responsibleParty,
    'police_documents_date': _date(policeDocumentsDate),
    'case_filed_date': _date(caseFiledDate), 'evidence_date': _date(evidenceDate),
    'award_date': _date(awardDate), 'award_type': awardType,
    'award_amount': awardAmount, 'award_amount_interest_cost': awardAmountInterestCost,
    'deposit_date': _date(depositDate),
    'deposit_amount': depositAmount, 'fees_received_date': _date(feesReceivedDate),
    'fees_amount': feesAmount, 'ep_filed_date': _date(epFiledDate),
    'execution_deposit_date': _date(executionDepositDate),
    'execution_deposit_amount': executionDepositAmount,
    'court_filed': courtFiled.trim(), 'advocates': normalizeAdvocates(advocates),
    'ep_filing_type': epFilingType ?? (epFiledDate == null ? null : 'EP'),
    'is_archived': isArchived ? 1 : 0, 'archived_at': _date(archivedAt),
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };

  factory CaseRecord.fromMap(Map<String, Object?> m) => CaseRecord(
    id: m['id'] as String,
    receivedDate: _parseDate(m['received_date']),
    caseNumber: formatCaseNumber(m['case_number'] as String?, _parseDate(m['received_date'])?.year),
    accidentDate: _parseDate(m['accident_date']),
    clientName: (m['client_name'] as String?) ?? '',
    address: (m['address'] as String?) ?? '',
    phone: (m['phone'] as String?) ?? '',
    policeStation: (m['police_station'] as String?) ?? '',
    responsibleParty: (m['responsible_party'] as String?) ?? '',
    policeDocumentsDate: _parseDate(m['police_documents_date']),
    caseFiledDate: _parseDate(m['case_filed_date']),
    evidenceDate: _parseDate(m['evidence_date']),
    awardDate: _parseDate(m['award_date']),
    awardType: m['award_type'] as String?,
    awardAmount: _double(m['award_amount']),
    awardAmountInterestCost: _double(m['award_amount_interest_cost']),
    depositDate: _parseDate(m['deposit_date']),
    depositAmount: _double(m['deposit_amount']),
    feesReceivedDate: _parseDate(m['fees_received_date']),
    feesAmount: _double(m['fees_amount']),
    epFiledDate: _parseDate(m['ep_filed_date']),
    executionDepositDate: _parseDate(m['execution_deposit_date']),
    executionDepositAmount: _double(m['execution_deposit_amount']),
    courtFiled: (m['court_filed'] as String?) ?? '',
    advocates: normalizeAdvocates(m['advocates'] as String?),
    epFilingType: (m['ep_filing_type'] as String?) ?? (_parseDate(m['ep_filed_date']) == null ? null : 'EP'),
    isArchived: (m['is_archived'] as int? ?? 0) != 0,
    archivedAt: _parseDate(m['archived_at']),
    createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse((m['updated_at'] as String?) ?? '') ?? DateTime.now(),
  );

  CaseRecord copyWith({
    String? caseNumber, DateTime? receivedDate, DateTime? accidentDate,
    String? clientName, String? address, String? phone, String? policeStation,
    String? responsibleParty, DateTime? policeDocumentsDate, DateTime? caseFiledDate,
    DateTime? evidenceDate, DateTime? awardDate, String? awardType,
    double? awardAmount, double? awardAmountInterestCost, DateTime? depositDate,
    double? depositAmount, DateTime? feesReceivedDate, double? feesAmount,
    DateTime? epFiledDate, DateTime? executionDepositDate,
    double? executionDepositAmount, String? courtFiled, String? advocates, String? epFilingType,
    bool? isArchived, DateTime? archivedAt, bool clearCaseNumber = false,
    bool clearAccidentDate = false, bool clearPoliceDocumentsDate = false,
    bool clearCaseFiledDate = false, bool clearEvidenceDate = false,
    bool clearAwardDate = false, bool clearAwardType = false,
    bool clearAwardAmount = false, bool clearAwardAmountInterestCost = false,
    bool clearDepositDate = false,
    bool clearDepositAmount = false, bool clearFeesReceivedDate = false,
    bool clearFeesAmount = false, bool clearEpFiledDate = false,
    bool clearExecutionDepositDate = false, bool clearExecutionDepositAmount = false,
  }) => CaseRecord(
    id: id, caseNumber: clearCaseNumber ? null : (caseNumber ?? this.caseNumber),
    receivedDate: receivedDate ?? this.receivedDate,
    accidentDate: clearAccidentDate ? null : (accidentDate ?? this.accidentDate),
    clientName: clientName ?? this.clientName, address: address ?? this.address,
    phone: phone ?? this.phone, policeStation: policeStation ?? this.policeStation,
    responsibleParty: responsibleParty ?? this.responsibleParty,
    policeDocumentsDate: clearPoliceDocumentsDate ? null : (policeDocumentsDate ?? this.policeDocumentsDate),
    caseFiledDate: clearCaseFiledDate ? null : (caseFiledDate ?? this.caseFiledDate),
    evidenceDate: clearEvidenceDate ? null : (evidenceDate ?? this.evidenceDate),
    awardDate: clearAwardDate ? null : (awardDate ?? this.awardDate),
    awardType: clearAwardType ? null : (awardType ?? this.awardType),
    awardAmount: clearAwardAmount ? null : (awardAmount ?? this.awardAmount),
    awardAmountInterestCost: clearAwardAmountInterestCost ? null : (awardAmountInterestCost ?? this.awardAmountInterestCost),
    depositDate: clearDepositDate ? null : (depositDate ?? this.depositDate),
    depositAmount: clearDepositAmount ? null : (depositAmount ?? this.depositAmount),
    feesReceivedDate: clearFeesReceivedDate ? null : (feesReceivedDate ?? this.feesReceivedDate),
    feesAmount: clearFeesAmount ? null : (feesAmount ?? this.feesAmount),
    epFiledDate: clearEpFiledDate ? null : (epFiledDate ?? this.epFiledDate),
    executionDepositDate: clearExecutionDepositDate ? null : (executionDepositDate ?? this.executionDepositDate),
    executionDepositAmount: clearExecutionDepositAmount ? null : (executionDepositAmount ?? this.executionDepositAmount),
    courtFiled: courtFiled ?? this.courtFiled, advocates: advocates ?? this.advocates,
    epFilingType: epFilingType ?? this.epFilingType, isArchived: isArchived ?? this.isArchived,
    archivedAt: archivedAt ?? this.archivedAt,
    createdAt: createdAt, updatedAt: DateTime.now(),
  );

  static String? _date(DateTime? d) => d?.toIso8601String().split('T').first;
  static String? _clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
  static DateTime? _parseDate(Object? v) => v == null || v.toString().isEmpty ? null : DateTime.tryParse(v.toString());
  static double? _double(Object? v) => v == null ? null : double.tryParse(v.toString());
}
