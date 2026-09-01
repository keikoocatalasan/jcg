import 'base_repository.dart';

class ChatSession {
  final String chatSessionId;
  final String userId;
  final String startedAt;
  final String? endedAt;
  final String syncStatus;

  ChatSession({
    required this.chatSessionId,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.syncStatus = 'pending',
  });

  ChatSession copyWith({
    String? chatSessionId,
    String? userId,
    String? startedAt,
    String? endedAt,
    String? syncStatus,
  }) {
    return ChatSession(
      chatSessionId: chatSessionId ?? this.chatSessionId,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ChatSessionRepository extends BaseRepository<ChatSession> {
  ChatSessionRepository(super.dbProvider);

  @override
  String get tableName => 'chat_sessions';

  @override
  String get pkColumn => 'chat_session_id';

  @override
  ChatSession fromMap(Map<String, dynamic> map) {
    return ChatSession(
      chatSessionId: map['chat_session_id'] as String,
      userId: map['user_id'] as String,
      startedAt: map['started_at'] as String,
      endedAt: map['ended_at'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  @override
  Map<String, dynamic> toMap(ChatSession entity) {
    return {
      'chat_session_id': entity.chatSessionId,
      'user_id': entity.userId,
      'started_at': entity.startedAt,
      'ended_at': entity.endedAt,
      'sync_status': entity.syncStatus,
    };
  }

  Future<List<ChatSession>> queryByUser(String userId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'started_at DESC',
    );
    return results.map(fromMap).toList();
  }

  Future<int> endSession(String sessionId) async {
    final db = await database;
    return db.update(
      tableName,
      {'ended_at': DateTime.now().toUtc().toIso8601String()},
      where: 'chat_session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
