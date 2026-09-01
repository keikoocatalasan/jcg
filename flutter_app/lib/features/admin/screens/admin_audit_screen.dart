import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/widgets/empty_state_widget.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';
import 'package:intl/intl.dart';

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(adminAuditLogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: GlassBackground(
        child: auditAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.fact_check_outlined,
                title: 'No Audit Entries',
                subtitle: 'Administrative actions will appear here.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(adminAuditLogProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => _AuditCard(entry: entries[index]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text('Failed to load audit logs'),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(adminAuditLogProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AdminAuditEntry entry;

  const _AuditCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isRoleChange = entry.auditType == 'Role Change';
    final date = DateFormat.yMMMd().add_jm().format(entry.createdAt.toLocal());
    return GlassCard(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceAlt,
          child: Icon(
            isRoleChange ? Icons.manage_accounts : Icons.gavel_outlined,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text(
          entry.action.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.auditType} · $date'),
              const SizedBox(height: 4),
              Text('Actor: ${entry.actorId}'),
              if (entry.targetId != null) Text('Target: ${entry.targetId}'),
              if (entry.reportId != null) Text('Report: ${entry.reportId}'),
              if (entry.postId != null) Text('Post: ${entry.postId}'),
              if (entry.details != null) ...[
                const SizedBox(height: 4),
                Text(entry.details!),
              ],
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
