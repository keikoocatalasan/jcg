import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/meal_planner/meal_planner_provider.dart';
import 'package:jcg_fitness/features/profile_settings/profile_provider.dart';

enum _FilterType { recommended, myFoods, budget, highProtein, quick }

class AddPlannedMealScreen extends ConsumerStatefulWidget {
  const AddPlannedMealScreen({super.key});

  @override
  ConsumerState<AddPlannedMealScreen> createState() =>
      _AddPlannedMealScreenState();
}

class _AddPlannedMealScreenState extends ConsumerState<AddPlannedMealScreen> {
  Food? _selectedFood;
  String _mealType = 'lunch';
  DateTime _plannedDate = DateTime.now();
  double _quantity = 1.0;
  bool _isSaving = false;
  bool _extrasProcessed = false;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Food> _allFoods = [];
  List<Food> _filteredFoods = [];
  bool _isLoadingFoods = false;
  String? _foodsError;

  _FilterType? _activeFilter;

  static const _mealTypes = [
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner'),
    ('snack', 'Snack'),
  ];

  String get _dayLabel {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final day = weekdays[_plannedDate.weekday - 1];
    final month = months[_plannedDate.month - 1];
    return '$day, $month ${_plannedDate.day}';
  }

  String get _mealSlotLabel =>
      _mealTypes.firstWhere((m) => m.$1 == _mealType).$2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processExtras());
  }

  void _processExtras() {
    if (_extrasProcessed) return;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      final food = extra['food'];
      if (food is Food) {
        setState(() => _selectedFood = food);
      }
      final date = extra['selectedDate'];
      if (date is String) {
        final parsed = DateTime.tryParse(date);
        if (parsed != null) {
          setState(() => _plannedDate = parsed);
        }
      }
      final mealType = extra['mealType'];
      if (mealType is String && _mealTypes.any((m) => m.$1 == mealType)) {
        setState(() => _mealType = mealType);
      }
    }
    _extrasProcessed = true;
    _loadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    setState(() {
      _isLoadingFoods = true;
      _foodsError = null;
    });

    try {
      final repo = FoodRepository(DatabaseProvider());
      final query = _searchController.text.trim();
      final foods = query.length >= 2
          ? await repo.searchByName(query)
          : await repo.readActiveOfficial();
      if (mounted) {
        setState(() {
          _allFoods = foods;
          _applyFilter();
          _isLoadingFoods = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _foodsError = 'Failed to load foods: $e';
          _isLoadingFoods = false;
        });
      }
    }
  }

  void _applyFilter() {
    List<Food> result = List.from(_allFoods);

    switch (_activeFilter) {
      case _FilterType.highProtein:
        result = result.where((f) => f.proteinG >= 20).toList();
        break;
      case _FilterType.budget:
        result = result.where((f) => f.estimatedPricePhp <= 50).toList();
        break;
      case _FilterType.quick:
        result = result.where((f) => (f.servingGrams ?? 0) <= 300).toList();
        break;
      case _FilterType.myFoods:
        result = result.where((f) => f.isLocalFood).toList();
        break;
      case _FilterType.recommended:
      case null:
        break;
    }

    _filteredFoods = result;
  }

  List<String> _reasonChips(Food food) {
    final chips = <String>[];
    if (food.proteinG >= 20) chips.add('Protein Fit');
    if (food.calories >= 200 && food.calories <= 600) chips.add('Goal Match');
    if (food.estimatedPricePhp <= 50) chips.add('Budget Friendly');
    return chips;
  }

  void _selectFood(Food food) {
    setState(() => _selectedFood = food);
  }

  void _deselectFood() {
    setState(() => _selectedFood = null);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _plannedDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date != null && mounted) {
      setState(() => _plannedDate = date);
    }
  }

  void _changeMealType(String type) {
    setState(() => _mealType = type);
  }

  Future<void> _save() async {
    if (_selectedFood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a food')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in')),
          );
        }
        return;
      }
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );

      final food = _selectedFood!;
      final mealPlanId = UuidHelper.generateUuid();
      final dateStr = DateFormat('yyyy-MM-dd').format(_plannedDate);
      final now = DateTime.now().toUtc().toIso8601String();

      final db = await DatabaseProvider().database;
      await db.transaction((txn) async {
        await txn.insert('meal_plans', {
          'meal_plan_id': mealPlanId,
          'user_id': localUserId,
          'food_id': food.foodId,
          'meal_type_code': _mealType,
          'status_code': 'planned',
          'converted_meal_log_id': null,
          'food_name_snapshot': food.foodName,
          'serving_grams_snapshot': food.servingGrams ?? 0,
          'quantity': _quantity,
          'calories_snapshot': food.calories * _quantity,
          'protein_g_snapshot': food.proteinG * _quantity,
          'carbs_g_snapshot': food.carbsG * _quantity,
          'fat_g_snapshot': food.fatG * _quantity,
          'cost_php_snapshot': food.estimatedPricePhp * _quantity,
          'planned_date': dateStr,
          'sync_status': 'pending',
          'created_at': now,
          'updated_at': now,
        });

        final operationId = const Uuid().v4();
        await txn.insert('sync_queue', {
          'sync_queue_id': const Uuid().v4(),
          'user_id': localUserId,
          'operation_id': operationId,
          'entity_type_code': 'meal_plan',
          'entity_id': mealPlanId,
          'operation_code': 'create',
          'payload_json': jsonEncode({
            'meal_plan_id': mealPlanId,
            'user_id': localUserId,
            'food_id': food.foodId,
            'meal_type_code': _mealType,
            'status_code': 'planned',
            'food_name_snapshot': food.foodName,
            'serving_grams_snapshot': food.servingGrams ?? 0,
            'quantity': _quantity,
            'calories_snapshot': food.calories * _quantity,
            'protein_g_snapshot': food.proteinG * _quantity,
            'carbs_g_snapshot': food.carbsG * _quantity,
            'fat_g_snapshot': food.fatG * _quantity,
            'cost_php_snapshot': food.estimatedPricePhp * _quantity,
            'planned_date': dateStr,
          }),
          'client_sequence': DateTime.now().millisecondsSinceEpoch,
          'attempt_count': 0,
          'sync_status': 'pending',
          'created_at': now,
        });
      });

      ref.invalidate(weeklyPlansProvider);
      ref.invalidate(plansForDateProvider);
      ref.read(syncProvider.notifier).startSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal planned successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Planned Meal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildInfoBar(theme)),
                SliverToBoxAdapter(child: _buildOfflineBanner(theme)),
                SliverToBoxAdapter(child: _buildSearchBar(theme)),
                SliverToBoxAdapter(child: _buildFilterChips(theme)),
                if (_isLoadingFoods)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_foodsError != null)
                  SliverFillRemaining(
                    child: _buildErrorState(theme),
                  )
                else if (_filteredFoods.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(theme),
                  )
                else
                  SliverList.builder(
                    itemCount: _filteredFoods.length,
                    itemBuilder: (context, index) {
                      return _buildFoodCard(theme, _filteredFoods[index]);
                    },
                  ),
                if (_selectedFood != null)
                  const SliverToBoxAdapter(child: SizedBox(height: 160)),
              ],
            ),
          ),
          if (_selectedFood != null) _buildPreviewPanel(theme),
          _buildBottomButtons(theme),
        ],
      ),
    );
  }

  Widget _buildInfoBar(ThemeData theme) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final goal = (profile?.fitnessGoalCode ?? 'balanced')
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    final weeklyBudget = (profile?.dailyBudgetPhp ?? 300) * 7;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              const Icon(Icons.calendar_today,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Day: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: _pickDate,
                child: Text(
                  _dayLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.restaurant, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Meal Slot: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _changeMealType,
                offset: const Offset(0, 30),
                child: Text(
                  _mealSlotLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                itemBuilder: (_) => _mealTypes
                    .map((m) => PopupMenuItem(
                          value: m.$1,
                          child: Text(m.$2),
                        ))
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Icon(Icons.flag, size: 16, color: AppColors.proteinColor),
              const SizedBox(width: 8),
              Text(
                'Goal: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                goal,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.proteinColor,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.account_balance_wallet,
                  size: 16, color: AppColors.budgetColor),
              const SizedBox(width: 8),
              Text(
                'Budget Left: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${Formatters.formatPhp(weeklyBudget)}/week',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.budgetColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'You\'re offline. Changes will sync later.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search foods...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            onPressed: _showFilterDialog,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => _loadFoods(),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: 'Recommended',
            selected: _activeFilter == _FilterType.recommended,
            onSelected: () => _toggleFilter(_FilterType.recommended),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'My Foods',
            selected: _activeFilter == _FilterType.myFoods,
            onSelected: () => _toggleFilter(_FilterType.myFoods),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Budget',
            selected: _activeFilter == _FilterType.budget,
            onSelected: () => _toggleFilter(_FilterType.budget),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'High Protein',
            selected: _activeFilter == _FilterType.highProtein,
            onSelected: () => _toggleFilter(_FilterType.highProtein),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Quick',
            selected: _activeFilter == _FilterType.quick,
            onSelected: () => _toggleFilter(_FilterType.quick),
          ),
        ],
      ),
    );
  }

  void _toggleFilter(_FilterType type) {
    setState(() {
      _activeFilter = _activeFilter == type ? null : type;
      _applyFilter();
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Foods',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('Sort by Price'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _allFoods.sort((a, b) =>
                        a.estimatedPricePhp.compareTo(b.estimatedPricePhp));
                    _applyFilter();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_fire_department),
                title: const Text('Sort by Calories'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _allFoods.sort((a, b) => a.calories.compareTo(b.calories));
                    _applyFilter();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.egg),
                title: const Text('Sort by Protein'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _allFoods.sort((a, b) => b.proteinG.compareTo(a.proteinG));
                    _applyFilter();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodCard(ThemeData theme, Food food) {
    final isSelected = _selectedFood?.foodId == food.foodId;
    final chips = _reasonChips(food);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: isSelected ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _selectFood(food),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: food.categoryName.isNotEmpty
                      ? Center(
                          child: Text(
                            food.foodName.isNotEmpty
                                ? food.foodName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : const Icon(Icons.restaurant,
                          color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.foodName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${food.categoryName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _NutrientBadge(
                            value: Formatters.formatCalories(food.calories),
                          ),
                          _NutrientBadge(
                            value: 'P ${Formatters.formatMacro(food.proteinG)}',
                          ),
                          _NutrientBadge(
                            value: 'C ${Formatters.formatMacro(food.carbsG)}',
                          ),
                          _NutrientBadge(
                            value: 'F ${Formatters.formatMacro(food.fatG)}',
                          ),
                        ],
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children:
                              chips.map((c) => StatusTag.ok(label: c)).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text(
                      Formatters.formatPhp(food.estimatedPricePhp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.budgetColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _selectFood(food),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.add,
                          size: 18,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
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

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _foodsError ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadFoods,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No foods found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search or filter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(ThemeData theme) {
    final food = _selectedFood!;
    final calories = food.calories * _quantity;
    final protein = food.proteinG * _quantity;
    final carbs = food.carbsG * _quantity;
    final fat = food.fatG * _quantity;
    final cost = food.estimatedPricePhp * _quantity;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              const Icon(Icons.preview, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Planned Meal Preview',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _deselectFood,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.foodName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_mealSlotLabel} · $_dayLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniNutrient(
                  label: 'Cal', value: '${calories.toStringAsFixed(0)}'),
              _MiniNutrient(
                  label: 'P', value: '${protein.toStringAsFixed(1)}g'),
              _MiniNutrient(label: 'C', value: '${carbs.toStringAsFixed(1)}g'),
              _MiniNutrient(label: 'F', value: '${fat.toStringAsFixed(1)}g'),
              Text(
                Formatters.formatPhp(cost),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving || _selectedFood == null ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Text('Add Planned Meal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NutrientBadge extends StatelessWidget {
  final String value;

  const _NutrientBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MiniNutrient extends StatelessWidget {
  final String label;
  final String value;

  const _MiniNutrient({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.textPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
