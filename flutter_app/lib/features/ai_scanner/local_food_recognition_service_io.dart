import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class LocalDishRecognition {
  final String modelLabel;
  final String foodName;
  final double confidence;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double estimatedCostPhp;

  const LocalDishRecognition({
    required this.modelLabel,
    required this.foodName,
    required this.confidence,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimatedCostPhp,
  });

  LocalDishRecognition withConfidence(double value) => LocalDishRecognition(
        modelLabel: modelLabel,
        foodName: foodName,
        confidence: value,
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        estimatedCostPhp: estimatedCostPhp,
      );
}

class LocalFoodRecognitionService {
  static const modelPath = 'assets/models/two_dish_classifier.tflite';
  static const labelsPath = 'assets/models/two_dish_labels.txt';
  static const inputSize = 224;
  static const modelName = 'jcg_two_dish_classifier';
  // The two-class prototype has no unknown-food class, so use a conservative
  // auto-accept gate until the expanded model is trained with negatives.
  static const confidentThreshold = 0.95;
  static const confidentMarginThreshold = 0.20;

  static const _dishProfiles = <String, LocalDishRecognition>{
    'chicken_adobo': LocalDishRecognition(
      modelLabel: 'chicken_adobo',
      foodName: 'Chicken Adobo',
      confidence: 0,
      calories: 430,
      proteinG: 35,
      carbsG: 8,
      fatG: 28,
      estimatedCostPhp: 65,
    ),
    'sinigang': LocalDishRecognition(
      modelLabel: 'sinigang',
      foodName: 'Sinigang na Baboy',
      confidence: 0,
      calories: 380,
      proteinG: 22,
      carbsG: 15,
      fatG: 26,
      estimatedCostPhp: 65,
    ),
  };

  Interpreter? _interpreter;
  List<String>? _labels;

  static bool isConfident(List<LocalDishRecognition> results) {
    if (results.isEmpty || results.first.confidence < confidentThreshold) {
      return false;
    }
    final runnerUp = results.length > 1 ? results[1].confidence : 0.0;
    return results.first.confidence - runnerUp >= confidentMarginThreshold;
  }

  Future<List<LocalDishRecognition>> recognizeFile(String imagePath) async {
    await _ensureInitialized();
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported or damaged image');
    }

    final oriented = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      oriented,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
    final imageMatrix = List.generate(
      inputSize,
      (y) => List.generate(
        inputSize,
        (x) {
          final pixel = resized.getPixel(x, y);
          return <double>[
            pixel.r.toDouble(),
            pixel.g.toDouble(),
            pixel.b.toDouble(),
          ];
        },
        growable: false,
      ),
      growable: false,
    );
    final output = <List<double>>[
      List<double>.filled(_labels!.length, 0),
    ];
    _interpreter!.run([imageMatrix], output);

    final results = <LocalDishRecognition>[];
    for (var index = 0; index < _labels!.length; index++) {
      final label = _labels![index];
      final profile = _dishProfiles[label];
      if (profile == null) continue;
      results.add(
        profile.withConfidence(output.first[index].clamp(0.0, 1.0).toDouble()),
      );
    }
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  Future<void> _ensureInitialized() async {
    if (_interpreter != null && _labels != null) return;
    final labelsText = await rootBundle.loadString(labelsPath);
    final labels = labelsText
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (labels.length != _dishProfiles.length ||
        labels.any((label) => !_dishProfiles.containsKey(label))) {
      throw StateError('Two-dish model labels do not match app profiles');
    }

    final options = InterpreterOptions()..threads = 2;
    final interpreter =
        await Interpreter.fromAsset(modelPath, options: options);
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (inputShape.length != 4 ||
        inputShape[1] != inputSize ||
        inputShape[2] != inputSize ||
        inputShape[3] != 3 ||
        outputShape.length != 2 ||
        outputShape[1] != labels.length) {
      interpreter.close();
      throw StateError(
        'Unexpected two-dish model shape: input=$inputShape output=$outputShape',
      );
    }
    _labels = labels;
    _interpreter = interpreter;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
  }
}
