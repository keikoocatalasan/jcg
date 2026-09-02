import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jcg_fitness/core/database/ai_scan_feedback_repository.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/features/ai_scanner/local_food_recognition_service.dart';

final localFoodRecognitionServiceProvider =
    Provider<LocalFoodRecognitionService>((ref) {
  final service = LocalFoodRecognitionService();
  ref.onDispose(service.close);
  return service;
});

class ScanPrediction {
  final String? foodId;
  final String foodName;
  final double confidence;
  final int? rankNumber;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? estimatedCostPhp;

  const ScanPrediction({
    this.foodId,
    required this.foodName,
    required this.confidence,
    this.rankNumber,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.estimatedCostPhp,
  });

  factory ScanPrediction.fromJson(Map<String, dynamic> json) {
    return ScanPrediction(
      foodId: json['food_id'] as String?,
      foodName: json['food_name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      rankNumber: (json['rank_number'] as num?)?.toInt(),
      calories: (json['calories'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      estimatedCostPhp: (json['estimated_cost_php'] as num?)?.toDouble(),
    );
  }

  ScanPrediction copyWith({
    String? foodId,
    String? foodName,
    double? confidence,
    int? rankNumber,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? estimatedCostPhp,
  }) {
    return ScanPrediction(
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      confidence: confidence ?? this.confidence,
      rankNumber: rankNumber ?? this.rankNumber,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      estimatedCostPhp: estimatedCostPhp ?? this.estimatedCostPhp,
    );
  }
}

class ScanResult {
  final String scanId;
  final String clientScanId;
  final List<ScanPrediction> predictions;

  const ScanResult({
    required this.scanId,
    required this.clientScanId,
    required this.predictions,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final clientScanId = json['client_scan_id'] as String? ?? '';
    final rawPredictions = (json['predictions'] ??
        json['candidates'] ??
        const <dynamic>[]) as List<dynamic>;
    return ScanResult(
      scanId: json['scan_id'] as String? ?? clientScanId,
      clientScanId: clientScanId,
      predictions: rawPredictions
          .map((e) => ScanPrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  ScanResult copyWith({List<ScanPrediction>? predictions}) {
    return ScanResult(
      scanId: scanId,
      clientScanId: clientScanId,
      predictions: predictions ?? this.predictions,
    );
  }
}

class ScanResultState {
  final bool isLoading;
  final ScanResult? result;
  final String? error;

  const ScanResultState({
    this.isLoading = false,
    this.result,
    this.error,
  });

  ScanResultState copyWith({
    bool? isLoading,
    ScanResult? result,
    String? error,
  }) {
    return ScanResultState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }

  bool get hasResult => result != null && error == null;
}

class ScanResultNotifier extends StateNotifier<ScanResultState> {
  ScanResultNotifier() : super(const ScanResultState());

  void setLoading() {
    state = state.copyWith(isLoading: true, error: null, result: null);
  }

  void setResult(ScanResult result) {
    state = ScanResultState(result: result);
  }

  void setError(String error) {
    state = ScanResultState(error: error);
  }

  void reset() {
    state = const ScanResultState();
  }
}

final scanResultProvider =
    StateNotifierProvider<ScanResultNotifier, ScanResultState>((ref) {
  return ScanResultNotifier();
});

final aiScanFeedbackRepositoryProvider =
    Provider<AiScanFeedbackRepository>((ref) {
  return AiScanFeedbackRepository(DatabaseProvider());
});

class AiScanFeedbackData {
  final String feedbackId;
  final String scanId;
  final String? selectedPredictionIndex;
  final String? mealLogId;
  final String? confirmedFoodId;
  final double? quantity;
  final String? mealTypeCode;
  final String? correctionReason;
  final String? feedbackType;
  final String? confirmedAt;

  AiScanFeedbackData({
    required this.feedbackId,
    required this.scanId,
    this.selectedPredictionIndex,
    this.mealLogId,
    this.confirmedFoodId,
    this.quantity,
    this.mealTypeCode,
    this.correctionReason,
    this.feedbackType,
    this.confirmedAt,
  });
}

const List<String> mealTypeOptions = [
  'breakfast',
  'lunch',
  'dinner',
  'snack',
];

const Map<String, String> mealTypeLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snack',
};
