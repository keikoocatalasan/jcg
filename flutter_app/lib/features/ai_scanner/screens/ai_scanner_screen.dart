import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/widgets/internet_required_widget.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/camera_screen.dart';

class AiScannerScreen extends ConsumerWidget {
  const AiScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);

    if (!online) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Food Scanner')),
        body: InternetRequiredWidget(
          featureName: 'AI Food Scanner',
          onGoBack: () => context.pop(),
        ),
      );
    }

    return const _AiScannerContent();
  }
}

class _AiScannerContent extends ConsumerStatefulWidget {
  const _AiScannerContent();

  @override
  ConsumerState<_AiScannerContent> createState() => _AiScannerContentState();
}

class _AiScannerContentState extends ConsumerState<_AiScannerContent> {
  String _selectedMealType = 'breakfast';

  @override
  void initState() {
    super.initState();
    ref.read(scanResultProvider.notifier).reset();
  }

  void _startScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(mealType: _selectedMealType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Food Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(
              Icons.document_scanner,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Food Scanner',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a photo of your food and let AI identify it',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'meal type',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.08,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: mealTypeOptions.map((type) {
                      final isSelected = _selectedMealType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMealType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            margin: EdgeInsets.only(
                              right: type != mealTypeOptions.last ? 6 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.textPrimary : AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected ? AppColors.textPrimary : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                mealTypeLabels[type]!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppColors.surface : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Start Scanning'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
