import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';

class QuantitySheet extends StatefulWidget {
  final Food food;
  final ValueChanged<FoodQuantityResult> onConfirm;
  final String mealType;
  final DateTime? loggedAt;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const QuantitySheet({
    super.key,
    required this.food,
    required this.onConfirm,
    this.mealType = 'breakfast',
    this.loggedAt,
    this.totalCalories = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
  });

  @override
  State<QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<QuantitySheet> {
  String _selectedUnit = 'g';
  double _quantity = 100;
  bool _showMoreNutrients = false;

  static const _units = ['g', 'oz', 'lb', 'cup', 'piece'];

  static const _quickSelectPresets = [25, 50, 100, 150, 200, 250, 300];

  Food get _food => widget.food;

  double get _servingMultiplier => FoodQuantityResult.servingMultiplierFor(
        food: _food,
        quantity: _quantity,
        unit: _selectedUnit,
      );
  double get _caloriesForQuantity => _food.calories * _servingMultiplier;
  double get _proteinForQuantity => _food.proteinG * _servingMultiplier;
  double get _carbsForQuantity => _food.carbsG * _servingMultiplier;
  double get _fatForQuantity => _food.fatG * _servingMultiplier;

  double get _minQuantity => _selectedUnit == 'g' ? 10 : 1;
  double get _maxQuantity => _selectedUnit == 'g' ? 500 : 50;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      level: GlassSurfaceLevel.modal,
      liveBlur: true,
      height: MediaQuery.of(context).size.height * 0.92,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Quantity',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Adjust the serving size for ${_food.foodName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FoodInfoCard(food: _food),
                const SizedBox(height: 16),
                const _SectionHeader(number: '1', title: 'Select Unit'),
                _UnitSelector(
                  units: _units,
                  selected: _selectedUnit,
                  onSelected: (u) => setState(() {
                    _selectedUnit = u;
                    _quantity = u == 'g' ? 100 : 1;
                  }),
                ),
                const SizedBox(height: 16),
                const _SectionHeader(number: '2', title: 'Set Quantity'),
                _QuantityStepper(
                  quantity: _quantity,
                  unit: _selectedUnit,
                  min: _minQuantity,
                  max: _maxQuantity,
                  onChanged: (q) => setState(() => _quantity = q),
                ),
                const SizedBox(height: 16),
                _QuickSelectGrid(
                  presets: _quickSelectPresets,
                  selected: _quantity,
                  unit: _selectedUnit,
                  onTap: (q) => setState(() => _quantity = q.toDouble()),
                  onCustom: () => _showCustomQuantityDialog(),
                ),
                const SizedBox(height: 16),
                _NutritionPreview(
                  calories: _caloriesForQuantity,
                  protein: _proteinForQuantity,
                  carbs: _carbsForQuantity,
                  fat: _fatForQuantity,
                  showMore: _showMoreNutrients,
                  onToggleMore: () =>
                      setState(() => _showMoreNutrients = !_showMoreNutrients),
                  food: _food,
                  quantity: _quantity,
                ),
                const SizedBox(height: 16),
                const _SectionHeader(number: '4', title: 'Apply to Meal'),
                _CurrentMealInfo(
                  mealType: widget.mealType,
                  loggedAt: widget.loggedAt ?? DateTime.now(),
                  totalCalories: widget.totalCalories,
                  totalProtein: widget.totalProtein,
                  totalCarbs: widget.totalCarbs,
                  totalFat: widget.totalFat,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(FoodQuantityResult(
                        food: _food,
                        quantity: _quantity,
                        unit: _selectedUnit,
                      ));
                      Navigator.pop(context);
                    },
                    child: const Text('Add to Meal'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomQuantityDialog() {
    final controller =
        TextEditingController(text: _quantity.round().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: _selectedUnit,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= _minQuantity && val <= _maxQuantity) {
                setState(() => _quantity = val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

class FoodQuantityResult {
  final Food food;
  final double quantity;
  final String unit;

  const FoodQuantityResult({
    required this.food,
    required this.quantity,
    required this.unit,
  });

  double get servingMultiplier => servingMultiplierFor(
        food: food,
        quantity: quantity,
        unit: unit,
      );

  static double servingMultiplierFor({
    required Food food,
    required double quantity,
    required String unit,
  }) {
    final servingGrams = food.servingGrams ?? 100;
    return switch (unit) {
      'g' => quantity / servingGrams,
      'oz' => quantity * 28.3495 / servingGrams,
      'lb' => quantity * 453.592 / servingGrams,
      'cup' || 'piece' => quantity,
      _ => quantity / servingGrams,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;

  const _SectionHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

class _FoodInfoCard extends StatelessWidget {
  final Food food;
  const _FoodInfoCard({required this.food});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant,
                  size: 32, color: AppColors.textSecondary),
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
                    'Per ${food.servingGrams?.round() ?? 100} g',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MacroBadge(
                          label: 'P',
                          value: '${food.proteinG.round()}g',
                          color: AppColors.proteinColor),
                      const SizedBox(width: 6),
                      _MacroBadge(
                          label: 'C',
                          value: '${food.carbsG.round()}g',
                          color: AppColors.carbsColor),
                      const SizedBox(width: 6),
                      _MacroBadge(
                          label: 'F',
                          value: '${food.fatG.round()}g',
                          color: AppColors.fatColor),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.formatCalories(food.calories),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
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

class _MacroBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label $value',
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  final List<String> units;
  final String selected;
  final ValueChanged<String> onSelected;

  const _UnitSelector({
    required this.units,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: units.map((unit) {
        final isSelected = unit == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(unit),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                unit,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textOnAccent
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final double quantity;
  final String unit;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _QuantityStepper({
    required this.quantity,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onTap: quantity > min
                      ? () => onChanged(quantity - (unit == 'g' ? 10 : 1))
                      : null,
                ),
                const SizedBox(width: 24),
                Text(
                  '${quantity.round()}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(width: 24),
                _StepperButton(
                  icon: Icons.add,
                  onTap: quantity < max
                      ? () => onChanged(quantity + (unit == 'g' ? 10 : 1))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${min.round()} $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                Expanded(
                  child: Slider(
                    value: quantity.clamp(min, max),
                    min: min,
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
                Text(
                  '${max.round()} $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onTap != null ? AppColors.primary : AppColors.divider,
          size: 24,
        ),
      ),
    );
  }
}

class _QuickSelectGrid extends StatelessWidget {
  final List<int> presets;
  final double selected;
  final String unit;
  final ValueChanged<int> onTap;
  final VoidCallback onCustom;

  const _QuickSelectGrid({
    required this.presets,
    required this.selected,
    required this.unit,
    required this.onTap,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...presets.map((preset) {
          final isSelected = selected == preset;
          return GestureDetector(
            onTap: () => onTap(preset),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                '$preset $unit',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textOnAccent
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: onCustom,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text(
              'Custom',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _NutritionPreview extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool showMore;
  final VoidCallback onToggleMore;
  final Food food;
  final double quantity;

  const _NutritionPreview({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.showMore,
    required this.onToggleMore,
    required this.food,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nutrition (per ${quantity.round()} g)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                GestureDetector(
                  onTap: onToggleMore,
                  child: Row(
                    children: [
                      Text(
                        'View Full Details',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                _NutrientTile(
                  label: 'Calories',
                  value: '${calories.round()}',
                  unit: 'kcal',
                  icon: Icons.local_fire_department,
                  color: AppColors.calorieColor,
                ),
                _NutrientTile(
                  label: 'Protein',
                  value: protein.toStringAsFixed(1),
                  unit: 'g',
                  icon: Icons.fitness_center,
                  color: AppColors.proteinColor,
                ),
                _NutrientTile(
                  label: 'Carbs',
                  value: '${carbs.round()}',
                  unit: 'g',
                  icon: Icons.grain,
                  color: AppColors.carbsColor,
                ),
                _NutrientTile(
                  label: 'Fat',
                  value: fat.toStringAsFixed(1),
                  unit: 'g',
                  icon: Icons.opacity,
                  color: AppColors.fatColor,
                ),
              ],
            ),
            if (showMore) ...[
              const Divider(height: 24),
              _MoreNutrientsRow(
                  label: 'Fiber',
                  value:
                      '${(food.carbsG * 0.15 * quantity / 100).toStringAsFixed(1)} g'),
              _MoreNutrientsRow(
                  label: 'Sugars',
                  value:
                      '${(food.carbsG * 0.04 * quantity / 100).toStringAsFixed(1)} g'),
              const _MoreNutrientsRow(label: 'Sodium', value: '2 mg'),
              const _MoreNutrientsRow(label: 'Cholesterol', value: '0 mg'),
              _MoreNutrientsRow(
                  label: 'Saturated Fat',
                  value:
                      '${(food.fatG * 0.15 * quantity / 100).toStringAsFixed(1)} g'),
            ],
            const SizedBox(height: 8),
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
    );
  }
}

class _NutrientTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _NutrientTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            unit,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _MoreNutrientsRow extends StatelessWidget {
  final String label;
  final String value;

  const _MoreNutrientsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _CurrentMealInfo extends StatelessWidget {
  final String mealType;
  final DateTime loggedAt;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const _CurrentMealInfo({
    required this.mealType,
    required this.loggedAt,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  String get _mealTypeDisplay {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return mealType.replaceAll('_', ' ');
    }
  }

  IconData get _mealTypeIcon {
    switch (mealType) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = loggedAt.year == now.year &&
        loggedAt.month == now.month &&
        loggedAt.day == now.day;
    final timeStr = TimeOfDay.fromDateTime(loggedAt).format(context);
    final dateStr = isToday ? 'Today' : '${loggedAt.month}/${loggedAt.day}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_mealTypeIcon, color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mealTypeDisplay,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '$timeStr · $dateStr',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Current Meal Total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${totalCalories.round()} kcal · P ${totalProtein.round()}g · C ${totalCarbs.round()}g · F ${totalFat.round()}g',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
