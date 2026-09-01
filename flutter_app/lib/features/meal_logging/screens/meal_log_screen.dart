import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/meal_logging/meal_log_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/meal_logging/screens/food_search_sheet.dart';
import 'package:jcg_fitness/features/meal_logging/screens/quantity_sheet.dart';

class MealLogScreen extends ConsumerStatefulWidget {
  const MealLogScreen({super.key});

  @override
  ConsumerState<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends ConsumerState<MealLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String _mealType = 'lunch';
  DateTime _loggedAt = DateTime.now();
  bool _isSaving = false;
  final _foodItems = <_FoodItem>[];
  bool _searchMode = true;
  String _searchQuery = '';
  List<Food> _searchResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processExtras());
  }

  void _processExtras() {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      final food = extra['food'];
      if (food is Food) {
        setState(() {
          _foodItems.add(_FoodItem(food: food, quantity: 1));
          _searchMode = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _totalCalories => _foodItems.fold(
      0, (sum, item) => sum + item.food.calories * item.quantity);

  double get _totalProtein => _foodItems.fold(
      0, (sum, item) => sum + item.food.proteinG * item.quantity);

  double get _totalCarbs =>
      _foodItems.fold(0, (sum, item) => sum + item.food.carbsG * item.quantity);

  double get _totalFat =>
      _foodItems.fold(0, (sum, item) => sum + item.food.fatG * item.quantity);

  Future<void> _searchFoods(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final repo = FoodRepository(DatabaseProvider());
      final results = await repo.searchByName(query.trim());
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {}
  }

  void _addFood(Food food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuantitySheet(
        food: food,
        mealType: _mealType,
        loggedAt: _loggedAt,
        totalCalories: _totalCalories,
        totalProtein: _totalProtein,
        totalCarbs: _totalCarbs,
        totalFat: _totalFat,
        onConfirm: (result) {
          final existing =
              _foodItems.indexWhere((i) => i.food.foodId == result.food.foodId);
          if (existing >= 0) {
            setState(() {
              _foodItems[existing] = _FoodItem(
                food: result.food,
                quantity:
                    _foodItems[existing].quantity + result.servingMultiplier,
              );
            });
          } else {
            setState(() => _foodItems.add(_FoodItem(
                  food: result.food,
                  quantity: result.servingMultiplier,
                )));
          }
        },
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    final newQty = _foodItems[index].quantity + delta;
    if (newQty < 1) return;
    setState(() {
      _foodItems[index] =
          _FoodItem(food: _foodItems[index].food, quantity: newQty);
    });
  }

  void _removeFood(int index) {
    setState(() => _foodItems.removeAt(index));
  }

  void _clearAll() {
    setState(() {
      _foodItems.clear();
      _searchMode = true;
      _notesController.clear();
      _mealType = 'lunch';
      _loggedAt = DateTime.now();
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _loggedAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_foodItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one food')),
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

      final helper = LocalTransactionHelper(DatabaseProvider());

      for (final item in _foodItems) {
        final mealLogId = UuidHelper.generateUuid();
        final mealLogData = <String, dynamic>{
          'meal_log_id': mealLogId,
          'user_id': user.id,
          'food_id': item.food.foodId,
          'meal_type_code': _mealType,
          'log_source_code': 'manual',
          'food_name_snapshot': item.food.foodName,
          'serving_grams_snapshot': item.food.servingGrams ?? 0,
          'quantity': item.quantity.toDouble(),
          'calories_snapshot': item.food.calories * item.quantity,
          'protein_g_snapshot': item.food.proteinG * item.quantity,
          'carbs_g_snapshot': item.food.carbsG * item.quantity,
          'fat_g_snapshot': item.food.fatG * item.quantity,
          'cost_php_snapshot': item.food.estimatedPricePhp * item.quantity,
          'logged_at': _loggedAt.toUtc().toIso8601String(),
          'is_deleted': 0,
        };
        await helper.createMealLog(mealLogData);
      }

      if (mounted) {
        ref.invalidate(todayMealLogsProvider);
        ref.invalidate(mealLogsForDateProvider);
        ref.invalidate(dashboardDataProvider);
        ref.invalidate(recentLogsProvider);
        ref.read(syncProvider.notifier).startSync();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.textPrimary, size: 18),
                SizedBox(width: 8),
                Text('Meal logged successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
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
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manual Log'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              'Save',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
      body: GlassBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Manually add food items to your meal log.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              if (!isOnline)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off,
                          size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You're offline. Meal will be saved locally and synced later.",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              const _SectionHeader(number: '1', title: 'Meal Details'),
              _MealDetailsSection(
                mealType: _mealType,
                loggedAt: _loggedAt,
                notesController: _notesController,
                onMealTypeChanged: (v) => setState(() => _mealType = v),
                onDateTimeTap: _pickDateTime,
              ),
              const _SectionHeader(number: '2', title: 'Add Food Items'),
              _AddFoodSection(
                searchMode: _searchMode,
                searchQuery: _searchQuery,
                searchResults: _searchResults,
                foodItems: _foodItems,
                onSearchChanged: (q) {
                  setState(() => _searchQuery = q);
                  _searchFoods(q);
                },
                onToggleMode: () => setState(() => _searchMode = !_searchMode),
                onAddFood: _addFood,
                onAddAnother: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => FoodSearchSheet(
                      onFoodSelected: _addFood,
                    ),
                  );
                },
                onUpdateQuantity: _updateQuantity,
                onRemoveFood: _removeFood,
              ),
              const _SectionHeader(number: '3', title: 'Meal Summary'),
              _MealSummarySection(
                totalCalories: _totalCalories,
                totalProtein: _totalProtein,
                totalCarbs: _totalCarbs,
                totalFat: _totalFat,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Meal Log'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _clearAll,
                        child: const Text('Clear All'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodItem {
  final Food food;
  final double quantity;

  const _FoodItem({required this.food, required this.quantity});
}

class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;

  const _SectionHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            '$number. ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _MealDetailsSection extends StatelessWidget {
  final String mealType;
  final DateTime loggedAt;
  final TextEditingController notesController;
  final ValueChanged<String> onMealTypeChanged;
  final VoidCallback onDateTimeTap;

  const _MealDetailsSection({
    required this.mealType,
    required this.loggedAt,
    required this.notesController,
    required this.onMealTypeChanged,
    required this.onDateTimeTap,
  });

  static const _mealTypes = [
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner'),
    ('snack', 'Snack'),
    ('other', 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: mealType,
                      decoration: const InputDecoration(
                        labelText: 'Meal Type',
                        prefixIcon: Icon(Icons.restaurant_menu),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: _mealTypes.map((m) {
                        return DropdownMenuItem(value: m.$1, child: Text(m.$2));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) onMealTypeChanged(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onDateTimeTap,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date & Time',
                          prefixIcon: Icon(Icons.calendar_today),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        child: Text(
                          '${loggedAt.month.toString().padLeft(2, '0')}/${loggedAt.day.toString().padLeft(2, '0')}/${loggedAt.year}  ·  ${TimeOfDay.fromDateTime(loggedAt).format(context)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add a note about this meal',
                ),
                maxLength: 150,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFoodSection extends StatefulWidget {
  final bool searchMode;
  final String searchQuery;
  final List<Food> searchResults;
  final List<_FoodItem> foodItems;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleMode;
  final ValueChanged<Food> onAddFood;
  final VoidCallback onAddAnother;
  final void Function(int index, int delta) onUpdateQuantity;
  final ValueChanged<int> onRemoveFood;

  const _AddFoodSection({
    required this.searchMode,
    required this.searchQuery,
    required this.searchResults,
    required this.foodItems,
    required this.onSearchChanged,
    required this.onToggleMode,
    required this.onAddFood,
    required this.onAddAnother,
    required this.onUpdateQuantity,
    required this.onRemoveFood,
  });

  @override
  State<_AddFoodSection> createState() => _AddFoodSectionState();
}

class _AddFoodSectionState extends State<_AddFoodSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.searchMode ? null : widget.onToggleMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.searchMode
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8)),
                      border: Border.all(color: AppColors.divider),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Search Foods',
                      style: TextStyle(
                        color: widget.searchMode
                            ? AppColors.textOnAccent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: widget.searchMode ? widget.onToggleMode : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !widget.searchMode
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8)),
                      border: Border.all(color: AppColors.divider),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'My Foods',
                      style: TextStyle(
                        color: !widget.searchMode
                            ? AppColors.textOnAccent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for a food...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => context.push('/ai-scanner'),
              ),
            ),
            onChanged: widget.onSearchChanged,
          ),
          if (widget.searchQuery.length >= 2) ...[
            const SizedBox(height: 12),
            ...widget.searchResults.map((food) => _SearchResultTile(
                  food: food,
                  onTap: () {
                    widget.onAddFood(food);
                    _searchController.clear();
                    widget.onSearchChanged('');
                  },
                )),
          ],
          if (widget.foodItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(widget.foodItems.length, (index) {
              final item = widget.foodItems[index];
              return _FoodItemTile(
                food: item.food,
                quantity: item.quantity,
                onIncrement: () => widget.onUpdateQuantity(index, 1),
                onDecrement: () => widget.onUpdateQuantity(index, -1),
                onRemove: () => widget.onRemoveFood(index),
              );
            }),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: widget.onAddAnother,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Another Item'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;

  const _SearchResultTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant, color: AppColors.textSecondary),
        ),
        title: Text(
          food.foodName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${food.servingLabel ?? '1 serving'} (${food.servingGrams?.round() ?? 0} g) · ${Formatters.formatCalories(food.calories)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'P ${food.proteinG.round()}g',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.proteinColor),
            ),
            const SizedBox(width: 6),
            Text(
              'C ${food.carbsG.round()}g',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.carbsColor),
            ),
            const SizedBox(width: 6),
            Text(
              'F ${food.fatG.round()}g',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.fatColor),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _FoodItemTile extends StatelessWidget {
  final Food food;
  final double quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _FoodItemTile({
    required this.food,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.restaurant, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.foodName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${food.servingLabel ?? '1 serving'} (${food.servingGrams?.round() ?? 0} g)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    Formatters.formatCalories(food.calories * quantity),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(icon: Icons.remove, onTap: onDecrement),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text(
                      quantity == quantity.roundToDouble()
                          ? quantity.toInt().toString()
                          : quantity.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _QtyButton(icon: Icons.add, onTap: onIncrement),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'remove') onRemove();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
              child:
                  const Icon(Icons.more_vert, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}

class _MealSummarySection extends StatelessWidget {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const _MealSummarySection({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _SummaryItem(
                    value: '${totalCalories.round()}',
                    label: 'Calories',
                    icon: Icons.local_fire_department,
                    color: AppColors.calorieColor,
                  ),
                  _SummaryItem(
                    value: '${totalProtein.toStringAsFixed(1)} g',
                    label: 'Protein',
                    icon: Icons.fitness_center,
                    color: AppColors.proteinColor,
                  ),
                  _SummaryItem(
                    value: '${totalCarbs.round()} g',
                    label: 'Carbs',
                    icon: Icons.grain,
                    color: AppColors.carbsColor,
                  ),
                  _SummaryItem(
                    value: '${totalFat.toStringAsFixed(1)} g',
                    label: 'Fat',
                    icon: Icons.opacity,
                    color: AppColors.fatColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These values are based on the selected serving sizes.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}
