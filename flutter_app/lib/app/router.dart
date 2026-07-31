import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/widgets/offline_banner.dart';
import 'package:jcg_fitness/features/admin/screens/admin_screen.dart';
import 'package:jcg_fitness/features/admin/screens/admin_food_form_screen.dart';
import 'package:jcg_fitness/features/admin/screens/food_management_screen.dart';
import 'package:jcg_fitness/features/admin/screens/moderation_detail_screen.dart';
import 'package:jcg_fitness/features/admin/screens/price_history_screen.dart';
import 'package:jcg_fitness/features/admin/screens/reports_screen.dart';
import 'package:jcg_fitness/features/admin/screens/admin_analytics_screen.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/ai_scanner_screen.dart';
import 'package:jcg_fitness/features/analytics/screens/analytics_screen.dart';
import 'package:jcg_fitness/features/auth/screens/forgot_password_screen.dart';
import 'package:jcg_fitness/features/auth/screens/login_screen.dart';
import 'package:jcg_fitness/features/auth/screens/privacy_screen.dart';
import 'package:jcg_fitness/features/auth/screens/register_screen.dart';
import 'package:jcg_fitness/features/auth/screens/session_loading_screen.dart';
import 'package:jcg_fitness/features/auth/screens/terms_screen.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/auth/session_loading_provider.dart';
import 'package:jcg_fitness/features/chatbot/screens/chatbot_screen.dart';
import 'package:jcg_fitness/features/community/screens/community_screen.dart';
import 'package:jcg_fitness/features/community/screens/create_post_screen.dart';
import 'package:jcg_fitness/features/community/screens/post_detail_screen.dart';
import 'package:jcg_fitness/features/dashboard/screens/dashboard_screen.dart';
import 'package:jcg_fitness/features/dashboard/screens/quick_actions_screen.dart';
import 'package:jcg_fitness/features/food_database/screens/custom_food_screen.dart';
import 'package:jcg_fitness/features/food_database/screens/food_search_screen.dart';
import 'package:jcg_fitness/features/hydration/screens/hydration_screen.dart';
import 'package:jcg_fitness/features/hydration/screens/hydration_history_screen.dart';
import 'package:jcg_fitness/features/meal_logging/screens/meal_log_screen.dart';
import 'package:jcg_fitness/features/meal_logging/screens/edit_meal_log_screen.dart';
import 'package:jcg_fitness/features/meal_logging/screens/delete_meal_log_screen.dart';
import 'package:jcg_fitness/features/meal_logging/screens/recent_logs_screen.dart';
import 'package:jcg_fitness/features/meal_planner/screens/add_planned_meal_screen.dart';
import 'package:jcg_fitness/features/meal_planner/screens/day_summary_screen.dart';
import 'package:jcg_fitness/features/meal_planner/screens/planner_screen.dart';
import 'package:jcg_fitness/features/onboarding/screens/onboarding_allergies_screen.dart';
import 'package:jcg_fitness/features/onboarding/screens/onboarding_budget_screen.dart';
import 'package:jcg_fitness/features/onboarding/screens/onboarding_disclaimer_screen.dart';
import 'package:jcg_fitness/features/onboarding/screens/onboarding_goal_screen.dart';
import 'package:jcg_fitness/features/onboarding/screens/onboarding_nickname_screen.dart';
import 'package:jcg_fitness/features/onboarding/screens/onboarding_review_screen.dart';
import 'package:jcg_fitness/features/onboarding/screens/onboarding_stats_screen.dart';
import 'package:jcg_fitness/features/profile_settings/screens/edit_profile_screen.dart';
import 'package:jcg_fitness/features/profile_settings/screens/profile_screen.dart';
import 'package:jcg_fitness/features/profile_settings/screens/settings_screen.dart';
import 'package:jcg_fitness/features/profile_settings/screens/sync_status_screen.dart';
import 'package:jcg_fitness/features/recommendations/screens/recommendation_detail_screen.dart';
import 'package:jcg_fitness/features/recommendations/screens/recommendations_screen.dart';
import 'package:jcg_fitness/features/weight_tracking/screens/weight_screen.dart';
import 'package:jcg_fitness/features/weight_tracking/screens/weight_history_screen.dart';
import 'package:jcg_fitness/features/nutrition/screens/nutrition_target_screen.dart';
import 'package:jcg_fitness/features/onboarding/onboarding_completion_provider.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();
  ref.watch(authStateProvider);
  final sessionChecked = ref.watch(launchSessionCheckedProvider);
  final onboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/session-loading',
    overridePlatformDefaultLocation: true,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final session = Supabase.instance.client.auth.currentSession;
      const publicRoutes = {
        '/login',
        '/register',
        '/forgot-password',
        '/terms',
        '/privacy',
      };
      final isPublic = publicRoutes.contains(location);
      final isOnboarding = location.startsWith('/onboarding');

      if (!sessionChecked) {
        return location == '/session-loading' ? null : '/session-loading';
      }
      if (session == null) {
        return isPublic ? null : '/login';
      }
      if (location == '/session-loading') return null;
      if (isPublic) return '/session-loading';
      if (!onboardingComplete && !isOnboarding) return '/onboarding';
      if (onboardingComplete && isOnboarding) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/session-loading',
        builder: (_, __) => const SessionLoadingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, __) => const TermsScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, __) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingNicknameScreen(),
        routes: [
          GoRoute(
            path: 'goal',
            builder: (_, __) => const OnboardingGoalScreen(),
          ),
          GoRoute(
            path: 'disclaimer',
            builder: (_, __) => const OnboardingDisclaimerScreen(),
          ),
          GoRoute(
            path: 'allergies',
            builder: (_, __) => const OnboardingAllergiesScreen(),
          ),
          GoRoute(
            path: 'stats',
            builder: (_, __) => const OnboardingStatsScreen(),
          ),
          GoRoute(
            path: 'budget',
            builder: (_, __) => const OnboardingBudgetScreen(),
          ),
          GoRoute(
            path: 'review',
            builder: (_, __) => const OnboardingReviewScreen(),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (_, __, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/meal-log',
            builder: (_, __) => const RecentLogsScreen(),
          ),
          GoRoute(
            path: '/chatbot',
            builder: (_, __) => const ChatbotScreen(),
          ),
          GoRoute(
            path: '/recommendations',
            builder: (_, __) => const RecommendationsScreen(),
          ),
          GoRoute(
            path: '/community',
            builder: (_, __) => const CommunityScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/planner',
            builder: (_, __) => const PlannerScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/add-meal-log',
        builder: (_, __) => const MealLogScreen(),
      ),
      GoRoute(
        path: '/quick-actions',
        builder: (_, __) => const QuickActionsScreen(),
      ),
      GoRoute(
        path: '/edit-meal-log',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EditMealLogScreen(
            mealLogId: extra['mealLogId'] ?? '',
            mealType: extra['mealType'] ?? 'breakfast',
            notes: extra['notes'],
          );
        },
      ),
      GoRoute(
        path: '/delete-meal-log',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return DeleteMealLogScreen(
            mealLogId: extra['mealLogId'] ?? '',
            mealType: extra['mealType'] ?? 'breakfast',
            loggedAt: extra['loggedAt'] ?? DateTime.now(),
            totalCalories: extra['totalCalories'] ?? 0,
            totalProtein: extra['totalProtein'] ?? 0,
            totalCarbs: extra['totalCarbs'] ?? 0,
            totalFat: extra['totalFat'] ?? 0,
            foods: extra['foods'] ?? [],
          );
        },
      ),
      GoRoute(
        path: '/food-search',
        builder: (_, __) => const FoodSearchScreen(),
      ),
      GoRoute(
        path: '/custom-food',
        builder: (_, __) => const CustomFoodScreen(),
      ),
      GoRoute(
        path: '/hydration',
        builder: (_, __) => const HydrationScreen(),
      ),
      GoRoute(
        path: '/hydration/history',
        builder: (_, __) => const HydrationHistoryScreen(),
      ),
      GoRoute(
        path: '/weight',
        builder: (_, __) => const WeightScreen(),
      ),
      GoRoute(
        path: '/weight/history',
        builder: (_, __) => const WeightHistoryScreen(),
      ),
      GoRoute(
        path: '/recommendation-detail',
        builder: (_, __) => const RecommendationDetailScreen(),
      ),
      GoRoute(
        path: '/add-planned-meal',
        builder: (_, __) => const AddPlannedMealScreen(),
      ),
      GoRoute(
        path: '/day-summary',
        builder: (_, state) {
          return const DaySummaryScreen();
        },
      ),
      GoRoute(
        path: '/ai-scanner',
        builder: (_, __) => const AiScannerScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (_, __) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/nutrition-target',
        builder: (_, __) => const NutritionTargetScreen(),
      ),
      GoRoute(
        path: '/create-post',
        builder: (_, __) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/post-detail',
        builder: (_, __) => const PostDetailScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sync-status',
        builder: (_, __) => const SyncStatusScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const _AdminGuard(child: AdminScreen()),
        routes: [
          GoRoute(
            path: 'foods',
            builder: (_, __) =>
                const _AdminGuard(child: FoodManagementScreen()),
          ),
          GoRoute(
            path: 'foods/new',
            builder: (_, __) => const _AdminGuard(child: AdminFoodFormScreen()),
          ),
          GoRoute(
            path: 'foods/edit',
            builder: (_, state) => _AdminGuard(
              child: AdminFoodFormScreen(existingFood: state.extra as dynamic),
            ),
          ),
          GoRoute(
            path: 'reports',
            builder: (_, __) => const _AdminGuard(child: ReportsScreen()),
          ),
          GoRoute(
            path: 'reports/detail',
            builder: (_, state) => _AdminGuard(
              child: ModerationDetailScreen(report: state.extra as PostReport),
            ),
          ),
          GoRoute(
            path: 'foods/price-history',
            builder: (_, state) {
              final args = state.extra as Map<String, dynamic>;
              return _AdminGuard(
                child: PriceHistoryScreen(
                  foodId: args['foodId'] as String,
                  foodName: args['foodName'] as String,
                  currentPrice: args['currentPrice'] as double,
                ),
              );
            },
          ),
          GoRoute(
            path: 'analytics',
            builder: (_, __) =>
                const _AdminGuard(child: AdminAnalyticsScreen()),
          ),
        ],
      ),
    ],
  );
});

class _AdminGuard extends ConsumerWidget {
  final Widget child;

  const _AdminGuard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(isAdminProvider).when(
          data: (allowed) => allowed
              ? child
              : Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 48,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.48)),
                        const SizedBox(height: 12),
                        Text('Access denied',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Scaffold(
            body: Center(
              child: Text('Unable to verify admin access.',
                  style: theme.textTheme.bodyMedium),
            ),
          ),
        );
  }
}

class DashboardShell extends StatelessWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  int _selectedIndex(String location) {
    if (location.startsWith('/meal-log')) {
      return 1;
    }
    if (location.startsWith('/chatbot')) {
      return 2;
    }
    if (location.startsWith('/planner')) {
      return 3;
    }
    if (location.startsWith('/community')) {
      return 4;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/meal-log');
      case 2:
        context.go('/chatbot');
      case 3:
        context.go('/planner');
      case 4:
        context.go('/community');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _selectedIndex(location);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: GlassContainer(
        level: GlassSurfaceLevel.chrome,
        // Static chrome avoids re-blurring scrolling content every frame on
        // budget Android hardware; profile QA showed the live path exceeding
        // the 16.7 ms raster budget on the dashboard.
        liveBlur: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) => _onTap(context, i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'AI Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Planner',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Community',
            ),
          ],
        ),
      ),
    );
  }
}
