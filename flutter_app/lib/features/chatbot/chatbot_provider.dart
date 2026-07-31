import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/config.dart';
import 'package:jcg_fitness/core/database/chat_message_repository.dart' as db;
import 'package:jcg_fitness/core/database/chat_session_repository.dart';
import 'package:jcg_fitness/core/database/database_provider.dart';
import 'package:jcg_fitness/core/database/profile_repository.dart';
import 'package:jcg_fitness/core/database/sync_queue_repository.dart';
import 'package:jcg_fitness/core/errors/result.dart';
import 'package:jcg_fitness/core/network/api_client.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/sync/sync_provider.dart';
import 'package:jcg_fitness/core/utils/uuid_helper.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';

const _fastApiBaseUrl = AppConfig.fastApiBaseUrl;

class ChatMessage {
  final String id;
  final String sessionId;
  final String roleCode;
  final String messageText;
  final String deliveryStatus;
  final String? safetyStatus;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.roleCode,
    required this.messageText,
    required this.deliveryStatus,
    this.safetyStatus,
    required this.createdAt,
  });

  ChatMessage copyWith({
    String? id,
    String? sessionId,
    String? roleCode,
    String? messageText,
    String? deliveryStatus,
    String? safetyStatus,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      roleCode: roleCode ?? this.roleCode,
      messageText: messageText ?? this.messageText,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      safetyStatus: safetyStatus ?? this.safetyStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ChatMessage.fromDb(db.ChatMessage dbMsg) {
    return ChatMessage(
      id: dbMsg.chatMessageId,
      sessionId: dbMsg.chatSessionId,
      roleCode: dbMsg.roleCode,
      messageText: dbMsg.messageText,
      deliveryStatus: dbMsg.deliveryStatusCode,
      safetyStatus:
          dbMsg.safetyStatusCode == 'safe' ? null : dbMsg.safetyStatusCode,
      createdAt: DateTime.parse(dbMsg.createdAt),
    );
  }
}

final chatSessionProvider =
    StateNotifierProvider<ChatSessionNotifier, ChatSession?>((ref) {
  return ChatSessionNotifier(ref);
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, sessionId) async {
  final dbProvider = DatabaseProvider();
  final repo = db.ChatMessageRepository(dbProvider);
  final rows = await repo.queryBySession(sessionId);
  return rows.map(ChatMessage.fromDb).toList();
});

final sendMessageProvider =
    FutureProvider.family<void, String>((ref, message) async {
  final notifier = ref.read(chatSessionProvider.notifier);
  await notifier.doSendMessage(message);
});

class ChatSessionNotifier extends StateNotifier<ChatSession?> {
  ChatSessionNotifier(this._ref) : super(null);

  final Ref _ref;

  late final dbProvider = DatabaseProvider();
  late final chatMsgRepo = db.ChatMessageRepository(dbProvider);
  late final chatSessionRepo = ChatSessionRepository(dbProvider);
  late final syncQueueRepo = SyncQueueRepository(dbProvider);
  late final profileRepo = ProfileRepository(dbProvider);

  Future<void> loadOrCreateSession() async {
    final userId = _getUserId();
    if (userId == null) return;

    final sessions = await chatSessionRepo.queryByUser(userId);
    if (sessions.isNotEmpty) {
      final active = sessions.firstWhere(
        (s) => s.endedAt == null,
        orElse: () => sessions.first,
      );
      state = active;
    } else {
      await _createSession(userId);
    }
  }

  Future<void> _createSession(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final session = ChatSession(
      chatSessionId: UuidHelper.generateUuid(),
      userId: userId,
      startedAt: now,
    );
    await chatSessionRepo.insert(session);
    await _queueSync(session.chatSessionId, 'chat_session', 'create', {
      'chat_session_id': session.chatSessionId,
      'user_id': session.userId,
      'started_at': session.startedAt,
    });
    state = session;
  }

  Future<void> sendMessage(String text) async {
    final session = state;
    if (session == null) await loadOrCreateSession();
    final currentSession = state;
    if (currentSession == null) return;

    final userMsgId = await _saveLocalUserMessage(text, currentSession);
    _ref.invalidate(chatMessagesProvider(currentSession.chatSessionId));

    _sendToApiAndRespond(userMsgId, text, currentSession);
  }

  Future<void> doSendMessage(String text) async {
    final session = state;
    if (session == null) return;
    final userMsgId = await _saveLocalUserMessage(text, session);
    _ref.invalidate(chatMessagesProvider(session.chatSessionId));

    _sendToApiAndRespond(userMsgId, text, session);
  }

  Future<String> _saveLocalUserMessage(String text, ChatSession session) async {
    final userId = _getUserId();
    if (userId == null) return '';

    final now = DateTime.now().toUtc().toIso8601String();
    final userMsgId = UuidHelper.generateUuid();

    final userMsg = db.ChatMessage(
      chatMessageId: userMsgId,
      chatSessionId: session.chatSessionId,
      roleCode: 'user',
      messageText: text,
      deliveryStatusCode: 'local_saved',
      createdAt: now,
    );
    await chatMsgRepo.insert(userMsg);
    await _queueSync(userMsgId, 'chat_message', 'create', {
      'chat_message_id': userMsgId,
      'chat_session_id': session.chatSessionId,
      'role_code': 'user',
      'message_text': text,
      'delivery_status_code': 'local_saved',
      'safety_status_code': 'safe',
      'created_at': now,
    });
    return userMsgId;
  }

  Future<void> _sendToApiAndRespond(
      String userMsgId, String text, ChatSession session) async {
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      await chatMsgRepo.updateDeliveryStatus(userMsgId, 'failed');
      _ref.invalidate(chatMessagesProvider(session.chatSessionId));
      return;
    }

    await chatMsgRepo.updateDeliveryStatus(userMsgId, 'sent_to_api');
    _ref.invalidate(chatMessagesProvider(session.chatSessionId));

    final context = await _buildContext();

    try {
      final result = await _callChatApi(
        session.chatSessionId,
        userMsgId,
        text,
        context,
      );

      switch (result) {
        case Success(data: final response):
          final safetyCode = response['safety_status'] as String? ?? 'safe';
          final replyText = response['reply'] as String? ?? '';
          final assistantNow = DateTime.now().toUtc().toIso8601String();
          final assistantMsgId = response['assistant_message_id'] as String? ??
              UuidHelper.generateUuid();

          final assistantMsg = db.ChatMessage(
            chatMessageId: assistantMsgId,
            chatSessionId: session.chatSessionId,
            roleCode: 'assistant',
            messageText: replyText,
            safetyStatusCode: safetyCode,
            deliveryStatusCode: 'sent_to_api',
            createdAt: assistantNow,
          );
          await chatMsgRepo.insert(assistantMsg);
          await _queueSync(assistantMsgId, 'chat_message', 'create', {
            'chat_message_id': assistantMsgId,
            'chat_session_id': session.chatSessionId,
            'role_code': 'assistant',
            'message_text': replyText,
            'delivery_status_code': 'sent_to_api',
            'safety_status_code': safetyCode,
            'created_at': assistantNow,
          });

        case Failure():
          await chatMsgRepo.updateDeliveryStatus(userMsgId, 'failed');
      }
    } catch (_) {
      await chatMsgRepo.updateDeliveryStatus(userMsgId, 'failed');
    }
    _ref.invalidate(chatMessagesProvider(session.chatSessionId));
    _ref.read(syncProvider.notifier).startSync();
  }

  Future<Result<Map<String, dynamic>>> _callChatApi(
    String sessionId,
    String messageId,
    String message,
    Map<String, dynamic> context,
  ) async {
    final apiClient = _apiClientProvider();
    return apiClient.post('/ai/chat', body: {
      'message': message,
      'chat_session_id': sessionId,
      'client_message_id': messageId,
      'context': context,
    });
  }

  Future<Map<String, dynamic>> _buildContext() async {
    final userId = _getUserId();
    if (userId == null) return {};

    try {
      final profile = await profileRepo.readByUserId(userId);
      if (profile == null) return {};
      return {
        'fitness_goal': profile.fitnessGoalCode,
        'remaining_budget_php': profile.dailyBudgetPhp,
        'allergies': (profile.allergies ?? '')
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      }..removeWhere((_, v) => v == null);
    } catch (_) {
      return {};
    }
  }

  Future<void> _queueSync(
    String entityId,
    String entityType,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final userId = _getUserId();
    if (userId == null) return;

    final sequence = DateTime.now().millisecondsSinceEpoch;
    await syncQueueRepo.insert(SyncQueueEntry(
      syncQueueId: UuidHelper.generateUuid(),
      userId: userId,
      operationId: UuidHelper.generateOperationId(),
      entityTypeCode: entityType,
      entityId: entityId,
      operationCode: operation,
      payloadJson: jsonEncode(payload),
      clientSequence: sequence,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ));
  }

  Future<void> retryFailed(String messageId) async {
    final session = state;
    if (session == null) return;
    final messages = await chatMsgRepo.queryBySession(session.chatSessionId);
    final failed =
        messages.where((message) => message.chatMessageId == messageId);
    if (failed.isEmpty) return;
    final message = failed.first;
    await chatMsgRepo.updateDeliveryStatus(messageId, 'local_saved');
    _ref.invalidate(chatMessagesProvider(session.chatSessionId));
    await _sendToApiAndRespond(
      messageId,
      message.messageText,
      session,
    );
  }

  Future<void> endSession() async {
    final session = state;
    if (session == null) return;
    await chatSessionRepo.endSession(session.chatSessionId);
    state = session.copyWith(
      endedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> switchSession(String sessionId) async {
    final session = await chatSessionRepo.readById(sessionId);
    state = session;
  }

  String? _getUserId() {
    final session = _ref.read(authSessionProvider);
    return session?.user.id;
  }
}

ApiClient _apiClientProvider() {
  return ApiClient(_fastApiBaseUrl);
}
