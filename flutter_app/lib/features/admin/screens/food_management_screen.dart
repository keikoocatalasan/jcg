import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/empty_state_widget.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';

enum FoodFilter { all, active, inactive }

class FoodManagementScreen extends ConsumerStatefulWidget {
  const FoodManagementScreen({super.key});

  @override
  ConsumerState<FoodManagementScreen> createState() =>
      _FoodManagementScreenState();
}

class _FoodManagementScreenState extends ConsumerState<FoodManagementScreen> {
  final _searchController = TextEditingController();
  FoodFilter _selectedFilter = FoodFilter.all;
  int _loadedPages = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetPagination() {
    setState(() => _loadedPages = 1);
  }

  List<Food> _filter(List<Food> foods) {
    var filtered = foods;
    switch (_selectedFilter) {
      case FoodFilter.active:
        filtered = filtered.where((f) => f.isActive).toList();
        break;
      case FoodFilter.inactive:
        filtered = filtered.where((f) => !f.isActive).toList();
        break;
      case FoodFilter.all:
        break;
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((f) => f.foodName.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  StatusTag _statusTag(Food food) {
    if (food.syncStatus == 'pending') {
      return const StatusTag.neutral(label: 'Pending');
    }
    if (!food.isActive) return const StatusTag.neutral(label: 'Inactive');
    return const StatusTag.ok(label: 'Active');
  }

  IconData _foodIcon(Food food) {
    final name = food.foodName.toLowerCase();
    if (name.contains('chicken') ||
        name.contains('pork') ||
        name.contains('beef')) {
      return Icons.set_meal;
    }
    if (name.contains('rice') || name.contains('bread')) {
      return Icons.rice_bowl;
    }
    if (name.contains('apple') ||
        name.contains('banana') ||
        name.contains('fruit')) {
      return Icons.apple;
    }
    if (name.contains('milk') || name.contains('yogurt')) {
      return Icons.local_cafe;
    }
    if (name.contains('egg')) {
      return Icons.egg;
    }
    return Icons.restaurant;
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(pagedAdminFoodsProvider(_loadedPages));
    final nextFoodsAsync = ref.watch(pagedAdminFoodsProvider(_loadedPages + 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Food Management')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_add_food',
        onPressed: () => context.push('/admin/foods/new'),
        child: const Icon(Icons.add),
      ),
      body: GlassBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search foods...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: FoodFilter.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final filter = FoodFilter.values[i];
                  final isSelected = _selectedFilter == filter;
                  return FilterChip(
                    label: Text(
                      filter.name[0].toUpperCase() + filter.name.substring(1),
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.surface
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    backgroundColor: AppColors.surfaceAlt,
                    selectedColor: AppColors.textPrimary,
                    checkmarkColor: AppColors.surface,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: foodsAsync.when(
                data: (foods) {
                  final filtered = _filter(foods);
                  final hasMore = nextFoodsAsync.when(
                    data: (nextFoods) => nextFoods.length > foods.length,
                    loading: () => true,
                    error: (_, __) => false,
                  );
                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.restaurant_menu,
                      title: 'No foods found',
                      subtitle: 'Add a new food using the + button.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () {
                      _resetPagination();
                      return ref.refresh(pagedAdminFoodsProvider(1).future);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length + (hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        if (i == filtered.length && hasMore) {
                          final loadedNext = nextFoodsAsync.valueOrNull;
                          final moreCount = loadedNext == null
                              ? adminFoodPageSize
                              : loadedNext.length - foods.length;
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => setState(
                                    () => _loadedPages = _loadedPages + 1),
                                child: Text('Load More ($moreCount more)'),
                              ),
                            ),
                          );
                        }
                        final food = filtered[i];
                        return GlassCard(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Icon(
                                _foodIcon(food),
                                color: AppColors.textPrimary,
                              ),
                            ),
                            title: Text(
                              food.foodName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              food.categoryName,
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${Formatters.formatPhp(food.estimatedPricePhp)} / 100g',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _statusTag(food),
                              ],
                            ),
                            onTap: () =>
                                context.push('/admin/foods/edit', extra: food),
                          ),
                        );
                      },
                    ),
                  );
                },
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.textPrimary),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load foods',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$err',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
