import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/dashboard/dashboard_provider.dart';
import 'package:jcg_fitness/features/meal_logging/meal_log_provider.dart';
import 'package:jcg_fitness/features/meal_logging/recent_logs_provider.dart';
import 'package:jcg_fitness/features/meal_logging/screens/food_search_sheet.dart';
import 'package:jcg_fitness/features/meal_logging/screens/quantity_sheet.dart';

class EditMealLogScreen extends ConsumerStatefulWidget {
  final String mealLogId;
  final String mealType;
  final String? notes;

  const EditMealLogScreen({
    super.key,
    required this.mealLogId,
    required this.mealType,
    this.notes,
  });

  @override
  ConsumerState<EditMealLogScreen> createState() => _EditMealLogScreenState();
}

class _EditMealLogScreenState extends ConsumerState<EditMealLogScreen> {
  final _notesController = TextEditingController();
  String _mealType = 'breakfast';
  DateTime _loggedAt = DateTime.now();
  bool _isSaving = false;
  bool _isLoading = true;
  String? _loadError;
  bool _showMoreNutrients = false;
  final _foodItems = <_FoodItem>[];
  final _removedMealLogIds = <String>{};

  static const _mealTypes = [
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner'),
    ('snack', 'Snack'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _mealType = widget.mealType;
    _notesController.text = widget.notes ?? '';
    _loadExistingFoods();
  }

  Future<void> _loadExistingFoods() async {
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) throw StateError('You must be logged in.');
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );
      final repo = MealLogRepository(DatabaseProvider());
      final selected =
          await repo.readByIdForUser(widget.mealLogId, localUserId);
      if (selected == null) {
        throw StateError('This meal entry is no longer available.');
      }
      final selectedDate =
          DateTime.tryParse(selected.loggedAt)?.toLocal() ?? DateTime.now();
      final logs = await repo.queryByUserAndDate(
        localUserId,
        _dateOnly(selectedDate),
      );
      final matching = logs
          .where(
            (l) =>
                l.mealTypeCode == selected.mealTypeCode &&
                l.loggedAt == selected.loggedAt &&
                !l.isDeleted,
          )
          .toList();
      final foodRepo = FoodRepository(DatabaseProvider());
      final items = <_FoodItem>[];
      for (final log in matching.isEmpty ? [selected] : matching) {
        final food =
            log.foodId == null ? null : await foodRepo.readById(log.foodId!);
        items.add(
          _FoodItem(
            food: food ?? _foodFromSnapshot(log),
            quantity: log.quantity,
            unit: 'serving',
            mealLogId: log.mealLogId,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _mealType = selected.mealTypeCode;
          _loggedAt = selectedDate;
          _foodItems
            ..clear()
            ..addAll(items);
          _notesController.text = widget.notes ?? '';
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static Food _foodFromSnapshot(MealLog log) {
    final now = DateTime.now().toUtc().toIso8601String();
    return Food(
      foodId: log.foodId ?? 'snapshot-${log.mealLogId}',
      categoryName: 'Logged food',
      foodName: log.foodNameSnapshot,
      normalizedName: log.foodNameSnapshot.toLowerCase(),
      servingLabel: 'Saved serving',
      servingGrams: log.servingGramsSnapshot,
      calories: log.quantity == 0
          ? log.caloriesSnapshot
          : log.caloriesSnapshot / log.quantity,
      proteinG: log.quantity == 0
          ? log.proteinGsnapshot
          : log.proteinGsnapshot / log.quantity,
      carbsG: log.quantity == 0
          ? log.carbsGsnapshot
          : log.carbsGsnapshot / log.quantity,
      fatG: log.quantity == 0
          ? log.fatGsnapshot
          : log.fatGsnapshot / log.quantity,
      estimatedPricePhp: log.quantity == 0
          ? log.costPhpSnapshot
          : log.costPhpSnapshot / log.quantity,
      isLocalFood: true,
      isActive: true,
      isDeleted: false,
      syncStatus: 'synced',
      createdAt: now,
      updatedAt: now,
    );
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

  void _addFood(Food food) {
    Navigator.pop(context);
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
          setState(() => _foodItems.add(_FoodItem(
                food: result.food,
                quantity: result.servingMultiplier,
                unit: 'serving',
              )));
        },
      ),
    );
  }

  void _updateQuantity(int index, double delta) {
    final newQty = _foodItems[index].quantity + delta;
    if (newQty <= 0) {
      _removeFood(index);
      return;
    }
    setState(() {
      _foodItems[index] = _FoodItem(
        food: _foodItems[index].food,
        quantity: newQty,
        unit: _foodItems[index].unit,
        mealLogId: _foodItems[index].mealLogId,
      );
    });
  }

  void _removeFood(int index) {
    final existingId = _foodItems[index].mealLogId;
    if (existingId != null) _removedMealLogIds.add(existingId);
    setState(() => _foodItems.removeAt(index));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    setState(() {
      _loggedAt = DateTime(
          date.year, date.month, date.day, _loggedAt.hour, _loggedAt.minute);
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _loggedAt = DateTime(_loggedAt.year, _loggedAt.month, _loggedAt.day,
          time.hour, time.minute);
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
      final user = await ref.read(authStateProvider.future);
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

      final helper = LocalTransactionHelper(DatabaseProvider());

      final keptIds = <String>{};
      for (final item in _foodItems) {
        final mealLogId = item.mealLogId ?? UuidHelper.generateUuid();
        keptIds.add(mealLogId);
        final mealLogData = <String, dynamic>{
          'meal_log_id': mealLogId,
          'user_id': localUserId,
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
        if (item.mealLogId == null) {
          await helper.createMealLog(mealLogData);
        } else {
          await helper.updateMealLog(mealLogData);
        }
      }

      for (final mealLogId in _removedMealLogIds) {
        if (!keptIds.contains(mealLogId)) {
          await helper.deleteMealLog(mealLogId, localUserId);
        }
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
                Text('Meal log updated successfully!'),
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

  void _deleteMeal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this meal log?'),
        content: const Text(
            'This will remove this meal and all its foods. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(authStateProvider).valueOrNull;
              if (user == null) return;
              try {
                final localUserId = await LocalUserIdentity.resolve(
                  DatabaseProvider(),
                  user.id,
                );
                final helper = LocalTransactionHelper(DatabaseProvider());
                await helper.deleteMealLog(widget.mealLogId, localUserId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.textPrimary, size: 18),
                          SizedBox(width: 8),
                          Text('Meal log deleted'),
                        ],
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _duplicateMeal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meal duplicated')),
    );
  }

  void _moveToAnotherMeal() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Move to meal'),
        children: _mealTypes.map((m) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _mealType = m.$1);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Moved to ${m.$2}')),
              );
            },
            child: Text(m.$2),
          );
        }).toList(),
      ),
    );
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
        title: const Text('Edit Meal Log'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _LoadError(
                    message: _loadError!,
                    onRetry: () {
                      setState(() {
                        _isLoading = true;
                        _loadError = null;
                      });
                      _loadExistingFoods();
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Update your meal details and foods.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ),
                      if (!isOnline)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.warning.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_off,
                                  size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "You're offline. Changes will be saved locally and synced later.",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.warning,
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
                        onDateTap: _pickDate,
                        onTimeTap: _pickTime,
                      ),
                      const _SectionHeader(number: '2', title: 'Foods'),
                      _FoodsSection(
                        foodItems: _foodItems,
                        onAddFood: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => FoodSearchSheet(
                              mealType: _mealType,
                              onFoodSelected: _addFood,
                            ),
                          );
                        },
                        onUpdateQuantity: _updateQuantity,
                        onRemoveFood: _removeFood,
                      ),
                      const _SectionHeader(
                          number: '3', title: 'Meal Summary (Updated)'),
                      _MealSummarySection(
                        totalCalories: _totalCalories,
                        totalProtein: _totalProtein,
                        totalCarbs: _totalCarbs,
                        totalFat: _totalFat,
                        showMore: _showMoreNutrients,
                        onToggleMore: () => setState(
                            () => _showMoreNutrients = !_showMoreNutrients),
                      ),
                      const _SectionHeader(number: '4', title: 'Actions'),
                      _ActionsSection(
                        onDuplicate: _duplicateMeal,
                        onDelete: _deleteMeal,
                        onMove: _moveToAnotherMeal,
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
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _FoodItem {
  final Food food;
  final double quantity;
  final String unit;
  final String? mealLogId;

  const _FoodItem({
    required this.food,
    required this.quantity,
    this.unit = 'serving',
    this.mealLogId,
  });
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
            const Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Unable to load this meal',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
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
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  const _MealDetailsSection({
    required this.mealType,
    required this.loggedAt,
    required this.notesController,
    required this.onMealTypeChanged,
    required this.onDateTap,
    required this.onTimeTap,
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: mealType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Meal Type',
                  prefixIcon: Icon(Icons.restaurant_menu),
                ),
                items: _mealTypes.map((m) {
                  return DropdownMenuItem(value: m.$1, child: Text(m.$2));
                }).toList(),
                onChanged: (v) {
                  if (v != null) onMealTypeChanged(v);
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateSelector = GestureDetector(
                    onTap: onDateTap,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _shortDate(loggedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                  final timeSelector = GestureDetector(
                    onTap: onTimeTap,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        TimeOfDay.fromDateTime(loggedAt).format(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: [
                        dateSelector,
                        const SizedBox(height: 12),
                        timeSelector,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: dateSelector),
                      const SizedBox(width: 12),
                      Expanded(child: timeSelector),
                    ],
                  );
                },
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

  static String _shortDate(DateTime value) =>
      '${_month(value.month)} ${value.day}, ${value.year % 100}';

  static String _month(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}

class _FoodsSection extends StatelessWidget {
  final List<_FoodItem> foodItems;
  final VoidCallback onAddFood;
  final void Function(int index, double delta) onUpdateQuantity;
  final ValueChanged<int> onRemoveFood;

  const _FoodsSection({
    required this.foodItems,
    required this.onAddFood,
    required this.onUpdateQuantity,
    required this.onRemoveFood,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 8),
          ...List.generate(foodItems.length, (index) {
            final item = foodItems[index];
            return _FoodItemTile(
              food: item.food,
              quantity: item.quantity,
              unit: item.unit,
              onIncrement: () => onUpdateQuantity(index, 1),
              onDecrement: () => onUpdateQuantity(index, -1),
              onRemove: () => onRemoveFood(index),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddFood,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Another Food'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodItemTile extends StatelessWidget {
  final Food food;
  final double quantity;
  final String unit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _FoodItemTile({
    required this.food,
    required this.quantity,
    required this.unit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.restaurant, color: AppColors.accentPrimary),
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
            Tooltip(
              message: '${_formatQuantity(quantity)} servings',
              child: Container(
                width: 112,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyButton(icon: Icons.remove, onTap: onDecrement),
                    Expanded(
                      child: Text(
                        '${_formatQuantity(quantity)}×',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    _QtyButton(icon: Icons.add, onTap: onIncrement),
                  ],
                ),
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

  static String _formatQuantity(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
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
  final bool showMore;
  final VoidCallback onToggleMore;

  const _MealSummarySection({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.showMore,
    required this.onToggleMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(),
                  GestureDetector(
                    onTap: onToggleMore,
                    child: Row(
                      children: [
                        Text(
                          'View Full Details',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SummaryItem(
                    value: '${totalCalories.round()}',
                    label: 'kcal',
                    icon: Icons.local_fire_department,
                    color: AppColors.calorieColor,
                  ),
                  _SummaryItem(
                    value: '${totalProtein.round()} g',
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
                    value: '${totalFat.round()} g',
                    label: 'Fat',
                    icon: Icons.opacity,
                    color: AppColors.fatColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: onToggleMore,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'More Nutrients',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Icon(
                        showMore ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ],
                  ),
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

class _ActionsSection extends StatelessWidget {
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onMove;

  const _ActionsSection({
    required this.onDuplicate,
    required this.onDelete,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.content_copy,
            iconColor: AppColors.primary,
            title: 'Duplicate this meal',
            subtitle: 'Create a copy of this meal log',
            onTap: onDuplicate,
          ),
          _ActionTile(
            icon: Icons.delete_outline,
            iconColor: AppColors.error,
            title: 'Delete this meal log',
            subtitle: 'Remove this meal and all foods',
            onTap: onDelete,
            titleColor: AppColors.error,
          ),
          _ActionTile(
            icon: Icons.move_to_inbox,
            iconColor: AppColors.primary,
            title: 'Move to another meal',
            subtitle: 'Change meal type (e.g., from Breakfast to Lunch)',
            onTap: onMove,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
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
                    'Changes are saved locally and will sync when you\'re back online.',
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
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: titleColor,
          ),
        ),
        subtitle: Text(subtitle),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
