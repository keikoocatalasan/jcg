import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistFoodReviewScreen extends ConsumerStatefulWidget {
  final NutritionistCatalogEntry entry;

  const NutritionistFoodReviewScreen({super.key, required this.entry});

  @override
  ConsumerState<NutritionistFoodReviewScreen> createState() =>
      _NutritionistFoodReviewScreenState();
}

class _NutritionistFoodReviewScreenState
    extends ConsumerState<NutritionistFoodReviewScreen> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _noteController = TextEditingController();
  final _sourceNameController = TextEditingController();
  final _sourceReferenceController = TextEditingController();

  String? _reviewId;
  String? _sourceType;
  DateTime? _sourceCheckedAt;
  String _decision = 'verified';
  bool _loading = true;
  bool _saving = false;
  bool _completed = false;
  String? _error;

  NutritionistCatalogEntry get _entry => widget.entry;

  @override
  void initState() {
    super.initState();
    _caloriesController.text = _entry.caloriesPer100g.toStringAsFixed(1);
    _proteinController.text = _entry.proteinPer100g.toStringAsFixed(1);
    _carbsController.text = _entry.carbsPer100g.toStringAsFixed(1);
    _fatController.text = _entry.fatPer100g.toStringAsFixed(1);
    _sourceType = _entry.sourceType;
    _sourceNameController.text = _entry.sourceName ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginReview());
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _noteController.dispose();
    _sourceNameController.dispose();
    _sourceReferenceController.dispose();
    super.dispose();
  }

  Future<void> _beginReview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(nutritionistServiceProvider).beginReview(
            foodId: _entry.foodId,
            servingId: _entry.servingId,
          );
      if (!mounted) return;
      setState(() {
        _reviewId = result['review_id'] as String?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double _doubleValue(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? double.nan;

  List<NutritionReviewWarning> get _warnings => assessPer100gValues(
        calories: _doubleValue(_caloriesController),
        protein: _doubleValue(_proteinController),
        carbs: _doubleValue(_carbsController),
        fat: _doubleValue(_fatController),
      );

  Future<void> _pickSourceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sourceCheckedAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
      helpText: 'Date the source was checked',
    );
    if (picked != null) setState(() => _sourceCheckedAt = picked);
  }

  Future<void> _submit() async {
    final reviewId = _reviewId;
    if (reviewId == null) return;

    final note = _noteController.text.trim();
    if (_decision != 'verified' && note.isEmpty) {
      _showMessage('A review note is required for this decision.');
      return;
    }
    if (_decision == 'verified') {
      if (_sourceType == null || _sourceCheckedAt == null) {
        _showMessage('Record the source type and the date it was checked.');
        return;
      }
      if (_sourceNameController.text.trim().isEmpty &&
          _sourceReferenceController.text.trim().isEmpty) {
        _showMessage('Record a source name or reference.');
        return;
      }
      if ([
        _caloriesController,
        _proteinController,
        _carbsController,
        _fatController
      ].any((controller) => !_doubleValue(controller).isFinite)) {
        _showMessage('Enter valid per-100 g nutrition values.');
        return;
      }
    }

    final confirmed = await _confirm(
      title: _decision == 'verified'
          ? 'Verify this nutrition record?'
          : _decision == 'needs_revision'
              ? 'Request revision?'
              : 'Reject this nutrition record?',
      message: _decision == 'verified'
          ? 'The reviewed values and source will be recorded with your reviewer identity and timestamp.'
          : 'The decision and reason will be recorded with your reviewer identity and timestamp.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final result = await ref.read(nutritionistServiceProvider).submitReview(
            reviewId: reviewId,
            decision: _decision,
            reviewNote: note.isEmpty ? null : note,
            sourceType: _sourceType,
            sourceName: _sourceNameController.text.trim().isEmpty
                ? null
                : _sourceNameController.text.trim(),
            sourceReference: _sourceReferenceController.text.trim().isEmpty
                ? null
                : _sourceReferenceController.text.trim(),
            sourceCheckedAt: _sourceCheckedAt,
            caloriesPer100g: _decision == 'verified'
                ? _doubleValue(_caloriesController)
                : null,
            proteinPer100g: _decision == 'verified'
                ? _doubleValue(_proteinController)
                : null,
            carbsPer100g:
                _decision == 'verified' ? _doubleValue(_carbsController) : null,
            fatPer100g:
                _decision == 'verified' ? _doubleValue(_fatController) : null,
          );
      final warnings = (result['warnings'] as List?) ?? const [];
      ref.invalidate(nutritionistDashboardProvider);
      ref.invalidate(nutritionistCatalogProvider);
      ref.invalidate(nutritionistHistoryProvider);
      ref.invalidate(foodVerificationProvider);
      if (!mounted) return;
      _completed = true;
      Navigator.of(context).pop();
      _showMessage(warnings.isEmpty
          ? 'Review saved.'
          : 'Review saved with ${warnings.length} validation warning(s).');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Review could not be saved: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveFood() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive this food entry?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Archiving hides the food from the catalog and marks its nutrition records archived. History is preserved.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(nutritionistServiceProvider)
          .archiveFood(foodId: _entry.foodId, reason: reason);
      ref.invalidate(nutritionistDashboardProvider);
      ref.invalidate(nutritionistCatalogProvider);
      ref.invalidate(nutritionistHistoryProvider);
      if (!mounted) return;
      _completed = true;
      Navigator.of(context).pop();
      _showMessage('Food archived.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Food could not be archived: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _completed || _reviewId == null || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _reviewId != null && !_saving) {
          _cancelAndPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _entry.foodName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildForm(),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (_reviewId == null || _saving) return false;
    final confirmed = await _confirm(
      title: 'Cancel this review?',
      message:
          'Your draft will be closed and the food will return to its prior review state.',
    );
    if (confirmed != true || !mounted) return false;
    try {
      await ref
          .read(nutritionistServiceProvider)
          .cancelReview(reviewId: _reviewId!);
      ref.invalidate(nutritionistDashboardProvider);
      ref.invalidate(nutritionistCatalogProvider);
      ref.invalidate(nutritionistHistoryProvider);
      return true;
    } catch (error) {
      _showMessage('Review could not be cancelled: $error');
      return false;
    }
  }

  Future<void> _cancelAndPop() async {
    if (await _confirmExit() && mounted) Navigator.of(context).pop();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _beginReview,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _entry.foodName,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_entry.categoryName} · ${_entry.servingLabel} '
                  '(${_entry.servingGrams.toStringAsFixed(0)} g)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current status: ${_entry.verificationLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_entry.verifiedAt != null)
                  Text(
                    'Last verified ${DateFormat('MMM d, yyyy').format(_entry.verifiedAt!.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                if (_entry.sourceName != null)
                  Text(
                    'Recorded source: ${_entry.sourceName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Canonical values per 100 g',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Assess the listed serving and its source, not whether the food is universally healthy. Verified corrections create a new version of the nutrition record and keep history.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ValueField(
                label: 'Calories',
                controller: _caloriesController,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ValueField(
                label: 'Protein (g)',
                controller: _proteinController,
                onChanged: () => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ValueField(
                label: 'Carbs (g)',
                controller: _carbsController,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ValueField(
                label: 'Fat (g)',
                controller: _fatController,
                onChanged: () => setState(() {}),
              ),
            ),
          ],
        ),
        if (_warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: AppColors.warning.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning),
                      const SizedBox(width: 8),
                      Text(
                        'Validation checks',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._warnings.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• ${warning.message}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Source and evidence',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _sourceType,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Source type',
            border: OutlineInputBorder(),
          ),
          items: nutritionistSourceTypes.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged:
              _saving ? null : (value) => setState(() => _sourceType = value),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sourceNameController,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Source name',
            border: OutlineInputBorder(),
          ),
        ),
        TextField(
          controller: _sourceReferenceController,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Source reference (URL, page, or document)',
            border: OutlineInputBorder(),
          ),
        ),
        InkWell(
          onTap: _saving ? null : _pickSourceDate,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Source checked on',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _sourceCheckedAt == null
                  ? 'Choose date checked'
                  : DateFormat('MMM d, yyyy').format(_sourceCheckedAt!),
              style: TextStyle(
                color: _sourceCheckedAt == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Decision',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Verify'),
              selected: _decision == 'verified',
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _decision = 'verified'),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.edit_note_outlined, size: 18),
              label: const Text('Needs revision'),
              selected: _decision == 'needs_revision',
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _decision = 'needs_revision'),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Reject'),
              selected: _decision == 'rejected',
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _decision = 'rejected'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLength: 1200,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: _decision == 'verified'
                ? 'Review note (optional)'
                : 'Review note (required)',
            border: const OutlineInputBorder(),
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
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save review decision'),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _saving ? null : _cancelAndPop,
          child: const Text('Cancel review'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _archiveFood,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
          ),
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archive this food entry'),
        ),
        const SizedBox(height: 4),
        Text(
          'Archive only for invalid or duplicate entries. Nutrition history is preserved; nothing is hard-deleted.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _ValueField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _ValueField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
