import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';

final latestWeightProvider = FutureProvider<WeightLog?>((ref) async {
  final userId = await ref.watch(localUserIdProvider.future);
  if (userId == null) return null;
  final repo = WeightLogRepository(DatabaseProvider());
  return repo.readLatest(userId);
});

final weightHistoryProvider = FutureProvider<List<WeightLog>>((ref) async {
  final userId = await ref.watch(localUserIdProvider.future);
  if (userId == null) return [];
  final repo = WeightLogRepository(DatabaseProvider());
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final startDate =
      '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';
  final endDate =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return repo.queryByUserAndDateRange(userId, startDate, endDate);
});
