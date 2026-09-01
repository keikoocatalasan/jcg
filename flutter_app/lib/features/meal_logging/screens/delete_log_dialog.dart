import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

class DeleteLogDialog extends StatelessWidget {
  final String foodName;
  final VoidCallback onConfirm;

  const DeleteLogDialog({
    super.key,
    required this.foodName,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required String foodName,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteLogDialog(
        foodName: foodName,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Log'),
      content: Text(
        'Are you sure you want to delete the log for "$foodName"? '
        'This will be synced across devices.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
