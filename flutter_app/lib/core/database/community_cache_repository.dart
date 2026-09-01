import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';

class CommunityCacheEntry {
  final String postId;
  final String userId;
  final String authorNickname;
  final String bodyText;
  final bool isHidden;
  final bool isDeleted;
  final int likeCount;
  final int commentCount;
  final String createdAt;
  final String updatedAt;
  final String cachedAt;

  CommunityCacheEntry({
    required this.postId,
    required this.userId,
    required this.authorNickname,
    required this.bodyText,
    this.isHidden = false,
    this.isDeleted = false,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.cachedAt,
  });

  CommunityCacheEntry copyWith({
    String? postId,
    String? userId,
    String? authorNickname,
    String? bodyText,
    bool? isHidden,
    bool? isDeleted,
    int? likeCount,
    int? commentCount,
    String? createdAt,
    String? updatedAt,
    String? cachedAt,
  }) {
    return CommunityCacheEntry(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      authorNickname: authorNickname ?? this.authorNickname,
      bodyText: bodyText ?? this.bodyText,
      isHidden: isHidden ?? this.isHidden,
      isDeleted: isDeleted ?? this.isDeleted,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

class CommunityCacheRepository extends BaseRepository<CommunityCacheEntry> {
  CommunityCacheRepository(super.dbProvider);

  @override
  String get tableName => 'community_cache';

  @override
  String get pkColumn => 'post_id';

  @override
  CommunityCacheEntry fromMap(Map<String, dynamic> map) {
    return CommunityCacheEntry(
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      authorNickname: map['author_nickname'] as String,
      bodyText: map['body_text'] as String,
      isHidden: (map['is_hidden'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
      likeCount: map['like_count'] as int,
      commentCount: map['comment_count'] as int,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      cachedAt: map['cached_at'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(CommunityCacheEntry entity) {
    return {
      'post_id': entity.postId,
      'user_id': entity.userId,
      'author_nickname': entity.authorNickname,
      'body_text': entity.bodyText,
      'is_hidden': entity.isHidden ? 1 : 0,
      'is_deleted': entity.isDeleted ? 1 : 0,
      'like_count': entity.likeCount,
      'comment_count': entity.commentCount,
      'created_at': entity.createdAt,
      'updated_at': entity.updatedAt,
      'cached_at': entity.cachedAt,
    };
  }

  Future<List<CommunityCacheEntry>> readAllVisible() async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'is_hidden = 0 AND is_deleted = 0',
      orderBy: 'created_at DESC',
    );
    return results.map(fromMap).toList();
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete(tableName);
  }

  Future<void> upsert(CommunityCacheEntry entry) async {
    final db = await database;
    await db.insert(
      tableName,
      toMap(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<CommunityCacheEntry>> queryPendingSync() async {
    return [];
  }

  @override
  Future<int> updateSyncStatus(String id, String status,
      {String? serverSyncedAt}) async {
    return 0;
  }
}
