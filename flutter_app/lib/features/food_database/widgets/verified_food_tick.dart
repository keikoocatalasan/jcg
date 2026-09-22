import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/food_database/food_provider.dart';

/// Small verified marker for dense lists (meal logs, planner, scanner), shown
/// only when the linked catalog food is verified by a nutritionist.
class VerifiedFoodTick extends ConsumerWidget {
  final String? foodId;

  const VerifiedFoodTick({super.key, required this.foodId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = foodId;
    if (id == null) return const SizedBox.shrink();
    final verifiedIds = ref.watch(verifiedFoodIdsProvider).valueOrNull;
    if (verifiedIds == null || !verifiedIds.contains(id)) {
      return const SizedBox.shrink();
    }
    return const Tooltip(
      message: 'Nutrition data verified by an admin-approved nutritionist',
      child: Padding(
        padding: EdgeInsets.only(left: 4),
        child: Icon(
          Icons.verified_rounded,
          size: 15,
          color: AppColors.success,
        ),
      ),
    );
  }
}
