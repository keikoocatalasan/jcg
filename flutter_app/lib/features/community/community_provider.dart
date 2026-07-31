import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/core/database/community_cache_repository.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/features/auth/auth_provider.dart';
import 'package:jcg_fitness/features/nutrition/nutrition_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _communityPostTable = 'community_post';
const _communityLikeTable = 'community_like';
const _communityCommentTable = 'community_comment';
const _communityReportTable = 'community_report';

class CommunityPost {
  final String postId;
  final String userId;
  final String authorNickname;
  final String bodyText;
  final int likeCount;
  final int commentCount;
  final String createdAt;
  final String updatedAt;
  final bool isLikedByMe;

  CommunityPost({
    required this.postId,
    required this.userId,
    required this.authorNickname,
    required this.bodyText,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isLikedByMe = false,
  });

  CommunityPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
  }) {
    return CommunityPost(
      postId: postId,
      userId: userId,
      authorNickname: authorNickname,
      bodyText: bodyText,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }

  factory CommunityPost.fromSupabase(Map<String, dynamic> map) {
    return CommunityPost(
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      authorNickname: map['author_nickname'] as String? ?? 'Unknown',
      bodyText: map['body_text'] as String,
      likeCount: (map['like_count'] as num? ?? 0).toInt(),
      commentCount: (map['comment_count'] as num? ?? 0).toInt(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  factory CommunityPost.fromCache(CommunityCacheEntry entry) {
    return CommunityPost(
      postId: entry.postId,
      userId: entry.userId,
      authorNickname: entry.authorNickname,
      bodyText: entry.bodyText,
      likeCount: entry.likeCount,
      commentCount: entry.commentCount,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }
}

class CommunityComment {
  final String commentId;
  final String postId;
  final String userId;
  final String authorNickname;
  final String bodyText;
  final String createdAt;

  CommunityComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.authorNickname,
    required this.bodyText,
    required this.createdAt,
  });

  factory CommunityComment.fromSupabase(Map<String, dynamic> map) {
    return CommunityComment(
      commentId: map['comment_id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      authorNickname: map['author_nickname'] as String? ?? 'Unknown',
      bodyText: map['comment_text'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

class CreateCommentInput {
  final String postId;
  final String bodyText;

  CreateCommentInput({required this.postId, required this.bodyText});
}

class ReportPostInput {
  final String postId;
  final String reason;
  final String? details;

  ReportPostInput({required this.postId, required this.reason, this.details});
}

final communityCacheRepositoryProvider =
    Provider<CommunityCacheRepository>((ref) {
  return CommunityCacheRepository(ref.watch(databaseProvider));
});

Future<Map<String, String>> _loadNicknames(
  SupabaseClient supabase,
  Iterable<String> userIds,
) async {
  final nicknames = <String, String>{};
  for (final userId in userIds.toSet()) {
    final profile = await supabase
        .from('user_profile')
        .select('nickname')
        .eq('user_id', userId)
        .maybeSingle();
    nicknames[userId] = profile?['nickname'] as String? ?? 'Unknown';
  }
  return nicknames;
}

Future<String?> _loadLocalNickname(Ref ref, String userId) async {
  final db = await ref.read(databaseProvider).database;
  final rows = await db.query(
    'profiles',
    columns: ['nickname'],
    where: 'user_id = ?',
    whereArgs: [userId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return rows.first['nickname'] as String?;
}

Future<int> _countRows(
  SupabaseClient supabase,
  String table,
  String postId, {
  bool visibleOnly = false,
}) async {
  var query = supabase.from(table).select('post_id').eq('post_id', postId);
  if (visibleOnly) {
    query = query.eq('is_hidden', false).eq('is_deleted', false);
  }
  final rows = await query;
  return rows.length;
}

String _reportReasonCode(String reason) {
  switch (reason.toLowerCase()) {
    case 'spam':
      return 'spam';
    case 'harassment':
    case 'bullying':
      return 'harassment';
    case 'inappropriate content':
      return 'inappropriate';
    case 'misinformation':
      return 'misinformation';
    default:
      return 'other';
  }
}

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final supabase = ref.read(supabaseClientProvider);
  final cacheRepo = ref.read(communityCacheRepositoryProvider);

  if (isOnline) {
    try {
      final response = await supabase
          .from(_communityPostTable)
          .select('''
            post_id,
            user_id,
            body_text,
            is_hidden,
            is_deleted,
            created_at,
            updated_at
          ''')
          .eq('is_hidden', false)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final now = DateTime.now().toUtc().toIso8601String();
      final nicknames = await _loadNicknames(
        supabase,
        response.map<String>((row) => row['user_id'] as String),
      );
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null &&
          (nicknames[user.id] == null || nicknames[user.id] == 'Unknown')) {
        nicknames[user.id] =
            await _loadLocalNickname(ref, user.id) ?? 'Unknown';
      }

      final entries = <CommunityCacheEntry>[];
      for (final row in response) {
        final postId = row['post_id'] as String;
        final userId = row['user_id'] as String;
        final likeCount =
            await _countRows(supabase, _communityLikeTable, postId);
        final commentCount = await _countRows(
          supabase,
          _communityCommentTable,
          postId,
          visibleOnly: true,
        );
        entries.add(
          CommunityCacheEntry(
            postId: postId,
            userId: userId,
            authorNickname: nicknames[userId] ?? 'Unknown',
            bodyText: row['body_text'] as String,
            likeCount: likeCount,
            commentCount: commentCount,
            createdAt: row['created_at'] as String,
            updatedAt: row['updated_at'] as String,
            cachedAt: now,
          ),
        );
      }

      await cacheRepo.clear();
      for (final entry in entries) {
        await cacheRepo.upsert(entry);
      }

      final likedPostIds = <String>{};
      if (user != null) {
        final likes = await supabase
            .from(_communityLikeTable)
            .select('post_id')
            .eq('user_id', user.id);
        for (final like in likes) {
          likedPostIds.add(like['post_id'] as String);
        }
      }

      return entries.map((e) {
        final post = CommunityPost.fromCache(e);
        if (likedPostIds.contains(post.postId)) {
          return post.copyWith(isLikedByMe: true);
        }
        return post;
      }).toList();
    } catch (_) {
      final cached = await cacheRepo.readAllVisible();
      return cached.map(CommunityPost.fromCache).toList();
    }
  }

  final cached = await cacheRepo.readAllVisible();
  return cached.map(CommunityPost.fromCache).toList();
});

final likePostProvider =
    Provider.family<Future<bool> Function(), String>((ref, postId) {
  return () async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      throw Exception('Liking posts requires an internet connection.');
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      throw Exception('You must be logged in to like posts.');
    }

    final supabase = ref.read(supabaseClientProvider);

    final existing = await supabase
        .from(_communityLikeTable)
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      await supabase
          .from(_communityLikeTable)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    } else {
      await supabase.from(_communityLikeTable).insert({
        'post_id': postId,
        'user_id': user.id,
      });
    }
    return true;
  };
});

final createCommentProvider =
    Provider.family<Future<bool> Function(), CreateCommentInput>((ref, input) {
  return () async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      throw Exception('Adding comments requires an internet connection.');
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      throw Exception('You must be logged in to comment.');
    }

    final supabase = ref.read(supabaseClientProvider);

    await supabase.from(_communityCommentTable).insert({
      'post_id': input.postId,
      'user_id': user.id,
      'comment_text': input.bodyText,
    });

    return true;
  };
});

final createPostProvider =
    Provider.family<Future<bool> Function(), String>((ref, bodyText) {
  return () async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      throw Exception('Creating posts requires an internet connection.');
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      throw Exception('You must be logged in to create posts.');
    }

    final supabase = ref.read(supabaseClientProvider);

    await supabase.from(_communityPostTable).insert({
      'user_id': user.id,
      'body_text': bodyText,
    });
    return true;
  };
});

final deletePostProvider =
    Provider.family<Future<bool> Function(), String>((ref, postId) {
  return () async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      throw Exception('Deleting posts requires an internet connection.');
    }

    final supabase = ref.read(supabaseClientProvider);

    await supabase
        .from(_communityPostTable)
        .update({'is_deleted': true}).eq('post_id', postId);
    return true;
  };
});

final reportPostProvider =
    Provider.family<Future<bool> Function(), ReportPostInput>((ref, input) {
  return () async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      throw Exception('Reporting posts requires an internet connection.');
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      throw Exception('You must be logged in to report posts.');
    }

    final supabase = ref.read(supabaseClientProvider);
    final reason = await supabase
        .from('report_reason')
        .select('reason_id')
        .eq('reason_code', _reportReasonCode(input.reason))
        .maybeSingle();

    await supabase.from(_communityReportTable).insert({
      'post_id': input.postId,
      'reporter_user_id': user.id,
      'reason_id': reason?['reason_id'] as int? ?? 5,
      'details': input.details,
    });
    return true;
  };
});

final postCommentsProvider =
    FutureProvider.family<List<CommunityComment>, String>((ref, postId) async {
  final supabase = ref.read(supabaseClientProvider);

  final response = await supabase
      .from(_communityCommentTable)
      .select('''
        comment_id,
        post_id,
        user_id,
        comment_text,
        created_at
      ''')
      .eq('post_id', postId)
      .eq('is_hidden', false)
      .eq('is_deleted', false)
      .order('created_at', ascending: true);

  final nicknames = await _loadNicknames(
    supabase,
    response.map<String>((row) => row['user_id'] as String),
  );

  return response.map<CommunityComment>((row) {
    return CommunityComment.fromSupabase({
      ...row,
      'author_nickname': nicknames[row['user_id'] as String] ?? 'Unknown',
    });
  }).toList();
});
