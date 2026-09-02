import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/local_user_id_provider.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/food_database/food_provider.dart';

class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key});

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _servingSizeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarsController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _saturatedFatController = TextEditingController();

  String? _selectedCategory;
  String _selectedServingUnit = 'cup';
  bool _isPublic = false;
  bool _saveToMyFoods = true;
  bool _isLoading = false;

  static const _servingUnits = [
    'cup',
    'g',
    'ml',
    'oz',
    'piece',
    'serving',
  ];

  @override
  void dispose() {
    _foodNameController.dispose();
    _servingSizeController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarsController.dispose();
    _sodiumController.dispose();
    _cholesterolController.dispose();
    _saturatedFatController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final localUserId = await LocalUserIdentity.resolve(
        DatabaseProvider(),
        user.id,
      );
      final data = FoodFormData(
        userId: localUserId,
        foodName: _foodNameController.text.trim(),
        categoryName: _selectedCategory!,
        servingLabel:
            '${_servingSizeController.text.isEmpty ? '1' : _servingSizeController.text} $_selectedServingUnit',
        servingGrams: 100,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        proteinG: double.tryParse(_proteinController.text) ?? 0,
        carbsG: double.tryParse(_carbsController.text) ?? 0,
        fatG: double.tryParse(_fatController.text) ?? 0,
        estimatedPricePhp: 0,
        isLocalFood: !_isPublic,
      );

      await ref.read(customFoodProvider(data).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.textPrimary, size: 18),
                SizedBox(width: 8),
                Text('Custom food saved successfully!'),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Custom Food'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _onSave,
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Create your own food and add nutrition info.\nAll fields are required.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            const _SectionHeader(number: '1', title: 'Basic Information'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _foodNameController,
                    decoration: const InputDecoration(
                      labelText: 'Food Name',
                      hintText: 'e.g., High Protein Smoothie',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => _requiredValidator(v, 'Food name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: ref.watch(categoriesProvider).map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v),
                          validator: (v) =>
                              v == null ? 'Category is required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _servingSizeController,
                          decoration: const InputDecoration(
                            labelText: 'Serving Size',
                            hintText: 'e.g., 1 cup',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              _requiredValidator(v, 'Serving size'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedServingUnit,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 16),
                          ),
                          items: _servingUnits.map((u) {
                            return DropdownMenuItem(value: u, child: Text(u));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null)
                              setState(() => _selectedServingUnit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      hintText:
                          'Add notes about ingredients, brand, or how it\'s made',
                      counterText: '${_descriptionController.text.length}/150',
                    ),
                    maxLength: 150,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const _SectionHeader(
                number: '2', title: 'Nutrition Information (per serving)'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Enter values for one serving. You can edit serving size when logging.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _NutritionGrid(
                      controllers: {
                        'Calories': _caloriesController,
                        'Protein': _proteinController,
                        'Carbs': _carbsController,
                        'Total Fat': _fatController,
                        'Fiber': _fiberController,
                        'Sugars': _sugarsController,
                        'Sodium': _sodiumController,
                        'Cholesterol': _cholesterolController,
                        'Saturated Fat': _saturatedFatController,
                      },
                      units: const {
                        'Calories': 'kcal',
                        'Protein': 'g',
                        'Carbs': 'g',
                        'Total Fat': 'g',
                        'Fiber': 'g',
                        'Sugars': 'g',
                        'Sodium': 'mg',
                        'Cholesterol': 'mg',
                        'Saturated Fat': 'g',
                      },
                      icons: const {
                        'Calories': Icons.local_fire_department,
                        'Protein': Icons.fitness_center,
                        'Carbs': Icons.grain,
                        'Total Fat': Icons.opacity,
                        'Fiber': Icons.grass,
                        'Sugars': Icons.cake,
                        'Sodium': Icons.water_drop,
                        'Cholesterol': Icons.circle,
                        'Saturated Fat': Icons.circle,
                      },
                      colors: const {
                        'Calories': AppColors.calorieColor,
                        'Protein': AppColors.proteinColor,
                        'Carbs': AppColors.carbsColor,
                        'Total Fat': AppColors.fatColor,
                        'Fiber': AppColors.textSecondary,
                        'Sugars': AppColors.textSecondary,
                        'Sodium': AppColors.textSecondary,
                        'Cholesterol': AppColors.textSecondary,
                        'Saturated Fat': AppColors.textSecondary,
                      },
                    ),
                  ],
                ),
              ),
            ),
            const _SectionHeader(number: '3', title: 'Additional Settings'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Card(
                    child: SwitchListTile(
                      title: const Text('Make this food public'),
                      subtitle:
                          const Text('Allow others to see and use this food'),
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      secondary: Icon(
                        _isPublic ? Icons.public : Icons.lock,
                        color: _isPublic
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Save to my foods'),
                      subtitle:
                          const Text('Save food to your custom food list'),
                      value: _saveToMyFoods,
                      onChanged: (v) => setState(() => _saveToMyFoods = v),
                      secondary: Icon(
                        _saveToMyFoods ? Icons.bookmark : Icons.bookmark_border,
                        color: _saveToMyFoods
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 18, color: AppColors.textPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Custom foods are saved locally and will sync when you\'re back online.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onSave,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Custom Food'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
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

class _NutritionGrid extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, String> units;
  final Map<String, IconData> icons;
  final Map<String, Color> colors;

  const _NutritionGrid({
    required this.controllers,
    required this.units,
    required this.icons,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final keys = controllers.keys.toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: keys.map((key) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 88) / 3,
          child: _NutritionInput(
            label: key,
            unit: units[key] ?? '',
            icon: icons[key] ?? Icons.circle,
            color: colors[key] ?? AppColors.textSecondary,
            controller: controllers[key]!,
          ),
        );
      }).toList(),
    );
  }
}

class _NutritionInput extends StatelessWidget {
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final TextEditingController controller;

  const _NutritionInput({
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
            const Spacer(),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
