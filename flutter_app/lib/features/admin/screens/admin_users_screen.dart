import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/widgets/empty_state_widget.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final rolesAsync = ref.watch(adminRolesProvider);
    final statusesAsync = ref.watch(adminAccountStatusesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: GlassBackground(
        child: usersAsync.when(
          data: (users) => rolesAsync.when(
            data: (roles) => statusesAsync.when(
              data: (statuses) {
                if (users.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.people_outline,
                    title: 'No Users Found',
                    subtitle: 'Registered users will appear here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final refresh = ref.refresh(adminUsersProvider.future);
                    await refresh;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _UserCard(
                      entry: users[index],
                      roles: roles,
                      statuses: statuses,
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _LoadError(
                message: 'Failed to load account statuses: $error',
                onRetry: () => ref.invalidate(adminAccountStatusesProvider),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _LoadError(
              message: 'Failed to load available roles: $error',
              onRetry: () => ref.invalidate(adminRolesProvider),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadError(
            message: 'Failed to load users: $error',
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerStatefulWidget {
  final AdminUserEntry entry;
  final List<AdminRoleOption> roles;
  final List<AdminAccountStatusOption> statuses;

  const _UserCard({
    required this.entry,
    required this.roles,
    required this.statuses,
  });

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  bool _saving = false;

  Future<void> _changeAccountStatus(int? statusId) async {
    if (statusId == null || statusId == widget.entry.statusId || _saving) {
      return;
    }

    final supabase = ref.read(supabaseClientProvider);
    if (supabase.auth.currentUser?.id == widget.entry.authUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Administrators cannot change their own account status.'),
        ),
      );
      return;
    }

    final status = widget.statuses.firstWhere(
      (option) => option.id == statusId,
      orElse: () => const AdminAccountStatusOption(
        id: -1,
        code: '',
        name: 'Unknown',
      ),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change account status?'),
        content: Text(
          'Change ${widget.entry.nickname ?? 'this user'} to ${status.name}? '
          'A disabled account cannot sign in. This action will be recorded '
          'in the admin audit log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change status'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await supabase.rpc(
        'admin_set_account_status',
        params: {
          'p_target_user_id': widget.entry.userId,
          'p_new_account_status_id': statusId,
        },
      );
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAuditLogProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account status changed to ${status.name}.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account status change failed: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeRole(int? roleId) async {
    if (roleId == null || roleId == widget.entry.roleId || _saving) return;

    final supabase = ref.read(supabaseClientProvider);
    if (supabase.auth.currentUser?.id == widget.entry.authUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Administrators cannot change their own role.'),
        ),
      );
      return;
    }

    final role = widget.roles.firstWhere(
      (option) => option.id == roleId,
      orElse: () => const AdminRoleOption(id: -1, code: '', name: 'Unknown'),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change user role?'),
        content: Text(
          'Change ${widget.entry.nickname ?? 'this user'} to ${role.name}? '
          'This action will be recorded in the admin audit log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change role'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(supabaseClientProvider).rpc(
        'admin_set_user_role',
        params: {
          'p_target_user_id': widget.entry.userId,
          'p_new_role_id': roleId,
        },
      );
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAuditLogProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role changed to ${role.name}.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role change failed: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat.yMMMd().add_jm().format(widget.entry.createdAt.toLocal());
    final currentRoleExists =
        widget.roles.any((role) => role.id == widget.entry.roleId);
    final currentStatusExists =
        widget.statuses.any((status) => status.id == widget.entry.statusId);
    final isCurrentUser =
        ref.read(supabaseClientProvider).auth.currentUser?.id ==
            widget.entry.authUserId;

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.nickname ?? 'Unnamed user',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.entry.email ?? 'Email unavailable',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'User ID: ${widget.entry.userId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Auth ID: ${widget.entry.authUserId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Created: $date',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(widget.entry.statusName),
                  avatar: Icon(
                    widget.entry.statusCode == 'active'
                        ? Icons.check_circle_outline
                        : Icons.block_outlined,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: currentRoleExists ? widget.entry.roleId : null,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: widget.roles
                  .map(
                    (role) => DropdownMenuItem<int>(
                      value: role.id,
                      child: Text(role.name),
                    ),
                  )
                  .toList(),
              onChanged: _saving || isCurrentUser ? null : _changeRole,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: currentStatusExists ? widget.entry.statusId : null,
              decoration: const InputDecoration(
                labelText: 'Account status',
                border: OutlineInputBorder(),
              ),
              items: widget.statuses
                  .map(
                    (status) => DropdownMenuItem<int>(
                      value: status.id,
                      child: Text(status.name),
                    ),
                  )
                  .toList(),
              onChanged: _saving || isCurrentUser ? null : _changeAccountStatus,
            ),
            if (isCurrentUser)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Your own role and account status cannot be changed here.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
