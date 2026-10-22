import 'package:claimmitra/features/cases/models/case.dart';
import 'package:claimmitra/database/case_database.dart';
import 'package:claimmitra/licensing/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats legacy YEAR/NUMBER records without changing their identity', () {
    final record = CaseRecord.fromMap({
      'id': 'same-case',
      'case_number': '2024/123',
      'received_date': '2024-06-01',
      'client_name': 'Client',
      'created_at': '2024-06-01T00:00:00.000',
      'updated_at': '2024-06-01T00:00:00.000',
    });
    expect(record.id, 'same-case');
    expect(record.displayCaseNumber, '123/2024');
    expect(record.toMap()['case_number'], '123/2024');
  });

  test('accepts either case-number order when formatting', () {
    expect(CaseRecord.formatCaseNumber('2024 / 123', 2024), '123/2024');
    expect(CaseRecord.formatCaseNumber('123/2024', 2024), '123/2024');
  });

  test('duplicate normalization treats legacy and canonical numbers equally', () {
    expect(CaseDatabase.normalizeCaseNumber(' 2024 / 123 '),
        CaseDatabase.normalizeCaseNumber('123/2024'));
  });

  test('new fields round trip and old EP records default to EP', () {
    final now = DateTime(2024, 1, 1);
    final record = CaseRecord(
      id: 'fields', receivedDate: now, clientName: 'Client',
      courtFiled: 'District Court', advocates: 'John Doe, Jane Smith',
      epFiledDate: now, epFilingType: 'RR', createdAt: now, updatedAt: now,
    );
    final loaded = CaseRecord.fromMap(record.toMap());
    expect(loaded.courtFiled, 'District Court');
    expect(loaded.advocates, 'John Doe, Jane Smith');
    expect(loaded.epFilingType, 'RR');

    final old = Map<String, Object?>.of(record.toMap())..remove('ep_filing_type');
    expect(CaseRecord.fromMap(old).epFilingType, 'EP');
  });

  test('archive state survives record serialization', () {
    final now = DateTime(2024, 1, 1);
    final record = CaseRecord(
      id: 'archived', receivedDate: now, clientName: 'Client',
      isArchived: true, archivedAt: now, createdAt: now, updatedAt: now,
    );
    final loaded = CaseRecord.fromMap(record.toMap());
    expect(loaded.id, 'archived');
    expect(loaded.isArchived, isTrue);
    expect(loaded.archivedAt, now);
  });

  test('normalizes advocate lists and matches whole names case insensitively', () {
    expect(CaseRecord.normalizeAdvocates(' John Doe, , Jane Smith, john doe '),
        'John Doe, Jane Smith');
    expect(CaseRecord.matchesAdvocateQuery('John Doe, Jane Smith', '  JOHN   DOE '),
        isTrue);
    expect(CaseRecord.matchesAdvocateQuery('John Doe, Jane Smith', 'doe'), isTrue);
    expect(CaseRecord.matchesAdvocateQuery('John Doe, Jane Smith', 'ann'), isFalse);
    expect(CaseRecord.matchesAdvocateQuery('John Doe Thomas', 'John Doe'), isFalse);
  });

  test('update checker compares dotted versions numerically', () {
    expect(UpdateService.isNewerVersion('1.0.5', '1.0.4'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.4', '1.0.5'), isFalse);
    expect(UpdateService.isNewerVersion('1.0.5', '1.0.5'), isFalse);
  });
}
