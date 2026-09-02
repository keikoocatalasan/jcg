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
import 'package:jcg_fitness/features/ai_scanner/local_food_recognition_service.dart';
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
    if (!mounted) return;
    setState(() {
      _isCancelled = false;
      _isScanning = true;
      _error = null;
      _currentStep = 0;
    });

    final file = File(widget.imagePath);
    if (!file.existsSync()) {
      _showError('Image file not found');
      return;
    }

    final clientScanId = UuidHelper.generateUuid();
    ScanResult? localResult;
    Object? localFailure;

    try {
      if (mounted) setState(() => _currentStep = 1);
      localResult = await _recognizeLocally(clientScanId);
      if (_isCancelled) return;
      final topConfidence = localResult.predictions.isEmpty
          ? 0.0
          : localResult.predictions.first.confidence;
      if (topConfidence >= LocalFoodRecognitionService.confidentThreshold) {
        await _completeScan(
          localResult,
          rawResponse: _localResponseJson(localResult),
          syncStatus: 'pending',
        );
        return;
      }
    } catch (e) {
      localFailure = e;
    }

    final online = ref.read(isOnlineProvider);
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (online && token != null && !_isCancelled) {
      try {
        if (mounted) setState(() => _currentStep = 2);
        final cloud = await _requestCloudScan(token, clientScanId);
        await _completeScan(
          cloud.$1,
          rawResponse: cloud.$2,
          syncStatus: 'synced',
        );
        return;
      } catch (cloudError) {
        if (localResult == null) {
          _showError('Cloud scan failed: $cloudError');
          return;
        }
      }
    }

    if (localResult != null && !_isCancelled) {
      await _completeScan(
        localResult,
        rawResponse: _localResponseJson(localResult),
        syncStatus: 'pending',
      );
      return;
    }

    final reason = localFailure == null
        ? 'The on-device model could not analyze this image.'
        : 'On-device recognition failed: $localFailure';
    _showError(reason);
  }

  Future<ScanResult> _recognizeLocally(String clientScanId) async {
    final recognitions = await ref
        .read(localFoodRecognitionServiceProvider)
        .recognizeFile(widget.imagePath);
    return ScanResult(
      scanId: clientScanId,
      clientScanId: clientScanId,
      predictions: [
        for (var index = 0; index < recognitions.length; index++)
          ScanPrediction(
            foodName: recognitions[index].foodName,
            confidence: recognitions[index].confidence,
            rankNumber: index + 1,
            calories: recognitions[index].calories,
            proteinG: recognitions[index].proteinG,
            carbsG: recognitions[index].carbsG,
            fatG: recognitions[index].fatG,
            estimatedCostPhp: recognitions[index].estimatedCostPhp,
          ),
      ],
    );
  }

  Future<(ScanResult, String)> _requestCloudScan(
    String token,
    String clientScanId,
  ) async {
    const baseUrl = AppConfig.fastApiBaseUrl;
    final uri = Uri.parse('$baseUrl/ai/scan-food');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['client_scan_id'] = clientScanId
      ..fields['meal_type'] = widget.mealType;
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_responseError(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (ScanResult.fromJson(body), response.body);
  }

  String _responseError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      final rootError = body['error'] as Map<String, dynamic>?;
      final nestedError = detail is Map<String, dynamic>
          ? detail['error'] as Map<String, dynamic>?
          : null;
      return rootError?['message'] as String? ??
          (detail is String
              ? detail
              : nestedError?['message'] as String? ??
                  body['message'] as String? ??
                  'Scan failed with status ${response.statusCode}');
    } catch (_) {
      return 'Scan failed with status ${response.statusCode}';
    }
  }

  String _localResponseJson(ScanResult result) => jsonEncode({
        'provider': 'tflite_on_device',
        'model': 'jcg_two_dish_classifier',
        'supported_foods': ['Chicken Adobo', 'Sinigang na Baboy'],
        'client_scan_id': result.clientScanId,
        'predictions': [
          for (final prediction in result.predictions)
            {
              'food_name': prediction.foodName,
              'confidence': prediction.confidence,
              'rank_number': prediction.rankNumber,
            },
        ],
      });

  Future<void> _completeScan(
    ScanResult result, {
    required String rawResponse,
    required String syncStatus,
  }) async {
    if (_isCancelled) return;
    if (mounted) setState(() => _currentStep = 3);
    final matchedResult = await _matchCatalogFoods(result);
    await _persistScan(
      matchedResult,
      rawResponse: rawResponse,
      syncStatus: syncStatus,
    );
    if (_isCancelled || !mounted) return;
    ref.read(scanResultProvider.notifier).setResult(matchedResult);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PredictionResultScreen(
          scanResult: matchedResult,
          mealType: widget.mealType,
          clientScanId: matchedResult.clientScanId,
        ),
      ),
    );
  }

  Future<void> _persistScan(
    ScanResult result, {
    required String rawResponse,
    required String syncStatus,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final db = await DatabaseProvider().database;
    final profiles = await db.query(
      'profiles',
      where: 'auth_user_id = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    if (profiles.isEmpty) return;
    final userId = profiles.first['user_id'] as String;
    final now = DateTime.now().toUtc().toIso8601String();
    final topConfidence =
        result.predictions.isEmpty ? 0.0 : result.predictions.first.confidence;
    await db.transaction((txn) async {
      await txn.insert(
        'ai_scans',
        {
          'scan_id': result.scanId,
          'user_id': userId,
          'scan_status_code':
              topConfidence >= 0.60 ? 'completed' : 'low_confidence',
          'client_scan_id': result.clientScanId,
          'image_path': widget.imagePath,
          'raw_response_json': rawResponse,
          'sync_status': syncStatus,
          'created_at': now,
          'completed_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'ai_scan_predictions',
        where: 'scan_id = ?',
        whereArgs: [result.scanId],
      );
      for (var index = 0; index < result.predictions.length; index++) {
        final prediction = result.predictions[index];
        await txn.insert('ai_scan_predictions', {
          'prediction_id': UuidHelper.generateUuid(),
          'scan_id': result.scanId,
          'food_id': prediction.foodId,
          'predicted_food_name': prediction.foodName,
          'confidence': prediction.confidence,
          'rank_number': prediction.rankNumber ?? index + 1,
          'calories': prediction.calories,
          'protein_g': prediction.proteinG,
          'carbs_g': prediction.carbsG,
          'fat_g': prediction.fatG,
          'estimated_cost_php': prediction.estimatedCostPhp,
          'sync_status': syncStatus,
        });
      }
    });
  }

  void _showError(String message) {
    if (!mounted || _isCancelled) return;
    setState(() {
      _error = message;
      _isScanning = false;
    });
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
