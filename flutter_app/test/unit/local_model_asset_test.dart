import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jcg_fitness/features/ai_scanner/local_food_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('five-dish pilot model assets are bundled with matching labels',
      () async {
    final model = await rootBundle.load(
      'assets/models/filifood5_pilot_v1.tflite',
    );
    final labels = (await rootBundle.loadString(
      'assets/models/filifood5_pilot_v1_labels.txt',
    ))
        .split('\n')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList();
    final displayNames = jsonDecode(await rootBundle.loadString(
      'assets/models/filifood5_pilot_v1_display_names.json',
    )) as Map<String, dynamic>;

    expect(model.lengthInBytes, greaterThan(4 * 1024 * 1024));
    expect(labels, hasLength(6));
    expect(
        labels,
        containsAll(<String>[
          'chicken_adobo',
          'pork_adobo',
          'sinigang_na_baboy',
          'sinigang_na_hipon',
          'kare_kare',
          'unknown_or_unsupported',
        ]));
    expect(displayNames.keys, containsAll(labels));
  });

  test(
    'pilot model loads and returns one score per label',
    skip: Platform.isWindows
        ? 'TFLite host DLL is not bundled in the Windows test runner.'
        : false,
    () async {
      final service = LocalFoodRecognitionService();
      final image = img.Image(width: 224, height: 224);
      final bytes = img.encodePng(image);

      try {
        final results = await service.recognizeBytes(bytes);
        expect(results, hasLength(6));
        expect(results.first.confidence, inInclusiveRange(0.0, 1.0));
        expect(
            results.map((result) => result.modelLabel), contains('kare_kare'));
      } finally {
        service.close();
      }
    },
  );
}
