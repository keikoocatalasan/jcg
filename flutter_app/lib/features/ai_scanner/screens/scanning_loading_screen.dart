import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http_parser/http_parser.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/food_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/prediction_result_screen.dart';
import 'package:jcg_fitness/app/theme.dart';

class ScanningLoadingScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String mealType;

  const ScanningLoadingScreen({
    super.key,
    required this.imagePath,
    required this.mealType,
  });

  @override
  ConsumerState<ScanningLoadingScreen> createState() =>
      _ScanningLoadingScreenState();
}

class _ScanningLoadingScreenState extends ConsumerState<ScanningLoadingScreen> {
  String? _error;
  bool _isScanning = true;
  bool _isCancelled = false;
  int _currentStep = 0;
  Timer? _stepTimer1;
  Timer? _stepTimer2;

  static const _stepLabels = [
    'Detecting food items',
    'Extracting features',
    'Running AI model',
    'Generating results',
  ];

  @override
  void initState() {
    super.initState();
    _startStepProgress();
    _performScan();
  }

  @override
  void dispose() {
    _stepTimer1?.cancel();
    _stepTimer2?.cancel();
    super.dispose();
  }

  void _startStepProgress() {
    _stepTimer1 = Timer(const Duration(seconds: 1), () {
      if (mounted && !_isCancelled) setState(() => _currentStep = 1);
    });
    _stepTimer2 = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isCancelled) setState(() => _currentStep = 2);
    });
  }

  void _cancelScan() {
    setState(() {
      _isCancelled = true;
      _isScanning = false;
      _error = null;
    });
    _stepTimer1?.cancel();
    _stepTimer2?.cancel();
  }

  Future<void> _performScan() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    final online = ref.read(isOnlineProvider);
    if (!online) {
      setState(() {
        _error = 'Internet connection required to scan food';
        _isScanning = false;
      });
      return;
    }

    final file = File(widget.imagePath);
    if (!file.existsSync()) {
      setState(() {
        _error = 'Image file not found';
        _isScanning = false;
      });
      return;
    }

    final clientScanId = UuidHelper.generateUuid();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      const baseUrl = AppConfig.fastApiBaseUrl;
      final uri = Uri.parse('$baseUrl/ai/scan-food');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.fields['client_scan_id'] = clientScanId;
      request.fields['meal_type'] = widget.mealType;
      final ext = widget.imagePath.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? MediaType('image', 'png')
          : ext == 'webp'
              ? MediaType('image', 'webp')
              : MediaType('image', 'jpeg');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          widget.imagePath,
          contentType: mimeType,
        ),
      );

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final scanResult = await _matchCatalogFoods(ScanResult.fromJson(body));

        final db = await DatabaseProvider().database;
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final profiles = await db.query(
            'profiles',
            where: 'auth_user_id = ?',
            whereArgs: [user.id],
          );
          if (profiles.isNotEmpty) {
            final userId = profiles.first['user_id'] as String;
            await db.insert(
              'ai_scans',
              {
                'scan_id': scanResult.scanId,
                'user_id': userId,
                'scan_status_code': 'completed',
                'client_scan_id': scanResult.clientScanId,
                'image_path': widget.imagePath,
                'raw_response_json': response.body,
                'sync_status': 'synced',
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'completed_at': DateTime.now().toUtc().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        ref.read(scanResultProvider.notifier).setResult(scanResult);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PredictionResultScreen(
                scanResult: scanResult,
                mealType: widget.mealType,
                clientScanId: scanResult.clientScanId,
              ),
            ),
          );
        }
      } else {
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};
        final detail = body['detail'];
        final rootError = body['error'] as Map<String, dynamic>?;
        final nestedError = detail is Map<String, dynamic>
            ? detail['error'] as Map<String, dynamic>?
            : null;
        final message = rootError?['message'] as String? ??
            (detail is String
                ? detail
                : nestedError?['message'] as String? ??
                    body['message'] as String? ??
                    'Scan failed with status ${response.statusCode}');
        setState(() {
          _error = message;
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: ${e.toString()}';
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scanning Food')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isScanning) ...[
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.eco,
                              size: 40,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Analyzing your food...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take a few seconds',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!isOnline) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off,
                                    size: 16, color: AppColors.textPrimary),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Scanning may take longer on slow connection',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        ...List.generate(_stepLabels.length, (index) {
                          return _buildStepIndicator(index);
                        }),
                      ] else if (_isCancelled) ...[
                        Icon(Icons.cancel_outlined,
                            size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'Scanning Cancelled',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scanning cancelled',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ] else if (_error != null) ...[
                        Icon(Icons.error_outline,
                            size: 64, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'Scan Failed',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getDisplayError(_error!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _performScan,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_isScanning) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelScan,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayError(String error) {
    if (error.contains('Connection error') ||
        error.contains('SocketException') ||
        error.contains('timeout')) {
      return 'Connection lost. Please check your internet.';
    }
    return error;
  }

  Future<ScanResult> _matchCatalogFoods(ScanResult result) async {
    final foods = await FoodRepository(DatabaseProvider()).readActiveOfficial();
    if (foods.isEmpty) return result;
    final matched = result.predictions.map((prediction) {
      final predictionTokens = _foodTokens(prediction.foodName);
      Food? best;
      var bestScore = 0.0;
      for (final food in foods) {
        final foodTokens = _foodTokens(food.normalizedName);
        final union = predictionTokens.union(foodTokens);
        if (union.isEmpty) continue;
        final score =
            predictionTokens.intersection(foodTokens).length / union.length;
        final contains = food.normalizedName.contains(
              prediction.foodName.toLowerCase(),
            ) ||
            prediction.foodName.toLowerCase().contains(food.normalizedName);
        final effectiveScore = contains ? 1.0 : score;
        if (effectiveScore > bestScore) {
          best = food;
          bestScore = effectiveScore;
        }
      }
      if (best == null || bestScore < 0.5) return prediction;
      return prediction.copyWith(
        foodId: best.foodId,
        foodName: best.foodName,
        calories: best.calories,
        proteinG: best.proteinG,
        carbsG: best.carbsG,
        fatG: best.fatG,
        estimatedCostPhp: best.estimatedPricePhp,
      );
    }).toList();
    return result.copyWith(predictions: matched);
  }

  Set<String> _foodTokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 2 && token != 'cooked')
      .toSet();

  Widget _buildStepIndicator(int index) {
    final isCompleted = index < _currentStep;
    final isActive = index == _currentStep && _isScanning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _buildStepCircle(index, isCompleted, isActive),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _stepLabels[index],
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isCompleted
                    ? AppColors.textPrimary
                    : isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int index, bool isCompleted, bool isActive) {
    if (isCompleted) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.textPrimary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: AppColors.surface),
      );
    }

    if (isActive) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.textPrimary,
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
    );
  }
}
