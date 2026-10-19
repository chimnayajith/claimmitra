import 'package:flutter_test/flutter_test.dart';
import 'package:claimmitra/features/cases/services/deadline_service.dart';

void main() {
  group('DeadlineService', () {
    test('adds calendar months and clamps end-of-month dates', () {
      expect(
        DeadlineService.addMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
    });

    test('police document thresholds are based on case received date', () {
      final received = DateTime(2026, 1, 10);
      final result = DeadlineService.police(
        received,
        now: DateTime(2026, 4, 10),
      );
      expect(result.status, DeadlineStatus.yellow);
      expect(result.deadline, DateTime(2026, 5, 10));
    });

    test('completed stages return completed status', () {
      final received = DateTime(2026, 1, 10);
      final completed = DateTime(2026, 7, 10);
      final result = DeadlineService.police(
        received,
        completed: completed,
        now: DateTime(2026, 12, 10),
      );
      expect(result.status, DeadlineStatus.completed);
      expect(result.deadline, completed);
    });
  });
}
