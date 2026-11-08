import '../models/case.dart';

final RegExp _caseNumberPattern = RegExp(r'^\s*(\d+)\s*/\s*(\d{4})\s*$');

int compareCasesForList(CaseRecord a, CaseRecord b) {
  final aNumber = a.caseNumber?.trim();
  final bNumber = b.caseNumber?.trim();
  final aHasNumber = aNumber?.isNotEmpty ?? false;
  final bHasNumber = bNumber?.isNotEmpty ?? false;
  final aParts = aHasNumber ? _caseNumberPattern.firstMatch(aNumber!) : null;
  final bParts = bHasNumber ? _caseNumberPattern.firstMatch(bNumber!) : null;
  final aYear =
      int.tryParse(aParts?.group(2) ?? '') ?? a.receivedDate?.year ?? 0;
  final bYear =
      int.tryParse(bParts?.group(2) ?? '') ?? b.receivedDate?.year ?? 0;

  if (aYear != bYear) return bYear.compareTo(aYear);
  if (aHasNumber != bHasNumber) return aHasNumber ? -1 : 1;

  if (aHasNumber && bHasNumber) {
    if (aParts != null && bParts != null) {
      final sequenceComparison = int.parse(
        aParts.group(1)!,
      ).compareTo(int.parse(bParts.group(1)!));
      if (sequenceComparison != 0) return sequenceComparison;
    }
    final numberComparison = aNumber!.compareTo(bNumber!);
    if (numberComparison != 0) return numberComparison;
  } else {
    final receivedDateComparison = (b.receivedDate ?? DateTime(1)).compareTo(
      a.receivedDate ?? DateTime(1),
    );
    if (receivedDateComparison != 0) return receivedDateComparison;
  }

  return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
}

int compareCasesByReceivedDate(
  CaseRecord a,
  CaseRecord b, {
  bool descending = false,
}) {
  if (a.receivedDate == null && b.receivedDate == null) {
    return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
  }
  if (a.receivedDate == null) return 1;
  if (b.receivedDate == null) return -1;

  final dateComparison = a.receivedDate!.compareTo(b.receivedDate!);
  if (dateComparison != 0) {
    return descending ? -dateComparison : dateComparison;
  }
  return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
}

int compareCasesForChronologicalList(
  CaseRecord a,
  CaseRecord b, {
  bool descending = false,
}) {
  final aNumber = a.caseNumber?.trim();
  final bNumber = b.caseNumber?.trim();
  final aHasNumber = aNumber?.isNotEmpty ?? false;
  final bHasNumber = bNumber?.isNotEmpty ?? false;
  final aParts = aHasNumber ? _caseNumberPattern.firstMatch(aNumber!) : null;
  final bParts = bHasNumber ? _caseNumberPattern.firstMatch(bNumber!) : null;
  final aYear = int.tryParse(aParts?.group(2) ?? '') ?? a.receivedDate?.year;
  final bYear = int.tryParse(bParts?.group(2) ?? '') ?? b.receivedDate?.year;

  if (aYear == null && bYear != null) return 1;
  if (aYear != null && bYear == null) return -1;
  if (aYear != null && bYear != null && aYear != bYear) {
    final yearComparison = aYear.compareTo(bYear);
    return descending ? -yearComparison : yearComparison;
  }

  if (aHasNumber != bHasNumber) return aHasNumber ? -1 : 1;

  final aDate = a.receivedDate;
  final bDate = b.receivedDate;
  if (aDate == null && bDate != null) return 1;
  if (aDate != null && bDate == null) return -1;
  if (aDate != null && bDate != null) {
    final dateComparison = aDate.compareTo(bDate);
    if (dateComparison != 0) {
      return descending ? -dateComparison : dateComparison;
    }
  }

  return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
}
