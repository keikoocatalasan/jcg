import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/widgets/internet_required_widget.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/camera_screen.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/image_preview_screen.dart';

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
  bool _isLoadingSample = false;

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

  Future<void> _openSample(String assetPath) async {
    if (_isLoadingSample) return;
    setState(() => _isLoadingSample = true);
    try {
      final data = await rootBundle.load(assetPath);
      final tempDirectory = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final file = File('${tempDirectory.path}/jcg_demo_$fileName');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(
            imagePath: file.path,
            mealType: _selectedMealType,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open demo image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSample = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Food Scanner')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
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
                'Take a photo or upload an image. The free on-device model recognizes Chicken Adobo and Sinigang.',
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
                            onTap: () =>
                                setState(() => _selectedMealType = type),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              margin: EdgeInsets.only(
                                right: type != mealTypeOptions.last ? 6 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.textPrimary
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  mealTypeLabels[type]!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.surface
                                        : AppColors.textSecondary,
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
              const SizedBox(height: 20),
              Text(
                'Try a sample image',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sampleCard(
                      assetPath: 'assets/images/dishes/chicken_adobo.jpg',
                      label: 'Chicken Adobo',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sampleCard(
                      assetPath: 'assets/images/dishes/sinigang.jpg',
                      label: 'Sinigang',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
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
      ),
    );
  }

  Widget _sampleCard({
    required String assetPath,
    required String label,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isLoadingSample ? null : () => _openSample(assetPath),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(assetPath, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
