import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

Future<void> showFoodReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required Food food,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FoodReportForm(food: food),
  );
}

class _FoodReportForm extends ConsumerStatefulWidget {
  final Food food;

  const _FoodReportForm({required this.food});

  @override
  ConsumerState<_FoodReportForm> createState() => _FoodReportFormState();
}

class _FoodReportFormState extends ConsumerState<_FoodReportForm> {
  final _descriptionController = TextEditingController();
  String? _issueType;
  bool _saving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_issueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the issue you found.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(nutritionistServiceProvider).submitFoodReport(
            foodId: widget.food.foodId,
            servingId: widget.food.servingId,
            issueType: _issueType!,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. A nutritionist will review the food data.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report could not be submitted: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Report food data',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Flag incorrect nutrition data for ${widget.food.foodName}. Reports go to admin-approved nutritionists.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _issueType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'What is wrong?',
              border: OutlineInputBorder(),
            ),
            items: nutritionistIssueTypes.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _issueType = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag_outlined),
            label: Text(_saving ? 'Submitting…' : 'Submit report'),
          ),
          const SizedBox(height: 4),
          Text(
            'Your identity is not shown to nutritionists reviewing this report.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
