import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/empty_state_widget.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminAsync = ref.watch(isAdminProvider);
    final kpisAsync = ref.watch(dashboardKpisProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: GlassBackground(
        child: adminAsync.when(
          data: (isAdmin) {
            if (!isAdmin) {
              return const EmptyStateWidget(
                icon: Icons.lock,
                title: 'Access Denied',
                subtitle: 'You do not have admin privileges.',
              );
            }
            return _buildDashboard(context, ref, kpisAsync);
          },
          error: (_, __) =>
              const Center(child: Text('Failed to verify access')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref,
      AsyncValue<DashboardKpis> kpisAsync) {
    return kpisAsync.when(
      data: (kpis) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        'Live data',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildKpiGrid(context, kpis),
            const SizedBox(height: 24),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(context),
          ],
        ),
      ),
      error: (_, __) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Live dashboard metrics are unavailable. Admin tools remain accessible.',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retry',
                      onPressed: () => ref.invalidate(dashboardKpisProvider),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(context),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildKpiGrid(BuildContext context, DashboardKpis kpis) {
    final entries = [
      _KpiData(Formatters.formatCount(kpis.totalUsers), 'Total Users',
          'All time', true),
      _KpiData(Formatters.formatCount(kpis.activeUsers), 'Active Users',
          'Last 30 days', true),
      _KpiData(Formatters.formatCount(kpis.totalMealLogs), 'Total Logs',
          'All time', true),
      _KpiData(Formatters.formatCount(kpis.totalAiScans), 'AI Scans',
          'All time', true),
      _KpiData('${kpis.reportCount}', 'Reports', 'All time', false),
      _KpiData('${kpis.pendingPostReports}', 'Pending Reports',
          'Awaiting action', false),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildKpiCard(context, entries[index]);
      },
    );
  }

  Widget _buildKpiCard(BuildContext context, _KpiData kpi) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              kpi.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              kpi.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            kpi.isPositive
                ? StatusTag.ok(label: kpi.change)
                : StatusTag.neutral(label: kpi.change),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.restaurant,
            label: 'Food\nManagement',
            onTap: () => context.push('/admin/foods'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.flag,
            label: 'Reports',
            onTap: () => context.push('/admin/reports'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.bar_chart,
            label: 'Statistics',
            onTap: () => context.push('/admin/analytics'),
          ),
        ),
      ],
    );
  }
}

class _KpiData {
  final String value;
  final String label;
  final String change;
  final bool isPositive;

  const _KpiData(this.value, this.label, this.change, this.isPositive);
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
