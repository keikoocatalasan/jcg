import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/admin/admin_provider.dart';
import 'package:jcg_fitness/features/food_database/food_provider.dart';

class AdminFoodFormScreen extends ConsumerStatefulWidget {
  final Food? existingFood;

  const AdminFoodFormScreen({super.key, this.existingFood});

  @override
  ConsumerState<AdminFoodFormScreen> createState() =>
      _AdminFoodFormScreenState();
}

class _AdminFoodFormScreenState extends ConsumerState<AdminFoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _servingLabelController = TextEditingController();
  final _servingGramsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedCategory;
  bool _isActive = true;
  bool _isLocalFood = false;
  bool _isLoading = false;

  bool get _isEditing => widget.existingFood != null;

  @override
  void initState() {
    super.initState();
    final food = widget.existingFood;
    if (food != null) {
      _foodNameController.text = food.foodName;
      _subcategoryController.text = food.subcategory ?? '';
      _descriptionController.text = food.description ?? '';
      _servingLabelController.text = food.servingLabel ?? '1 serving';
      _servingGramsController.text =
          food.servingGrams?.toStringAsFixed(1) ?? '';
      _caloriesController.text = food.calories.toStringAsFixed(1);
      _proteinController.text = food.proteinG.toStringAsFixed(1);
      _carbsController.text = food.carbsG.toStringAsFixed(1);
      _fatController.text = food.fatG.toStringAsFixed(1);
      _priceController.text = food.estimatedPricePhp.toStringAsFixed(2);
      _selectedCategory = food.categoryName;
      _isActive = food.isActive;
      _isLocalFood = food.isLocalFood;
    } else {
      _servingLabelController.text = '1 serving';
    }
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _subcategoryController.dispose();
    _servingLabelController.dispose();
    _servingGramsController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? v, String label) =>
      v == null || v.trim().isEmpty ? '$label is required' : null;

  String? _positiveNumberValidator(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Negative values not allowed';
    return null;
  }

  String? _gramsValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Serving grams is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return 'Must be greater than 0';
    return null;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      if (supabase.auth.currentSession == null) {
        throw Exception('Not authenticated');
      }

      final foodId =
          _isEditing ? widget.existingFood!.foodId : UuidHelper.generateUuid();
      final servingId = _isEditing
          ? (widget.existingFood!.servingId ?? UuidHelper.generateUuid())
          : UuidHelper.generateUuid();

      final servingGrams = double.tryParse(_servingGramsController.text) ?? 0;
      final calories = double.tryParse(_caloriesController.text) ?? 0;
      final protein = double.tryParse(_proteinController.text) ?? 0;
      final carbs = double.tryParse(_carbsController.text) ?? 0;
      final fat = double.tryParse(_fatController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0;

      // Admin catalog writes go through the audited, atomic RPC. This keeps
      // the console usable on web, where the consumer SQLite cache is not
      // available, and prevents partially-written food records.
      await supabase.rpc('admin_upsert_food', params: {
        'p_food_id': foodId,
        'p_category_name': _selectedCategory!,
        'p_subcategory': _subcategoryController.text.trim().isEmpty
            ? null
            : _subcategoryController.text.trim(),
        'p_description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'p_food_name': _foodNameController.text.trim(),
        'p_normalized_name': _foodNameController.text.trim().toLowerCase(),
        'p_is_local_food': _isLocalFood,
        'p_is_official': true,
        'p_is_active': _isActive,
        'p_serving_id': servingId,
        'p_serving_label': _servingLabelController.text.trim(),
        'p_serving_grams': servingGrams,
        'p_calories': calories,
        'p_protein_g': protein,
        'p_carbs_g': carbs,
        'p_fat_g': fat,
        'p_price_php': price,
      });

      ref.invalidate(pagedAdminFoodsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Food updated' : 'Food created')),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Food' : 'Add Food'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Price history',
              onPressed: () => context.push(
                '/admin/foods/price-history',
                extra: {
                  'foodId': widget.existingFood!.foodId,
                  'foodName': widget.existingFood!.foodName,
                  'currentPrice': widget.existingFood!.estimatedPricePhp,
                },
              ),
              icon: const Icon(Icons.history),
            ),
          TextButton.icon(
            onPressed: _isLoading ? null : _onSave,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Basic Info', Icons.info_outline),
            TextFormField(
              controller: _foodNameController,
              decoration: const InputDecoration(
                labelText: 'Food Name *',
                prefixIcon: Icon(Icons.restaurant),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => _requiredValidator(v, 'Food name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                prefixIcon: Icon(Icons.category),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              validator: (v) => v == null ? 'Category is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subcategoryController,
              decoration: const InputDecoration(
                labelText: 'Subcategory',
                prefixIcon: Icon(Icons.subdirectory_arrow_right),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Serving Unit *',
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (v) => _requiredValidator(v, 'Serving label'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingGramsController,
                    decoration: const InputDecoration(
                      labelText: 'Serving (g) *',
                      prefixIcon: Icon(Icons.scale),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _gramsValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive foods are hidden from users'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const Divider(height: 32),
            _buildSectionHeader('Nutrition', Icons.local_fire_department),
            TextFormField(
              controller: _caloriesController,
              decoration: const InputDecoration(
                labelText: 'Calories *',
                prefixIcon: Icon(Icons.local_fire_department),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => _positiveNumberValidator(v, 'Calories'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _proteinController,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g) *',
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => _positiveNumberValidator(v, 'Protein'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _carbsController,
                    decoration: const InputDecoration(
                      labelText: 'Carbs (g) *',
                      prefixIcon: Icon(Icons.grain),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => _positiveNumberValidator(v, 'Carbs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fatController,
              decoration: const InputDecoration(
                labelText: 'Fat (g) *',
                prefixIcon: Icon(Icons.opacity),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => _positiveNumberValidator(v, 'Fat'),
            ),
            const Divider(height: 32),
            _buildSectionHeader('Price', Icons.monetization_on),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (PHP) *',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => _positiveNumberValidator(v, 'Price'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text('Official catalog item'),
                    subtitle: Text(
                        'Admin entries are published to the official food catalog.'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Local Food'),
                    subtitle: const Text('Mark as locally sourced food'),
                    value: _isLocalFood,
                    onChanged: (v) => setState(() => _isLocalFood = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
