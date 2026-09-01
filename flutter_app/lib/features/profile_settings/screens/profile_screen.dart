import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/auth/screens/logout_dialog.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load account: $e')),
        data: (isAdmin) {
          if (isAdmin) {
            return _AdminProfileView(
              email: ref.watch(authSessionProvider)?.user.email,
            );
          }

          final profileAsync = ref.watch(profileProvider);
          return profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Profile not found'));
              }

              final displayName = profile.nickname ?? 'User';
              final initial =
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 12),
                  _ProfileInfoCard(
                    displayName: displayName,
                    handle: profile.fitnessGoalCode ?? '',
                    initial: initial,
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.08,
                      ),
                    ),
                  ),
                  _GroupedMenuCard(
                    items: [
                      _MenuData(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () => context.push('/settings'),
                      ),
                      if (isAdmin)
                        _MenuData(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Admin Console',
                          onTap: () => context.push('/admin'),
                        ),
                      _MenuData(
                        icon: Icons.logout,
                        label: 'Logout',
                        onTap: () => LogoutDialog.show(context),
                        iconColor: AppColors.textPrimary,
                        textColor: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminProfileView extends StatelessWidget {
  final String? email;

  const _AdminProfileView({this.email});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.textPrimary,
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 40,
                  color: AppColors.surface,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Administrator',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email ?? 'Admin account',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _GroupedMenuCard(
          items: [
            _MenuData(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin Console',
              onTap: () => context.go('/admin'),
            ),
            _MenuData(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () => LogoutDialog.show(context),
              iconColor: AppColors.textPrimary,
              textColor: AppColors.textPrimary,
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final String displayName;
  final String handle;
  final String initial;

  const _ProfileInfoCard({
    required this.displayName,
    required this.handle,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.textPrimary,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.surface,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            displayName,
            key: const Key('profile_display_name'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            handle,
            key: const Key('profile_handle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/edit-profile'),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _MenuData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });
}

class _GroupedMenuCard extends StatelessWidget {
  final List<_MenuData> items;

  const _GroupedMenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return Column(
            children: [
              ListTile(
                leading: Icon(item.icon,
                    color: item.iconColor ?? AppColors.textSecondary, size: 20),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: item.textColor ?? AppColors.textPrimary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 18),
                onTap: item.onTap,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              if (!isLast) const Divider(height: 1, indent: 52, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }
}
