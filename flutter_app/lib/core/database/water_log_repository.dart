import 'base_repository.dart';

class WaterLog {
  final String waterLogId;
  final String userId;
  final int amountMl;
  final String loggedAt;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;

  const WaterLog({
    required this.waterLogId,
    required this.userId,
    required this.amountMl,
    required this.loggedAt,
    this.syncStatus = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory WaterLog.fromMap(Map<String, dynamic> map) {
    return WaterLog(
      waterLogId: map['water_log_id'] as String,
      userId: map['user_id'] as String,
      amountMl: map['amount_ml'] as int,
      loggedAt: map['logged_at'] as String,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'water_log_id': waterLogId,
      'user_id': userId,
      'amount_ml': amountMl,
      'logged_at': loggedAt,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class WaterLogRepository extends BaseRepository<WaterLog> {
  WaterLogRepository(super.dbProvider);

  @override
  String get tableName => 'water_logs';

  @override
  String get pkColumn => 'water_log_id';

  @override
  WaterLog fromMap(Map<String, dynamic> map) => WaterLog.fromMap(map);

  @override
  Map<String, dynamic> toMap(WaterLog entity) => entity.toMap();

  Future<List<WaterLog>> queryByUserAndDate(
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

  Future<List<WaterLog>> queryByUserAndDateRange(
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

  Future<List<WaterLog>> queryTodayByUser(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where:
          "user_id = ? AND date(logged_at, 'localtime') = date('now', 'localtime')",
      whereArgs: [userId],
    );
    return results.map(fromMap).toList();
  }
}
