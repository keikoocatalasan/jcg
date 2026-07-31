import 'package:sqflite/sqflite.dart';
import 'database_provider.dart';

abstract class BaseRepository<T> {
  final DatabaseProvider _dbProvider;

  BaseRepository(this._dbProvider);

  Future<Database> get database => _dbProvider.database;

  String get tableName;

  String get pkColumn;

  T fromMap(Map<String, dynamic> map);

  Map<String, dynamic> toMap(T entity);

  Future<String> insert(T entity) async {
    final db = await database;
    final map = toMap(entity);
    await db.insert(tableName, map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return map[pkColumn] as String;
  }

  Future<T?> readById(String id) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: '$pkColumn = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }

  Future<int> update(T entity) async {
    final db = await database;
    final map = toMap(entity);
    return db.update(
      tableName,
      map,
      where: '$pkColumn = ?',
      whereArgs: [map[pkColumn]],
    );
  }

  Future<int> delete(String id) async {
    final db = await database;
    return db.delete(
      tableName,
      where: '$pkColumn = ?',
      whereArgs: [id],
    );
  }

  Future<List<T>> queryPendingSync() async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return results.map(fromMap).toList();
  }

  Future<int> updateSyncStatus(String id, String status,
      {String? serverSyncedAt}) async {
    final db = await database;
    final values = <String, dynamic>{'sync_status': status};
    if (serverSyncedAt != null) {
      values['server_synced_at'] = serverSyncedAt;
    }
    return db.update(
      tableName,
      values,
      where: '$pkColumn = ?',
      whereArgs: [id],
    );
  }
}
