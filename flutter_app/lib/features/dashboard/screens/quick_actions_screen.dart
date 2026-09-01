import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';

class QuickActionsScreen extends ConsumerWidget {
  const QuickActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Quick Actions'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Shortcuts to log, track, and plan your day.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const _SectionHeader(title: 'Log Your Day'),
          _LogYourDaySection(),
          const _SectionHeader(title: 'Plan Ahead'),
          _PlanAheadSection(),
          const _SectionHeader(title: 'Explore'),
          _ExploreSection(),
          const _SectionHeader(title: 'More'),
          _MoreSection(),
          if (!isOnline) _OfflineBanner(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _LogYourDaySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _ActionCard(
          icon: Icons.restaurant,
          title: 'Log Meal',
          subtitle: 'Add a meal to your log',
          onTap: () => context.push('/add-meal-log'),
        ),
        _ActionCard(
          icon: Icons.water_drop,
          title: 'Log Water',
          subtitle: 'Track your water intake',
          onTap: () => context.push('/hydration'),
        ),
        _ActionCard(
          icon: Icons.monitor_weight,
          title: 'Log Weight',
          subtitle: 'Record your weight',
          onTap: () => context.push('/weight'),
        ),
        _ActionCard(
          icon: Icons.camera_alt,
          title: 'Scan Food',
          subtitle: 'Use AI to scan food',
          onTap: () => context.push('/ai-scanner'),
        ),
      ],
    );
  }
}

class _PlanAheadSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _ActionCard(
          icon: Icons.calendar_month,
          title: 'Meal Planner',
          subtitle: 'Plan meals for the week',
          onTap: () => context.push('/planner'),
        ),
        _ActionCard(
          icon: Icons.lightbulb_outline,
          title: 'Recommendations',
          subtitle: 'Get personalized ideas',
          onTap: () => context.go('/recommendations'),
        ),
        _ActionCard(
          icon: Icons.checklist,
          title: 'Planned Meals',
          subtitle: 'View weekly plans',
          onTap: () => context.push('/planner'),
        ),
      ],
    );
  }
}

class _ExploreSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _ActionCard(
          icon: Icons.search,
          title: 'Search Foods',
          subtitle: 'Find foods in database',
          onTap: () => context.push('/food-search'),
        ),
        _ActionCard(
          icon: Icons.chat_bubble_outline,
          title: 'AI Chatbot',
          subtitle: 'Ask nutrition questions',
          onTap: () => context.push('/chatbot'),
        ),
        _ActionCard(
          icon: Icons.bar_chart,
          title: 'Analytics',
          subtitle: 'View your progress',
          onTap: () => context.push('/analytics'),
        ),
        _ActionCard(
          icon: Icons.add_box_outlined,
          title: 'Create Food',
          subtitle: 'Add custom food items',
          onTap: () => context.push('/custom-food'),
        ),
      ],
    );
  }
}

class _MoreSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _ActionCard(
          icon: Icons.forum_outlined,
          title: 'Community',
          subtitle: 'Connect with others',
          onTap: () => context.go('/community'),
        ),
        _ActionCard(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Manage preferences',
          onTap: () => context.push('/settings'),
        ),
        _ActionCard(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'View and edit profile',
          onTap: () => context.go('/profile'),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(icon, color: AppColors.textPrimary, size: 18),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're offline",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All logs are saved locally and will sync when you\'re back online.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: OutlinedButton(
              onPressed: () => context.push('/sync-status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 0),
              ),
              child: const Text('Sync Status'),
            ),
          ),
        ],
      ),
    );
  }
}
