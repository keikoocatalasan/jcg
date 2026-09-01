import 'base_repository.dart';

class SyncQueueEntry {
  final String syncQueueId;
  final String userId;
  final String operationId;
  final String entityTypeCode;
  final String entityId;
  final String operationCode;
  final String payloadJson;
  final String? changedFieldsJson;
  final int clientSequence;
  final int attemptCount;
  final String? lastError;
  final String? dependsOnEntityType;
  final String? dependsOnEntityId;
  final String syncStatus;
  final String? serverSyncedAt;
  final String createdAt;

  SyncQueueEntry({
    required this.syncQueueId,
    required this.userId,
    required this.operationId,
    required this.entityTypeCode,
    required this.entityId,
    required this.operationCode,
    required this.payloadJson,
    this.changedFieldsJson,
    required this.clientSequence,
    this.attemptCount = 0,
    this.lastError,
    this.dependsOnEntityType,
    this.dependsOnEntityId,
    this.syncStatus = 'pending',
    this.serverSyncedAt,
    required this.createdAt,
  });

  SyncQueueEntry copyWith({
    String? syncQueueId,
    String? userId,
    String? operationId,
    String? entityTypeCode,
    String? entityId,
    String? operationCode,
    String? payloadJson,
    String? changedFieldsJson,
    int? clientSequence,
    int? attemptCount,
    String? lastError,
    String? dependsOnEntityType,
    String? dependsOnEntityId,
    String? syncStatus,
    String? serverSyncedAt,
    String? createdAt,
  }) {
    return SyncQueueEntry(
      syncQueueId: syncQueueId ?? this.syncQueueId,
      userId: userId ?? this.userId,
      operationId: operationId ?? this.operationId,
      entityTypeCode: entityTypeCode ?? this.entityTypeCode,
      entityId: entityId ?? this.entityId,
      operationCode: operationCode ?? this.operationCode,
      payloadJson: payloadJson ?? this.payloadJson,
      changedFieldsJson: changedFieldsJson ?? this.changedFieldsJson,
      clientSequence: clientSequence ?? this.clientSequence,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      dependsOnEntityType: dependsOnEntityType ?? this.dependsOnEntityType,
      dependsOnEntityId: dependsOnEntityId ?? this.dependsOnEntityId,
      syncStatus: syncStatus ?? this.syncStatus,
      serverSyncedAt: serverSyncedAt ?? this.serverSyncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SyncQueueRepository extends BaseRepository<SyncQueueEntry> {
  SyncQueueRepository(super.dbProvider);

  @override
  String get tableName => 'sync_queue';

  @override
  String get pkColumn => 'sync_queue_id';

  @override
  SyncQueueEntry fromMap(Map<String, dynamic> map) {
    return SyncQueueEntry(
      syncQueueId: map['sync_queue_id'] as String,
      userId: map['user_id'] as String,
      operationId: map['operation_id'] as String,
      entityTypeCode: map['entity_type_code'] as String,
      entityId: map['entity_id'] as String,
      operationCode: map['operation_code'] as String,
      payloadJson: map['payload_json'] as String,
      changedFieldsJson: map['changed_fields_json'] as String?,
      clientSequence: map['client_sequence'] as int,
      attemptCount: map['attempt_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
      dependsOnEntityType: map['depends_on_entity_type'] as String?,
      dependsOnEntityId: map['depends_on_entity_id'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
      serverSyncedAt: map['server_synced_at'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(SyncQueueEntry entity) {
    return {
      'sync_queue_id': entity.syncQueueId,
      'user_id': entity.userId,
      'operation_id': entity.operationId,
      'entity_type_code': entity.entityTypeCode,
      'entity_id': entity.entityId,
      'operation_code': entity.operationCode,
      'payload_json': entity.payloadJson,
      'changed_fields_json': entity.changedFieldsJson,
      'client_sequence': entity.clientSequence,
      'attempt_count': entity.attemptCount,
      'last_error': entity.lastError,
      'depends_on_entity_type': entity.dependsOnEntityType,
      'depends_on_entity_id': entity.dependsOnEntityId,
      'sync_status': entity.syncStatus,
      'server_synced_at': entity.serverSyncedAt,
      'created_at': entity.createdAt,
    };
  }

  Future<List<SyncQueueEntry>> readPending() async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'client_sequence ASC',
    );
    return results.map(fromMap).toList();
  }

  Future<List<SyncQueueEntry>> readFailed() async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'sync_status = ?',
      whereArgs: ['failed'],
    );
    return results.map(fromMap).toList();
  }

  Future<int> incrementAttempt(String id, {String? error}) async {
    final db = await database;
    final entry = await readById(id);
    if (entry == null) return 0;
    final values = <String, dynamic>{
      'attempt_count': entry.attemptCount + 1,
    };
    if (error != null) {
      values['last_error'] = error;
    }
    return db.update(
      tableName,
      values,
      where: 'sync_queue_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markSynced(String id, {String? serverSyncedAt}) async {
    final db = await database;
    final values = <String, dynamic>{
      'sync_status': 'synced',
    };
    if (serverSyncedAt != null) {
      values['server_synced_at'] = serverSyncedAt;
    }
    return db.update(
      tableName,
      values,
      where: 'sync_queue_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteByEntity(String entityType, String entityId) async {
    final db = await database;
    return db.delete(
      tableName,
      where: 'entity_type_code = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );
  }

  Future<SyncQueueEntry?> readByOperationId(String operationId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'operation_id = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return fromMap(results.first);
  }
}
