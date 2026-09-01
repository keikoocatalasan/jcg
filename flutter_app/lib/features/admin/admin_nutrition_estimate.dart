import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/errors/app_error.dart';
import 'package:jcg_fitness/core/errors/result.dart';
import 'package:jcg_fitness/core/network/api_client.dart';

class AdminNutritionSource {
  final String title;
  final String url;

  const AdminNutritionSource({required this.title, required this.url});

  factory AdminNutritionSource.fromJson(Map<String, dynamic> json) {
    return AdminNutritionSource(
      title: json['title'] as String? ?? 'Source',
      url: json['url'] as String? ?? '',
    );
  }
}

class AdminNutritionEstimate {
  final String estimateId;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final List<String> suggestedMealTypes;
  final double confidence;
  final List<String> warnings;
  final List<AdminNutritionSource> sources;
  final String provider;
  final String model;

  const AdminNutritionEstimate({
    required this.estimateId,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.suggestedMealTypes,
    required this.confidence,
    required this.warnings,
    required this.sources,
    required this.provider,
    required this.model,
  });

  factory AdminNutritionEstimate.fromJson(Map<String, dynamic> json) {
    return AdminNutritionEstimate(
      estimateId: json['estimate_id'] as String,
      calories: (json['calories'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      suggestedMealTypes: (json['suggested_meal_types'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .map((value) => AdminNutritionSource.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList(),
      provider: json['provider'] as String? ?? 'unknown',
      model: json['model'] as String? ?? 'unknown',
    );
  }
}

class AdminNutritionEstimateService {
  Future<Result<AdminNutritionEstimate>> estimate({
    required String foodName,
    required String categoryName,
    required String servingLabel,
    required double servingGrams,
    String? description,
  }) async {
    final client = ApiClient(AppConfig.fastApiBaseUrl);
    try {
      final response = await client.post(
        '/ai/admin/estimate-nutrition',
        body: {
          'food_name': foodName,
          'category_name': categoryName,
          'serving_label': servingLabel,
          'serving_grams': servingGrams,
          'description': description,
        },
      );
      return switch (response) {
        Success(data: final body) => Success(
            AdminNutritionEstimate.fromJson(
              Map<String, dynamic>.from(body['data'] as Map),
            ),
          ),
        Failure(error: final error) => Failure(error),
      };
    } catch (error) {
      return Failure(AppError.unknown(error.toString()));
    } finally {
      client.dispose();
    }
  }
}
