import 'dart:convert';
import 'package:http/http.dart' as http;

class AppRelease {
  final String version;
  final int versionCode;
  final int bytes;
  final Uri downloadUrl;
  final Uri notesUrl;

  const AppRelease(this.version, this.versionCode, this.bytes, this.downloadUrl,
      this.notesUrl);

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final code = json['versionCode'];
    if (json['schemaVersion'] != 1 ||
        json['applicationId'] != 'com.jcg.fitness' ||
        version is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        code is! int ||
        code < 1) {
      throw const FormatException('Invalid release metadata');
    }
    final assets = json['assets'] as List;
    final asset = assets
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['name'] == 'JCG-Fitness.apk');
    final expected =
        'https://github.com/keikoocatalasan/jcg/releases/download/v$version/JCG-Fitness.apk';
    final notes =
        'https://github.com/keikoocatalasan/jcg/releases/tag/v$version';
    if (asset['url'] != expected ||
        json['releaseNotesUrl'] != notes ||
        asset['bytes'] is! int ||
        (asset['bytes'] as int) <= 0) {
      throw const FormatException('Invalid release asset');
    }
    return AppRelease(version, code, asset['bytes'] as int, Uri.parse(expected),
        Uri.parse(notes));
  }

  static Future<AppRelease> fetch() async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(
              'https://github.com/keikoocatalasan/jcg/releases/latest/download/release.json'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const FormatException('Release information unavailable');
      }
      return AppRelease.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }
}
