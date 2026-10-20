import 'package:claimmitra/features/cases/list/case_sort.dart';
import 'package:claimmitra/features/cases/models/case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sorts numbered cases by numeric sequence before unnumbered cases', () {
    final cases = [
      _case('missing-new', null, DateTime(2026, 9, 1)),
      _case('number-10', '2026/010', DateTime(2026, 1, 1)),
      _case('number-2', '2026/002', DateTime(2026, 2, 1)),
      _case('missing-old', null, DateTime(2026, 3, 1)),
      _case('number-1', '2026/001', DateTime(2026, 4, 1)),
      _case('older-year', '2025/999', DateTime(2025, 12, 1)),
    ]..sort(compareCasesForList);

    expect(cases.map((c) => c.id).toList(), [
      'number-1',
      'number-2',
      'number-10',
      'missing-new',
      'missing-old',
      'older-year',
    ]);
  });
}

CaseRecord _case(String id, String? caseNumber, DateTime receivedDate) {
  return CaseRecord(
    id: id,
    caseNumber: caseNumber,
    receivedDate: receivedDate,
    clientName: id,
    createdAt: receivedDate,
    updatedAt: receivedDate,
  );
}