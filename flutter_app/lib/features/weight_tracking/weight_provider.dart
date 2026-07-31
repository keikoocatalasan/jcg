import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/weight_log_repository.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

final latestWeightProvider = FutureProvider<WeightLog?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final repo = WeightLogRepository(DatabaseProvider());
  return repo.readLatest(user.id);
});

final weightHistoryProvider = FutureProvider<List<WeightLog>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final repo = WeightLogRepository(DatabaseProvider());
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final startDate =
      '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';
  final endDate =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return repo.queryByUserAndDateRange(user.id, startDate, endDate);
});
