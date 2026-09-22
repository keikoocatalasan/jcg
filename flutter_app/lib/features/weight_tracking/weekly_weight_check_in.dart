import 'package:flutter/material.dart';

/// Returns true when a user has not logged a weight or their last check-in is
/// at least seven days old. Future-dated entries do not trigger a reminder.
bool isWeeklyWeightCheckInDue({
  required DateTime? lastLoggedAt,
  required DateTime now,
}) {
  if (lastLoggedAt == null) return true;

  final elapsed = now.toUtc().difference(lastLoggedAt.toUtc());
  return elapsed >= const Duration(days: 7);
}

class WeeklyWeightCheckInCard extends StatelessWidget {
  const WeeklyWeightCheckInCard({
    required this.lastLoggedAt,
    required this.onLogWeight,
    this.now,
    super.key,
  });

  final DateTime? lastLoggedAt;
  final DateTime? now;
  final VoidCallback onLogWeight;

  @override
  Widget build(BuildContext context) {
    if (!isWeeklyWeightCheckInDue(
      lastLoggedAt: lastLoggedAt,
      now: now ?? DateTime.now(),
    )) {
      return const SizedBox.shrink();
    }

    final isFirstCheckIn = lastLoggedAt == null;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        key: const ValueKey('weekly-weight-check-in'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_weight_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFirstCheckIn
                          ? 'Start your weight check-ins'
                          : 'Weekly weight check-in',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isFirstCheckIn
                    ? 'Log your current weight to start your trend. Your calorie and macro targets will update from your latest weight.'
                    : 'It has been a week since your last weigh-in. Log your current weight to keep your progress and calorie and macro targets up to date.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onLogWeight,
                  icon: const Icon(Icons.add),
                  label: const Text('Log weight'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
