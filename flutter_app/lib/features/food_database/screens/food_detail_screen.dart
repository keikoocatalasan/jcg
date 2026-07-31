import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/constants.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/core/widgets/status_tag.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  final Food food;

  const FoodDetailScreen({super.key, required this.food});

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  int _quantity = 1;
  DateTime _loggedAt = DateTime.now();
  String _servingSize = '';

  @override
  void initState() {
    super.initState();
    _servingSize = widget.food.servingLabel ?? '1 serving';
  }

  Food get _food => widget.food;

  double get _totalCalories => _food.calories * _quantity;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Food Detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (!isOnline)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                      "You're offline. Showing last saved data.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          _FoodHeader(food: _food),
          _MacroSummaryRow(food: _food),
          _NutritionFactsCard(food: _food),
          _LogFoodSection(
            food: _food,
            quantity: _quantity,
            loggedAt: _loggedAt,
            servingSize: _servingSize,
            totalCalories: _totalCalories,
            onQuantityChanged: (q) => setState(() => _quantity = q),
            onDateChanged: (dt) => setState(() => _loggedAt = dt),
            onServingChanged: (s) => setState(() => _servingSize = s),
          ),
          _RelatedFoodsSection(food: _food),
        ],
      ),
    );
  }
}

class _FoodHeader extends StatelessWidget {
  final Food food;
  const _FoodHeader({required this.food});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(
              Icons.restaurant,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.foodName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                const StatusTag.ok(label: 'Common'),
                const SizedBox(height: 8),
                Text(
                  '${food.servingLabel ?? '1 serving'} (${food.servingGrams?.round() ?? 0} g)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCalories(food.calories),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'per serving',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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

class _MacroSummaryRow extends StatelessWidget {
  final Food food;
  const _MacroSummaryRow({required this.food});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _MacroCard(
              label: 'Calories',
              value: '${food.calories.round()}',
              icon: Icons.local_fire_department,
              color: AppColors.calorieColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MacroCard(
              label: 'Protein',
              value: '${food.proteinG.round()} g',
              icon: Icons.fitness_center,
              color: AppColors.proteinColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MacroCard(
              label: 'Carbs',
              value: '${food.carbsG.round()} g',
              icon: Icons.grain,
              color: AppColors.carbsColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MacroCard(
              label: 'Fats',
              value: '${food.fatG.round()} g',
              icon: Icons.opacity,
              color: AppColors.fatColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionFactsCard extends StatelessWidget {
  final Food food;
  const _NutritionFactsCard({required this.food});

  @override
  Widget build(BuildContext context) {
    final totalFatG = food.fatG;
    final saturatedFat = totalFatG * 0.15;
    const transFat = 0.0;
    const cholesterol = 0.0;
    const sodium = 2.0;
    final totalCarbs = food.carbsG;
    final dietaryFiber = totalCarbs * 0.15;
    final totalSugars = totalCarbs * 0.04;
    final protein = food.proteinG;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Facts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 24),
            _NutritionRow(
              label: 'Serving Size',
              value:
                  '${food.servingLabel ?? '1 serving'} (${food.servingGrams?.round() ?? 0} g)',
            ),
            const _NutritionRow(
              label: 'Servings Per Container',
              value: '1',
            ),
            const Divider(height: 24),
            Text(
              'Amount Per Serving',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${food.calories.round()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '% Daily Value*',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            _NutritionDetailRow(
              label: 'Total Fat',
              amount: '${totalFatG.toStringAsFixed(0)} g',
              percent: '${(totalFatG / 65 * 100).round()}%',
            ),
            _NutritionDetailRow(
              label: 'Saturated Fat',
              amount: '${saturatedFat.toStringAsFixed(1)} g',
              percent: '${(saturatedFat / 20 * 100).round()}%',
              indent: true,
            ),
            _NutritionDetailRow(
              label: 'Trans Fat',
              amount: '${transFat.toStringAsFixed(0)} g',
              indent: true,
            ),
            _NutritionDetailRow(
              label: 'Cholesterol',
              amount: '${cholesterol.toStringAsFixed(0)} mg',
              percent: '${(cholesterol / 300 * 100).round()}%',
            ),
            _NutritionDetailRow(
              label: 'Sodium',
              amount: '${sodium.toStringAsFixed(0)} mg',
              percent: '${(sodium / 2300 * 100).round()}%',
            ),
            _NutritionDetailRow(
              label: 'Total Carbohydrate',
              amount: '${totalCarbs.toStringAsFixed(0)} g',
              percent: '${(totalCarbs / 300 * 100).round()}%',
            ),
            _NutritionDetailRow(
              label: 'Dietary Fiber',
              amount: '${dietaryFiber.toStringAsFixed(0)} g',
              percent: '${(dietaryFiber / 28 * 100).round()}%',
              indent: true,
            ),
            _NutritionDetailRow(
              label: 'Total Sugars',
              amount: '${totalSugars.toStringAsFixed(0)} g',
              indent: true,
            ),
            const _NutritionDetailRow(
              label: 'Includes 0 g Added Sugars',
              amount: '',
              percent: '0%',
              indent: true,
            ),
            _NutritionDetailRow(
              label: 'Protein',
              amount: '${protein.toStringAsFixed(0)} g',
              percent: '${(protein / 50 * 100).round()}%',
            ),
            const Divider(height: 24),
            const _NutritionDetailRow(
              label: 'Vitamin D',
              amount: '',
              percent: '0%',
            ),
            const _NutritionDetailRow(
              label: 'Calcium',
              amount: '',
              percent: '2%',
            ),
            const _NutritionDetailRow(
              label: 'Iron',
              amount: '',
              percent: '6%',
            ),
            const _NutritionDetailRow(
              label: 'Potassium',
              amount: '',
              percent: '4%',
            ),
            const Divider(height: 24),
            Text(
              '*The % Daily Value (DV) tells you how much a nutrient in a serving of food contributes to a daily diet. 2,000 calories a day is used for general nutrition advice.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final String label;
  final String value;
  const _NutritionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _NutritionDetailRow extends StatelessWidget {
  final String label;
  final String amount;
  final String? percent;
  final bool indent;

  const _NutritionDetailRow({
    required this.label,
    required this.amount,
    this.percent,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: indent ? 24 : 0,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              amount.isNotEmpty ? '$label  $amount' : label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: indent ? FontWeight.normal : FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ),
          if (percent != null)
            Text(
              percent!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
        ],
      ),
    );
  }
}

class _LogFoodSection extends StatefulWidget {
  final Food food;
  final int quantity;
  final DateTime loggedAt;
  final String servingSize;
  final double totalCalories;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onServingChanged;

  const _LogFoodSection({
    required this.food,
    required this.quantity,
    required this.loggedAt,
    required this.servingSize,
    required this.totalCalories,
    required this.onQuantityChanged,
    required this.onDateChanged,
    required this.onServingChanged,
  });

  @override
  State<_LogFoodSection> createState() => _LogFoodSectionState();
}

class _LogFoodSectionState extends State<_LogFoodSection> {
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _date = widget.loggedAt;
    _time = TimeOfDay.fromDateTime(widget.loggedAt);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Food',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTimeField(
                    label: 'Date',
                    value:
                        '${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}/${_date.year}',
                    icon: Icons.calendar_today,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTimeField(
                    label: 'Time',
                    value: _time.format(context),
                    icon: Icons.access_time,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serving Size',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.servingSize,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down,
                                color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      'Quantity',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _QuantityButton(
                            icon: Icons.remove,
                            onTap: widget.quantity > 1
                                ? () => widget
                                    .onQuantityChanged(widget.quantity - 1)
                                : null,
                          ),
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '${widget.quantity}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          _QuantityButton(
                            icon: Icons.add,
                            onTap: () =>
                                widget.onQuantityChanged(widget.quantity + 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                Formatters.formatCalories(widget.totalCalories),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(
                  AppConstants.mealLogRoute,
                  extra: {'food': widget.food},
                ),
                child: const Text('Log This Food'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _date = date);
      widget.onDateChanged(
          DateTime(date.year, date.month, date.day, _time.hour, _time.minute));
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (time != null) {
      setState(() => _time = time);
      widget.onDateChanged(
          DateTime(_date.year, _date.month, _date.day, time.hour, time.minute));
    }
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateTimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(icon, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? AppColors.primary : AppColors.divider,
        ),
      ),
    );
  }
}

class _RelatedFoodsSection extends StatelessWidget {
  final Food food;
  const _RelatedFoodsSection({required this.food});

  final _related = const [
    ('Oats, Raw', '1 cup (81 g)', 307),
    ('Quick Oats, Cooked', '1 cup (234 g)', 154),
    ('Steel Cut Oats, Cooked', '1 cup (236 g)', 170),
    ('Oat Bran', '1 cup (60 g)', 210),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Related Foods',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final (name, serving, calories) = _related[index];
              return SizedBox(
                width: 140,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            size: 32,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serving,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          '$calories kcal',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
