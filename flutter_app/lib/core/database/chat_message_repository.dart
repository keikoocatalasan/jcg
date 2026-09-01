import 'base_repository.dart';

class ChatMessage {
  final String chatMessageId;
  final String chatSessionId;
  final String roleCode;
  final String safetyStatusCode;
  final String deliveryStatusCode;
  final String messageText;
  final String syncStatus;
  final String createdAt;
  final String? sentAt;

  ChatMessage({
    required this.chatMessageId,
    required this.chatSessionId,
    required this.roleCode,
    this.safetyStatusCode = 'safe',
    this.deliveryStatusCode = 'local_saved',
    required this.messageText,
    this.syncStatus = 'pending',
    required this.createdAt,
    this.sentAt,
  });

  ChatMessage copyWith({
    String? chatMessageId,
    String? chatSessionId,
    String? roleCode,
    String? safetyStatusCode,
    String? deliveryStatusCode,
    String? messageText,
    String? syncStatus,
    String? createdAt,
    String? sentAt,
  }) {
    return ChatMessage(
      chatMessageId: chatMessageId ?? this.chatMessageId,
      chatSessionId: chatSessionId ?? this.chatSessionId,
      roleCode: roleCode ?? this.roleCode,
      safetyStatusCode: safetyStatusCode ?? this.safetyStatusCode,
      deliveryStatusCode: deliveryStatusCode ?? this.deliveryStatusCode,
      messageText: messageText ?? this.messageText,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}

class ChatMessageRepository extends BaseRepository<ChatMessage> {
  ChatMessageRepository(super.dbProvider);

  @override
  String get tableName => 'chat_messages';

  @override
  String get pkColumn => 'chat_message_id';

  @override
  ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      chatMessageId: map['chat_message_id'] as String,
      chatSessionId: map['chat_session_id'] as String,
      roleCode: map['role_code'] as String,
      safetyStatusCode: map['safety_status_code'] as String? ?? 'safe',
      deliveryStatusCode:
          map['delivery_status_code'] as String? ?? 'local_saved',
      messageText: map['message_text'] as String,
      syncStatus: map['sync_status'] as String? ?? 'pending',
      createdAt: map['created_at'] as String,
      sentAt: map['sent_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap(ChatMessage entity) {
    return {
      'chat_message_id': entity.chatMessageId,
      'chat_session_id': entity.chatSessionId,
      'role_code': entity.roleCode,
      'safety_status_code': entity.safetyStatusCode,
      'delivery_status_code': entity.deliveryStatusCode,
      'message_text': entity.messageText,
      'sync_status': entity.syncStatus,
      'created_at': entity.createdAt,
      'sent_at': entity.sentAt,
    };
  }

  Future<List<ChatMessage>> queryBySession(String sessionId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'chat_session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return results.map(fromMap).toList();
  }

  Future<int> updateDeliveryStatus(String messageId, String status) async {
    final db = await database;
    return db.update(
      tableName,
      {'delivery_status_code': status},
      where: 'chat_message_id = ?',
      whereArgs: [messageId],
    );
  }
}
