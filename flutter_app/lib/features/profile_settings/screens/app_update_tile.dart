import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jcg_fitness/core/network/app_release.dart';

class AppUpdateTile extends StatefulWidget {
  const AppUpdateTile({super.key});

  @override
  State<AppUpdateTile> createState() => _AppUpdateTileState();
}

class _AppUpdateTileState extends State<AppUpdateTile> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();
  bool _checking = false;

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message('Could not open your browser. Please try again.');
      }
    } catch (_) {
      _message('Could not open your browser. Please try again.');
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final info = await _info;
      final current = int.tryParse(info.buildNumber);
      if (current == null) {
        throw const FormatException('Unknown installed build');
      }
      final release = await AppRelease.fetch();
      if (!mounted) return;
      if (release.versionCode <= current) {
        _message('You have the latest published version.');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('JCG Fitness ${release.version} is available'),
          content: Text(
              'Download ${(release.bytes / 1048576).toStringAsFixed(1)} MB. '
              'Open the downloaded APK to update. Keep your existing app installed to preserve its data.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later')),
            TextButton(
                onPressed: () => _open(release.notesUrl),
                child: const Text('Release notes')),
            FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _open(release.downloadUrl);
                },
                child: const Text('Download update')),
          ],
        ),
      );
    } catch (_) {
      _message(
          'Could not check for updates. Check your connection and try again later.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: FutureBuilder<PackageInfo>(
          future: _info,
          builder: (context, snapshot) => ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Check for updates'),
            subtitle: Text(snapshot.hasData
                ? 'Installed ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                : 'JCG Fitness'),
            trailing: _checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _checking ? null : _check,
          ),
        ),
      );
}
