import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/confirm_ai_log_screen.dart';

class ManualCorrectionScreen extends ConsumerStatefulWidget {
  final String mealType;
  final String clientScanId;
  final String scanId;

  const ManualCorrectionScreen({
    super.key,
    required this.mealType,
    required this.clientScanId,
    required this.scanId,
  });

  @override
  ConsumerState<ManualCorrectionScreen> createState() =>
      _ManualCorrectionScreenState();
}

class _ManualCorrectionScreenState
    extends ConsumerState<ManualCorrectionScreen> {
  bool _useManualEntry = false;
  bool _isSearching = false;
  List<Food> _searchResults = [];
  final _searchController = TextEditingController();
  Food? _selectedFood;

  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _costController = TextEditingController();
  final _portionController = TextEditingController(text: '1.0');
  final _formKey = GlobalKey<FormState>();
  String _selectedMealType = 'breakfast';

  @override
  void dispose() {
    _searchController.dispose();
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _costController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    FoodRepository(DatabaseProvider())
        .searchByName(query.trim())
        .then((results) {
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isSearching = false);
    });
  }

  void _onFoodSelected(Food food) {
    setState(() {
      _selectedFood = food;
      _useManualEntry = false;
    });
  }

  void _proceedToConfirm() {
    if (_useManualEntry) {
      if (!_formKey.currentState!.validate()) return;

      final foodName = _foodNameController.text.trim();
      final calories = double.tryParse(_caloriesController.text) ?? 0;
      final proteinG = double.tryParse(_proteinController.text) ?? 0;
      final carbsG = double.tryParse(_carbsController.text) ?? 0;
      final fatG = double.tryParse(_fatController.text) ?? 0;
      final cost = double.tryParse(_costController.text) ?? 0;
      final portion = double.tryParse(_portionController.text) ?? 1.0;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmAiLogScreen(
            foodName: foodName,
            calories: calories * portion,
            proteinG: proteinG * portion,
            carbsG: carbsG * portion,
            fatG: fatG * portion,
            estimatedCostPhp: cost,
            mealType: _selectedMealType,
            scanId: widget.scanId,
            clientScanId: widget.clientScanId,
            isManualCorrection: true,
            correctionReason: 'manual_entry',
          ),
        ),
      );
    } else if (_selectedFood != null) {
      final food = _selectedFood!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmAiLogScreen(
            foodName: food.foodName,
            calories: food.calories,
            proteinG: food.proteinG,
            carbsG: food.carbsG,
            fatG: food.fatG,
            estimatedCostPhp: food.estimatedPricePhp,
            mealType: _selectedMealType,
            scanId: widget.scanId,
            clientScanId: widget.clientScanId,
            foodId: food.foodId,
            isManualCorrection: true,
            correctionReason: 'search_selected',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a food or enter nutrition manually'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'You can correct any details before logging',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchSection(theme),
          if (!_useManualEntry && _selectedFood != null) ...[
            const SizedBox(height: 16),
            _buildSelectedFoodCard(theme),
          ],
          const SizedBox(height: 16),
          _buildToggle(theme),
          if (_useManualEntry) ...[
            const SizedBox(height: 16),
            _buildManualForm(theme),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _proceedToConfirm,
              child: const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search food...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _onSearchChanged,
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final food = _searchResults[i];
                return ListTile(
                  dense: true,
                  selected: _selectedFood?.foodId == food.foodId,
                  title: Text(food.foodName),
                  subtitle: Text(
                    '${food.categoryName} \u2022 ${Formatters.formatCalories(food.calories)}',
                  ),
                  trailing: Text(
                    Formatters.formatMacro(food.proteinG),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.proteinColor,
                    ),
                  ),
                  onTap: () => _onFoodSelected(food),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedFoodCard(ThemeData theme) {
    final food = _selectedFood!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.foodName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${food.categoryName} \u2022 ${Formatters.formatCalories(food.calories)} per serving',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _useManualEntry
                    ? 'Enter nutrition details manually'
                    : 'Or enter nutrition details manually',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Switch(
              value: _useManualEntry,
              onChanged: (v) {
                setState(() => _useManualEntry = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nutrition Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Food Name',
                  prefixIcon: Icon(Icons.restaurant),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'This field is required'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _portionController,
                      decoration: const InputDecoration(
                        labelText: 'Portion Size',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'This field is required';
                      }
                      final val = double.tryParse(v);
                      if (val == null) return 'Please enter a valid number';
                      if (val <= 0) return 'Value must be greater than 0';
                      return null;
                    },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'serving',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedMealType,
                decoration: const InputDecoration(
                  labelText: 'Meal Type',
                  prefixIcon: Icon(Icons.access_time),
                ),
                items: mealTypeOptions
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMealType = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  prefixIcon: Icon(Icons.local_fire_department),
                  suffixText: 'kcal',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'This field is required';
                  final val = double.tryParse(v);
                  if (val == null) return 'Please enter a valid number';
                  if (val > 5000) return 'Value seems high. Please review.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'This field is required';
                        }
                        final val = double.tryParse(v);
                        if (val == null) return 'Please enter a valid number';
                        if (val > 500) {
                          return 'Value seems high. Please review.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                        prefixIcon: Icon(Icons.grain),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'This field is required';
                        }
                        final val = double.tryParse(v);
                        if (val == null) return 'Please enter a valid number';
                        if (val > 1000) {
                          return 'Value seems high. Please review.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      decoration: const InputDecoration(
                        labelText: 'Fat (g)',
                        prefixIcon: Icon(Icons.opacity),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'This field is required';
                        }
                        final val = double.tryParse(v);
                        if (val == null) return 'Please enter a valid number';
                        if (val > 500) {
                          return 'Value seems high. Please review.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Est. Cost (PHP)',
                        prefixIcon: Icon(Icons.monetization_on),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'This field is required';
                        }
                        final val = double.tryParse(v);
                        if (val == null) return 'Please enter a valid number';
                        if (val > 10000) {
                          return 'Value seems high. Please review.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
