class CaseRecord {
  final String id;
  final String? caseNumber;
  final DateTime receivedDate;
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
  final DateTime? depositDate;
  final double? depositAmount;
  final DateTime? feesReceivedDate;
  final double? feesAmount;
  final DateTime? epFiledDate;
  final DateTime? executionDepositDate;
  final double? executionDepositAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.depositDate,
    this.depositAmount,
    this.feesReceivedDate,
    this.feesAmount,
    this.epFiledDate,
    this.executionDepositDate,
    this.executionDepositAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isClosed => depositDate != null && feesReceivedDate != null ||
      executionDepositDate != null;

  int get year => receivedDate.year;

  Map<String, Object?> toMap() => {
    'id': id, 'case_number': _clean(caseNumber),
    'received_date': _date(receivedDate), 'accident_date': _date(accidentDate),
    'client_name': clientName, 'address': address, 'phone': phone,
    'police_station': policeStation, 'responsible_party': responsibleParty,
    'police_documents_date': _date(policeDocumentsDate),
    'case_filed_date': _date(caseFiledDate), 'evidence_date': _date(evidenceDate),
    'award_date': _date(awardDate), 'deposit_date': _date(depositDate),
    'deposit_amount': depositAmount, 'fees_received_date': _date(feesReceivedDate),
    'fees_amount': feesAmount, 'ep_filed_date': _date(epFiledDate),
    'execution_deposit_date': _date(executionDepositDate),
    'execution_deposit_amount': executionDepositAmount,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };

  factory CaseRecord.fromMap(Map<String, Object?> m) => CaseRecord(
    id: m['id'] as String,
    caseNumber: m['case_number'] as String?,
    receivedDate: DateTime.parse(m['received_date'] as String),
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
    depositDate: _parseDate(m['deposit_date']),
    depositAmount: _double(m['deposit_amount']),
    feesReceivedDate: _parseDate(m['fees_received_date']),
    feesAmount: _double(m['fees_amount']),
    epFiledDate: _parseDate(m['ep_filed_date']),
    executionDepositDate: _parseDate(m['execution_deposit_date']),
    executionDepositAmount: _double(m['execution_deposit_amount']),
    createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse((m['updated_at'] as String?) ?? '') ?? DateTime.now(),
  );

  CaseRecord copyWith({
    String? caseNumber, DateTime? receivedDate, DateTime? accidentDate,
    String? clientName, String? address, String? phone, String? policeStation,
    String? responsibleParty, DateTime? policeDocumentsDate, DateTime? caseFiledDate,
    DateTime? evidenceDate, DateTime? awardDate, DateTime? depositDate,
    double? depositAmount, DateTime? feesReceivedDate, double? feesAmount,
    DateTime? epFiledDate, DateTime? executionDepositDate,
    double? executionDepositAmount, bool clearCaseNumber = false,
    bool clearAccidentDate = false, bool clearPoliceDocumentsDate = false,
    bool clearCaseFiledDate = false, bool clearEvidenceDate = false,
    bool clearAwardDate = false, bool clearDepositDate = false,
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
    depositDate: clearDepositDate ? null : (depositDate ?? this.depositDate),
    depositAmount: clearDepositAmount ? null : (depositAmount ?? this.depositAmount),
    feesReceivedDate: clearFeesReceivedDate ? null : (feesReceivedDate ?? this.feesReceivedDate),
    feesAmount: clearFeesAmount ? null : (feesAmount ?? this.feesAmount),
    epFiledDate: clearEpFiledDate ? null : (epFiledDate ?? this.epFiledDate),
    executionDepositDate: clearExecutionDepositDate ? null : (executionDepositDate ?? this.executionDepositDate),
    executionDepositAmount: clearExecutionDepositAmount ? null : (executionDepositAmount ?? this.executionDepositAmount),
    createdAt: createdAt, updatedAt: DateTime.now(),
  );

  static String? _date(DateTime? d) => d?.toIso8601String().split('T').first;
  static String? _clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
  static DateTime? _parseDate(Object? v) => v == null || v.toString().isEmpty ? null : DateTime.tryParse(v.toString());
  static double? _double(Object? v) => v == null ? null : double.tryParse(v.toString());
}
