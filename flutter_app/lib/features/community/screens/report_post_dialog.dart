import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/features/community/community_provider.dart';

const _reasons = [
  'Spam',
  'Hate speech',
  'Harassment',
  'Inappropriate content',
  'Misinformation',
  'Other',
];

Future<ReportPostInput?> showReportPostDialog(
  BuildContext context,
  String postId,
) {
  return showDialog<ReportPostInput>(
    context: context,
    builder: (ctx) => _ReportPostDialog(postId: postId),
  );
}

class _ReportPostDialog extends ConsumerStatefulWidget {
  final String postId;

  const _ReportPostDialog({required this.postId});

  @override
  ConsumerState<_ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends ConsumerState<_ReportPostDialog> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  int _detailsLength = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detailsController.addListener(() {
      setState(() => _detailsLength = _detailsController.text.length);
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _isValid => _selectedReason != null;

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reporting requires an internet connection.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final input = ReportPostInput(
        postId: widget.postId,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
      );
      Navigator.of(context).pop(input);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report this post'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Why are you reporting this post?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
            ),
            const SizedBox(height: 16),
            ..._reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (v) => setState(() => _selectedReason = v),
                  contentPadding: EdgeInsets.zero,
                  visualDensity:
                      const VisualDensity(horizontal: -4, vertical: -2),
                )),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              decoration: InputDecoration(
                labelText: 'Additional details (optional)',
                border: const OutlineInputBorder(),
                counterText: '$_detailsLength/500',
                counterStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
              ),
              maxLength: 500,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid && !_isSubmitting ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentPrimary,
            foregroundColor: AppColors.textOnAccent,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textOnAccent),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
