import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

/// User-facing nutrition verification state for a food record.
///
/// `verified` foods were reviewed and accepted by an admin-approved
/// Nutritionist-Dietitian; every other state is shown explicitly so users can
/// tell that the data has not been professionally verified.
class NutritionVerificationBadge extends StatelessWidget {
  final String status;
  final bool verbose;

  const NutritionVerificationBadge({
    super.key,
    required this.status,
    this.verbose = false,
  });

  @override
  Widget build(BuildContext context) {
    final (:label, :color, :icon) = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.02,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ({String label, Color color, IconData icon}) get _style {
    switch (status) {
      case 'verified':
        return (
          label: verbose ? 'Nutrition data verified' : 'Verified',
          color: AppColors.success,
          icon: Icons.verified_rounded,
        );
      case 'needs_revision':
        return (
          label: 'Needs revision',
          color: AppColors.warning,
          icon: Icons.edit_note_rounded,
        );
      case 'rejected':
        return (
          label: 'Rejected',
          color: AppColors.error,
          icon: Icons.cancel_outlined,
        );
      case 'in_review':
        return (
          label: 'In review',
          color: AppColors.primary,
          icon: Icons.hourglass_top_rounded,
        );
      case 'archived':
        return (
          label: 'Archived',
          color: AppColors.textSecondary,
          icon: Icons.archive_outlined,
        );
      default:
        return (
          label: verbose ? 'Not yet verified by a nutritionist' : 'Unverified',
          color: AppColors.textSecondary,
          icon: Icons.help_outline_rounded,
        );
    }
  }
}
