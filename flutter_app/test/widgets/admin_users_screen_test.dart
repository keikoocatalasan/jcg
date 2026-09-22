import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';
import 'package:jcg_fitness/features/admin/screens/admin_users_screen.dart';

void main() {
  testWidgets(
      'local demo user management renders without Supabase initialization',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith((ref) async => true),
          adminUsersProvider.overrideWith((ref) async => [
                AdminUserEntry(
                  userId: 'local-demo-admin',
                  authUserId: 'local-demo-admin',
                  email: 'demo.admin@local.jcg',
                  roleId: 2,
                  roleCode: 'admin',
                  roleName: 'Administrator',
                  statusId: 1,
                  statusCode: 'active',
                  statusName: 'Active',
                  nickname: 'Demo Admin',
                  createdAt: DateTime.utc(2026, 1, 1),
                ),
              ]),
          adminRolesProvider.overrideWith((ref) async => const [
                AdminRoleOption(id: 1, code: 'user', name: 'User'),
                AdminRoleOption(id: 2, code: 'admin', name: 'Administrator'),
              ]),
          adminAccountStatusesProvider.overrideWith((ref) async => const [
                AdminAccountStatusOption(
                  id: 1,
                  code: 'active',
                  name: 'Active',
                ),
                AdminAccountStatusOption(
                  id: 2,
                  code: 'disabled',
                  name: 'Disabled',
                ),
              ]),
        ],
        child: const MaterialApp(home: AdminUsersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search users'), findsOneWidget);
    expect(find.text('Demo Admin'), findsOneWidget);
    expect(
        find.text('Your own role and account status cannot be changed here.'),
        findsOneWidget);
  });
}
