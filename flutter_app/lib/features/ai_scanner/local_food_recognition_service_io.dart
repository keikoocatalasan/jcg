import 'dart:convert';

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class LocalDishRecognition {
  final String modelLabel;
  final String foodName;
  final double confidence;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? estimatedCostPhp;
  final double? servingGrams;

  const LocalDishRecognition({
    required this.modelLabel,
    required this.foodName,
    required this.confidence,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimatedCostPhp,
    this.servingGrams,
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
        servingGrams: servingGrams,
      );
}

class LocalFoodRecognitionService {
  static const modelPath = 'assets/models/filifood5_pilot_v1.tflite';
  static const labelsPath = 'assets/models/filifood5_pilot_v1_labels.txt';
  static const fallbackModelPath = 'assets/models/two_dish_classifier.tflite';
  static const fallbackLabelsPath = 'assets/models/two_dish_labels.txt';
  static const expandedModelPath = 'assets/models/filifood100_v1.tflite';
  static const expandedLabelsPath = 'assets/models/filifood100_labels.txt';
  static const expandedDisplayNamesPath =
      'assets/models/filifood100_display_names.json';
  static const pilotDisplayNamesPath =
      'assets/models/filifood5_pilot_v1_display_names.json';
  static const inputSize = 224;
  static const modelName = 'jcg_filifood5_pilot';
  static const modelVersion = 'filifood5-pilot-v1';
  // The pilot contains an unknown class, but keep a conservative auto-accept
  // gate until it is validated on fresh phone-camera captures.
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
      servingGrams: null,
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
      servingGrams: null,
    ),
  };

  Interpreter? _interpreter;
  List<String>? _labels;
  Map<String, String> _displayNames = const {};

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
    return recognizeBytes(bytes);
  }

  Future<List<LocalDishRecognition>> recognizeBytes(Uint8List bytes) async {
    await _ensureInitialized();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported or damaged image');
    }

    return _recognizeDecodedImage(decoded);
  }

  List<LocalDishRecognition> _recognizeDecodedImage(img.Image decoded) {
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
      final profile = _dishProfiles[label] ??
          LocalDishRecognition(
            modelLabel: label,
            foodName: _displayNames[label] ?? _displayNameFromLabel(label),
            confidence: 0,
            calories: null,
            proteinG: null,
            carbsG: null,
            fatG: null,
            estimatedCostPhp: null,
          );
      results.add(
        profile.withConfidence(output.first[index].clamp(0.0, 1.0).toDouble()),
      );
    }
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  Future<void> _ensureInitialized() async {
    if (_interpreter != null && _labels != null) return;
    var selectedModelPath = modelPath;
    var selectedLabelsPath = labelsPath;
    try {
      await rootBundle.load(expandedModelPath);
      await rootBundle.loadString(expandedLabelsPath);
      selectedModelPath = expandedModelPath;
      selectedLabelsPath = expandedLabelsPath;
      try {
        final displayNamesJson =
            await rootBundle.loadString(expandedDisplayNamesPath);
        final decoded = jsonDecode(displayNamesJson);
        if (decoded is Map) {
          _displayNames = {
            for (final entry in decoded.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          };
        }
      } catch (_) {
        _displayNames = const {};
      }
    } catch (_) {
      try {
        final pilotDisplayNamesJson =
            await rootBundle.loadString(pilotDisplayNamesPath);
        final decoded = jsonDecode(pilotDisplayNamesJson);
        if (decoded is Map) {
          _displayNames = {
            for (final entry in decoded.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          };
        }
      } catch (_) {
        // Keep the two-dish asset as a final fallback if a pilot build is
        // rolled back or an older install has not received the new assets.
        selectedModelPath = fallbackModelPath;
        selectedLabelsPath = fallbackLabelsPath;
        _displayNames = const {};
      }
    }

    final labelsText = await rootBundle.loadString(selectedLabelsPath);
    final labels = labelsText
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (labels.isEmpty) {
      throw StateError('Food model has no labels');
    }

    final options = InterpreterOptions()..threads = 2;
    final interpreter =
        await Interpreter.fromAsset(selectedModelPath, options: options);
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
        'Unexpected food model shape: input=$inputShape output=$outputShape',
      );
    }
    _labels = labels;
    _interpreter = interpreter;
  }

  static String _displayNameFromLabel(String label) {
    return label
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
    _displayNames = const {};
  }
}
