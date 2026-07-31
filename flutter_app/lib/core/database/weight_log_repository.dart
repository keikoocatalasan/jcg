import 'base_repository.dart';

class WeightLog {
  final String weightLogId;
  final String userId;
  final double weightKg;
  final String loggedAt;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;

  const WeightLog({
    required this.weightLogId,
    required this.userId,
    required this.weightKg,
    required this.loggedAt,
    this.syncStatus = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeightLog.fromMap(Map<String, dynamic> map) {
    return WeightLog(
      weightLogId: map['weight_log_id'] as String,
      userId: map['user_id'] as String,
      weightKg: (map['weight_kg'] as num).toDouble(),
      loggedAt: map['logged_at'] as String,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weight_log_id': weightLogId,
      'user_id': userId,
      'weight_kg': weightKg,
      'logged_at': loggedAt,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class WeightLogRepository extends BaseRepository<WeightLog> {
  WeightLogRepository(super.dbProvider);

  @override
  String get tableName => 'weight_logs';

  @override
  String get pkColumn => 'weight_log_id';

  @override
  WeightLog fromMap(Map<String, dynamic> map) => WeightLog.fromMap(map);

  @override
  Map<String, dynamic> toMap(WeightLog entity) => entity.toMap();

  Future<List<WeightLog>> queryByUserAndDate(
    String userId,
    String date,
  ) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: "user_id = ? AND date(logged_at, 'localtime') = ?",
      whereArgs: [userId, date],
    );
    return results.map(fromMap).toList();
  }

  Future<List<WeightLog>> queryByUserAndDateRange(
    String userId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: "user_id = ? AND date(logged_at, 'localtime') BETWEEN ? AND ?",
      whereArgs: [userId, startDate, endDate],
    );
    return results.map(fromMap).toList();
  }

  Future<WeightLog?> readLatest(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC, created_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }

  Future<WeightLog?> readSecondLatest(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC, created_at DESC',
      limit: 1,
      offset: 1,
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }
}
