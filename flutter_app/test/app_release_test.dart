import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/network/app_release.dart';

Map<String, dynamic> metadata() => {
      'schemaVersion': 1,
      'applicationId': 'com.jcg.fitness',
      'version': '1.0.2',
      'versionCode': 3,
      'releaseNotesUrl':
          'https://github.com/keikoocatalasan/jcg/releases/tag/v1.0.2',
      'assets': [
        {
          'name': 'JCG-Fitness.apk',
          'bytes': 100,
          'url':
              'https://github.com/keikoocatalasan/jcg/releases/download/v1.0.2/JCG-Fitness.apk'
        },
      ],
    };

void main() {
  test('reads the build number and universal package', () {
    final release = AppRelease.fromJson(metadata());
    expect(release.versionCode, 3);
    expect(release.version, '1.0.2');
    expect(release.downloadUrl.path, endsWith('/JCG-Fitness.apk'));
  });
  test('compares semantic versions across ABI build-code offsets', () {
    expect(AppRelease.compareVersions('1.0.2', '1.0.1'), greaterThan(0));
    expect(AppRelease.compareVersions('1.0.2', '1.0.2'), 0);
    expect(AppRelease.compareVersions('1.0.1', '1.0.2'), lessThan(0));
  });
  test('rejects another application and unsupported schema', () {
    expect(() => AppRelease.fromJson(metadata()..['applicationId'] = 'other'),
        throwsFormatException);
    expect(() => AppRelease.fromJson(metadata()..['schemaVersion'] = 2),
        throwsFormatException);
  });
  test('rejects external and mismatched-version download links', () {
    for (final url in [
      'https://example.com/JCG-Fitness.apk',
      'https://github.com/keikoocatalasan/jcg/releases/download/v1.0.1/JCG-Fitness.apk'
    ]) {
      final data = metadata();
      (data['assets'] as List).first['url'] = url;
      expect(() => AppRelease.fromJson(data), throwsFormatException);
    }
  });
  test('rejects nonnumeric build numbers and empty packages', () {
    expect(() => AppRelease.fromJson(metadata()..['versionCode'] = '3'),
        throwsFormatException);
    final data = metadata();
    (data['assets'] as List).first['bytes'] = 0;
    expect(() => AppRelease.fromJson(data), throwsFormatException);
  });
}
