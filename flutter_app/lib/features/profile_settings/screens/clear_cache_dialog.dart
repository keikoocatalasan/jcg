import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/database/community_cache_repository.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';

class ClearCacheDialog extends StatefulWidget {
  const ClearCacheDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ClearCacheDialog(),
    );
  }

  @override
  State<ClearCacheDialog> createState() => _ClearCacheDialogState();
}

class _ClearCacheDialogState extends State<ClearCacheDialog> {
  bool _isClearing = false;
  double _cacheSizeMB = 0;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync();
        for (final entity in entities) {
          try {
            if (entity is File) {
              totalBytes += entity.lengthSync();
            } else if (entity is Directory) {
              totalBytes += await _dirSize(entity);
            }
          } catch (_) {}
        }
      }
      final dbDir = await getApplicationDocumentsDirectory();
      final dbPath = '${dbDir.path}/cache/community_cache.db';
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        totalBytes += dbFile.lengthSync();
      }
      if (mounted) {
        setState(() => _cacheSizeMB = totalBytes / (1024 * 1024));
      }
    } catch (_) {}
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        try {
          if (entity is File) {
            total += entity.lengthSync();
          } else if (entity is Directory) {
            total += await _dirSize(entity);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);

    try {
      final cacheRepo = CommunityCacheRepository(DatabaseProvider());
      await cacheRepo.clear();

      try {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          final entities = tempDir.listSync();
          for (final entity in entities) {
            try {
              if (entity is File) {
                entity.deleteSync();
              } else if (entity is Directory) {
                entity.deleteSync(recursive: true);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Clear Cache?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will remove temporary files and free up ${_cacheSizeMB.toStringAsFixed(1)} MB of space.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            "This won't delete your logs or account data.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: _isClearing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isClearing ? null : _clearCache,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.textPrimary,
          ),
          child: _isClearing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textPrimary),
                )
              : const Text('Clear Cache'),
        ),
      ],
    );
  }
}
