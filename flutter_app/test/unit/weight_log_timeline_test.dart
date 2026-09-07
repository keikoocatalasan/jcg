import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/features/weight_tracking/weight_log_timeline.dart';

WeightLog _log(
  String id,
  double weight,
  String loggedAt, {
  String? createdAt,
}) {
  return WeightLog(
    weightLogId: id,
    userId: 'user-1',
    weightKg: weight,
    loggedAt: loggedAt,
    createdAt: createdAt ?? loggedAt,
    updatedAt: loggedAt,
  );
}

void main() {
  final earlier = _log('earlier', 60, '2026-09-01T08:00:00Z');
  final latest = _log('latest', 59, '2026-09-03T08:00:00Z');

  test('moving the current latest entry backward selects the next entry', () {
    final result = selectLatestWeightAfterEdit(
      logs: [earlier, latest],
      editedLog: latest,
      editedWeightKg: 58,
      editedLoggedAt: '2026-08-30T08:00:00Z',
    );

    expect(result.weightLogId, 'earlier');
    expect(result.weightKg, 60);
  });

  test('moving an older entry forward promotes it to current', () {
    final result = selectLatestWeightAfterEdit(
      logs: [earlier, latest],
      editedLog: earlier,
      editedWeightKg: 61,
      editedLoggedAt: '2026-09-04T08:00:00Z',
    );

    expect(result.weightLogId, 'earlier');
    expect(result.weightKg, 61);
  });

  test('same timestamps use creation time for a stable ordering', () {
    final olderCreation = _log(
      'older-creation',
      62,
      '2026-09-04T08:00:00Z',
      createdAt: '2026-09-04T08:01:00Z',
    );
    final newerCreation = _log(
      'newer-creation',
      61,
      '2026-09-04T08:00:00Z',
      createdAt: '2026-09-04T08:02:00Z',
    );

    final result = selectLatestWeightAfterEdit(
      logs: [olderCreation, newerCreation],
      editedLog: olderCreation,
      editedWeightKg: 63,
      editedLoggedAt: '2026-09-04T08:00:00Z',
    );

    expect(result.weightLogId, 'newer-creation');
  });
}
