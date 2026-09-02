import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/core/database/meal_log_repository.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/sync/local_transaction_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
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
  bool _showMoreNutrients = false;
  final _foodItems = <_FoodItem>[];

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
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );
      final repo = MealLogRepository(DatabaseProvider());
      final logs = await repo.queryByUserAndDate(
        localUserId,
        _loggedAt.toUtc().toIso8601String().substring(0, 10),
      );
      final matching = logs
          .where(
            (l) =>
                l.mealTypeCode == widget.mealType &&
                l.mealLogId == widget.mealLogId &&
                !l.isDeleted,
          )
          .toList();
      if (matching.isNotEmpty && mounted) {
        setState(() {
          _loggedAt = DateTime.tryParse(matching.first.loggedAt)?.toLocal() ??
              _loggedAt;
          _notesController.text = widget.notes ?? '';
        });
      }
    } catch (_) {}
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
                quantity: result.quantity.round(),
                unit: result.unit,
              )));
        },
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    final newQty = _foodItems[index].quantity + delta;
    if (newQty < 1) return;
    setState(() {
      _foodItems[index] = _FoodItem(
        food: _foodItems[index].food,
        quantity: newQty,
        unit: _foodItems[index].unit,
      );
    });
  }

  void _removeFood(int index) {
    setState(() => _foodItems.removeAt(index));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(now.year - 1),
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

      final helper = LocalTransactionHelper(DatabaseProvider());

      for (final item in _foodItems) {
        final mealLogData = <String, dynamic>{
          'meal_log_id': widget.mealLogId,
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
        await helper.updateMealLog(mealLogData);
      }

      if (mounted) {
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
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Update your meal details and foods.',
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
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You're offline. Changes will be saved locally and synced later.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  builder: (_) => FoodSearchSheet(onFoodSelected: _addFood),
                );
              },
              onUpdateQuantity: _updateQuantity,
              onRemoveFood: _removeFood,
            ),
            const _SectionHeader(number: '3', title: 'Meal Summary (Updated)'),
            _MealSummarySection(
              totalCalories: _totalCalories,
              totalProtein: _totalProtein,
              totalCarbs: _totalCarbs,
              totalFat: _totalFat,
              showMore: _showMoreNutrients,
              onToggleMore: () =>
                  setState(() => _showMoreNutrients = !_showMoreNutrients),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
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
  final int quantity;
  final String unit;

  const _FoodItem(
      {required this.food, required this.quantity, this.unit = 'g'});
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
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onDateTap,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${loggedAt.month.toString().padLeft(2, '0')}/${loggedAt.day.toString().padLeft(2, '0')}/${loggedAt.year}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onTimeTap,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          TimeOfDay.fromDateTime(loggedAt).format(context),
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

class _FoodsSection extends StatelessWidget {
  final List<_FoodItem> foodItems;
  final VoidCallback onAddFood;
  final void Function(int index, int delta) onUpdateQuantity;
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
  final int quantity;
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
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '$quantity $unit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
