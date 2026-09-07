import 'package:jcg_fitness/core/database/weight_log_repository.dart';

/// Returns the weight that should be considered current after editing one log.
///
/// The date is part of the meaning of a weight entry. An edit can therefore
/// promote an older entry to the latest position or demote the current latest
/// entry. Keeping this decision in a pure helper makes the target recalculation
/// behavior deterministic and easy to test without rendering a screen.
WeightLog selectLatestWeightAfterEdit({
  required List<WeightLog> logs,
  required WeightLog editedLog,
  required double editedWeightKg,
  required String editedLoggedAt,
}) {
  final candidate = WeightLog(
    weightLogId: editedLog.weightLogId,
    userId: editedLog.userId,
    weightKg: editedWeightKg,
    loggedAt: editedLoggedAt,
    syncStatus: editedLog.syncStatus,
    createdAt: editedLog.createdAt,
    updatedAt: editedLog.updatedAt,
  );
  final candidates = [
    for (final log in logs)
      log.weightLogId == editedLog.weightLogId ? candidate : log,
  ];
  if (candidates.isEmpty) return candidate;

  candidates.sort((a, b) {
    final dateComparison = _parseDate(b.loggedAt).compareTo(
      _parseDate(a.loggedAt),
    );
    if (dateComparison != 0) return dateComparison;
    return b.createdAt.compareTo(a.createdAt);
  });
  return candidates.first;
}

DateTime _parseDate(String value) =>
    DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
