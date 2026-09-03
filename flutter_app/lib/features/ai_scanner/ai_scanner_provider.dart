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
  final double? servingGrams;

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
    this.servingGrams,
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
      servingGrams: (json['serving_grams'] as num?)?.toDouble(),
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
    double? servingGrams,
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
      servingGrams: servingGrams ?? this.servingGrams,
    );
  }
}

class ScanComponent {
  final String componentId;
  final String roleCode;
  final String? foodId;
  final String foodName;
  final double confidence;
  final List<String> alternatives;
  final double? referenceGrams;
  final double? grams;
  final String portionMethod;
  final double? portionConfidence;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? estimatedCostPhp;

  const ScanComponent({
    required this.componentId,
    required this.roleCode,
    this.foodId,
    required this.foodName,
    required this.confidence,
    this.alternatives = const [],
    this.referenceGrams,
    this.grams,
    this.portionMethod = 'not_provided',
    this.portionConfidence,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.estimatedCostPhp,
  });

  factory ScanComponent.fromJson(Map<String, dynamic> json) {
    final rawAlternatives = json['alternatives'] ?? json['alternative_names'];
    return ScanComponent(
      componentId: json['component_id'] as String? ?? 'component-unknown',
      roleCode:
          json['role'] as String? ?? json['role_code'] as String? ?? 'unknown',
      foodId: json['food_id'] as String?,
      foodName: json['food_name'] as String? ?? 'Unknown component',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      alternatives: rawAlternatives is List
          ? rawAlternatives.whereType<String>().toList(growable: false)
          : const [],
      referenceGrams:
          (json['reference_grams'] as num? ?? json['serving_grams'] as num?)
              ?.toDouble(),
      grams: (json['grams'] as num?)?.toDouble(),
      portionMethod: json['portion_method'] as String? ?? 'not_provided',
      portionConfidence: (json['portion_confidence'] as num?)?.toDouble(),
      calories: (json['calories'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      estimatedCostPhp: (json['estimated_cost_php'] as num?)?.toDouble(),
    );
  }

  ScanComponent copyWith({
    String? roleCode,
    String? foodId,
    String? foodName,
    double? confidence,
    List<String>? alternatives,
    double? referenceGrams,
    double? grams,
    String? portionMethod,
    double? portionConfidence,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? estimatedCostPhp,
  }) {
    return ScanComponent(
      componentId: componentId,
      roleCode: roleCode ?? this.roleCode,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      confidence: confidence ?? this.confidence,
      alternatives: alternatives ?? this.alternatives,
      referenceGrams: referenceGrams ?? this.referenceGrams,
      grams: grams ?? this.grams,
      portionMethod: portionMethod ?? this.portionMethod,
      portionConfidence: portionConfidence ?? this.portionConfidence,
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
  final List<ScanComponent> components;
  final String status;
  final String pipelineVersion;
  final double? compositionConfidence;
  final bool needsPortionInput;
  final List<String> qualityFlags;
  final List<String> messages;

  const ScanResult({
    required this.scanId,
    required this.clientScanId,
    required this.predictions,
    this.components = const [],
    this.status = 'unknown',
    this.pipelineVersion = 'scanner-v2',
    this.compositionConfidence,
    this.needsPortionInput = false,
    this.qualityFlags = const [],
    this.messages = const [],
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final clientScanId = json['client_scan_id'] as String? ?? '';
    final rawPredictions = (json['predictions'] ??
        json['candidates'] ??
        const <dynamic>[]) as List<dynamic>;
    final rawComponents = json['components'] as List<dynamic>? ?? const [];
    return ScanResult(
      scanId: json['scan_id'] as String? ?? clientScanId,
      clientScanId: clientScanId,
      predictions: rawPredictions
          .map((e) => ScanPrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      components: rawComponents
          .whereType<Map<String, dynamic>>()
          .map(ScanComponent.fromJson)
          .toList(growable: false),
      status: json['status'] as String? ?? 'unknown',
      pipelineVersion: json['pipeline_version'] as String? ?? 'scanner-v2',
      compositionConfidence:
          (json['composition_confidence'] as num?)?.toDouble(),
      needsPortionInput: json['needs_portion_input'] as bool? ?? false,
      qualityFlags: (json['quality_flags'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      messages: (json['messages'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
    );
  }

  ScanResult copyWith({
    List<ScanPrediction>? predictions,
    List<ScanComponent>? components,
    String? status,
    String? pipelineVersion,
    double? compositionConfidence,
    bool? needsPortionInput,
    List<String>? qualityFlags,
    List<String>? messages,
  }) {
    return ScanResult(
      scanId: scanId,
      clientScanId: clientScanId,
      predictions: predictions ?? this.predictions,
      components: components ?? this.components,
      status: status ?? this.status,
      pipelineVersion: pipelineVersion ?? this.pipelineVersion,
      compositionConfidence:
          compositionConfidence ?? this.compositionConfidence,
      needsPortionInput: needsPortionInput ?? this.needsPortionInput,
      qualityFlags: qualityFlags ?? this.qualityFlags,
      messages: messages ?? this.messages,
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
