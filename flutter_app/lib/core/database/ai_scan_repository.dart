import 'base_repository.dart';

class AiScan {
  final String scanId;
  final String userId;
  final String scanStatusCode;
  final String clientScanId;
  final String? imagePath;
  final String? rawResponseJson;
  final String syncStatus;
  final String? createdAt;
  final String? completedAt;

  AiScan({
    required this.scanId,
    required this.userId,
    required this.scanStatusCode,
    required this.clientScanId,
    this.imagePath,
    this.rawResponseJson,
    required this.syncStatus,
    this.createdAt,
    this.completedAt,
  });
}

class AiScanRepository extends BaseRepository<AiScan> {
  AiScanRepository(super._dbProvider);

  @override
  String get tableName => 'ai_scans';

  @override
  String get pkColumn => 'scan_id';

  @override
  AiScan fromMap(Map<String, dynamic> map) {
    return AiScan(
      scanId: map['scan_id'] as String,
      userId: map['user_id'] as String,
      scanStatusCode: map['scan_status_code'] as String,
      clientScanId: map['client_scan_id'] as String,
      imagePath: map['image_path'] as String?,
      rawResponseJson: map['raw_response_json'] as String?,
      syncStatus: map['sync_status'] as String,
      createdAt: map['created_at'] as String?,
      completedAt: map['completed_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(AiScan entity) {
    return {
      'scan_id': entity.scanId,
      'user_id': entity.userId,
      'scan_status_code': entity.scanStatusCode,
      'client_scan_id': entity.clientScanId,
      'image_path': entity.imagePath,
      'raw_response_json': entity.rawResponseJson,
      'sync_status': entity.syncStatus,
      'created_at': entity.createdAt,
      'completed_at': entity.completedAt,
    };
  }

  Future<AiScan?> readByClientScanId(String userId, String clientScanId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'user_id = ? AND client_scan_id = ?',
      whereArgs: [userId, clientScanId],
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }

  Future<int> updateStatus(String scanId, String status) async {
    final db = await database;
    return db.update(
      tableName,
      {'scan_status_code': status},
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }
}
