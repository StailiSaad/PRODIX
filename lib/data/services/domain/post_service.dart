import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  PostService({required this.supabaseUrl});

  final String supabaseUrl;

  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

  Future<String> uploadPostMedia(Uint8List bytes, String fileName) async {
    final path = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _db.storage.from('post_media').uploadBinary(path, bytes);
    return _db.storage.from('post_media').getPublicUrl(path);
  }

  Future<String> uploadChatMedia(Uint8List bytes, String fileName) async {
    final path = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _db.storage.from('chat_media').uploadBinary(path, bytes);
    return _db.storage.from('chat_media').getPublicUrl(path);
  }

  Future<Map<String, dynamic>> createPost({
    required String caption,
    required List<Uint8List> mediaBytes,
    required List<String> mediaExtensions,
    String visibility = 'public',
  }) async {
    if (userId == null) throw Exception('Not authenticated');
    final urls = <String>[];
    final types = <String>[];
    for (int i = 0; i < mediaBytes.length; i++) {
      final ext = mediaExtensions[i];
      final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext.toLowerCase());
      types.add(isVideo ? 'video' : 'image');
      final fileName = 'post_media_$i.$ext';
      final url = await uploadPostMedia(mediaBytes[i], fileName);
      urls.add(url);
    }
    final post = await _db.from('posts').insert({
      'user_id': userId,
      'caption': caption,
      'media_urls': urls,
      'media_types': types,
      'visibility': visibility,
    }).select().single();
    return post;
  }

  Future<List<Map<String, dynamic>>> _attachUserData(List<Map<String, dynamic>> posts) async {
    if (posts.isEmpty) return posts;
    final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
    final profiles = <String, Map<String, dynamic>>{};
    try {
      final rows = await _db
          .from('profiles')
          .select('id, pseudo, avatar_url')
          .filter('id', 'in', '(${userIds.join(",")})');
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        profiles[row['id'] as String] = row;
      }
    } catch (e) {
      developer.log('_attachUserData error: $e');
    }
    for (final post in posts) {
      final uid = post['user_id'] as String;
      post['user'] = profiles[uid] ?? {'id': uid, 'pseudo': 'Inconnu', 'avatar_url': null};
    }
    return posts;
  }

  Future<List<Map<String, dynamic>>> getFeedPosts({bool friendsOnly = false}) async {
    if (userId == null) return [];
    try {
      dynamic query = _db.from('posts').select('*');
      if (friendsOnly) {
        final friendIds = await _getFriendIds();
        final ids = [userId!, ...friendIds];
        query = query.filter('user_id', 'in', '(${ids.join(",")})');
      } else {
        query = query.eq('visibility', 'public');
      }
      query = query.order('created_at', ascending: false).limit(50);
      final posts = List<Map<String, dynamic>>.from(await query);
      await _attachUserData(posts);
      for (final post in posts) {
        final pid = post['id'] as String;
        post['likes_count'] = await _getPostLikesCount(pid);
        post['comments_count'] = await _getPostCommentsCount(pid);
        post['is_liked'] = await _isPostLiked(pid);
      }
      return posts;
    } catch (e) {
      developer.log('getFeedPosts error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      final post = await _db.from('posts').select('*').eq('id', postId).maybeSingle();
      if (post == null) return null;
      await _attachUserData([post]);
      post['likes_count'] = await _getPostLikesCount(postId);
      post['comments_count'] = await _getPostCommentsCount(postId);
      post['is_liked'] = await _isPostLiked(postId);
      return post;
    } catch (e) {
      developer.log('getPostById error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String targetUserId) async {
    try {
      final posts = List<Map<String, dynamic>>.from(
        await _db.from('posts').select('*').eq('user_id', targetUserId).order('created_at', ascending: false),
      );
      await _attachUserData(posts);
      for (final post in posts) {
        final pid = post['id'] as String;
        post['likes_count'] = await _getPostLikesCount(pid);
        post['comments_count'] = await _getPostCommentsCount(pid);
        post['is_liked'] = await _isPostLiked(pid);
      }
      return posts;
    } catch (e) {
      developer.log('getUserPosts error: $e');
      return [];
    }
  }

  Future<void> deletePost(String postId) async {
    if (userId == null) return;
    try {
      await _db.from('posts').delete().eq('id', postId).eq('user_id', userId!);
    } catch (e) {
      developer.log('deletePost error: $e');
      rethrow;
    }
  }

  Future<void> likePost(String postId) async {
    if (userId == null) throw Exception('Not authenticated');
    await _db.from('post_likes').insert({'post_id': postId, 'user_id': userId});
  }

  Future<void> unlikePost(String postId) async {
    if (userId == null) throw Exception('Not authenticated');
    await _db.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId!);
  }

  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    if (userId == null) throw Exception('Not authenticated');
    try {
      final comment = await _db.from('post_comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': content,
        if (parentId != null) 'parent_id': parentId,
      }).select('*').single();
      final profile = await _db
          .from('profiles')
          .select('id, pseudo, avatar_url')
          .eq('id', userId!)
          .maybeSingle();
      comment['user'] = profile ?? {'id': userId, 'pseudo': 'Inconnu', 'avatar_url': null};
      comment['likes_count'] = 0;
      comment['is_liked'] = false;
      return comment;
    } catch (e) {
      developer.log('addComment error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final comments = List<Map<String, dynamic>>.from(
        await _db.from('post_comments').select('*').eq('post_id', postId).order('created_at', ascending: true),
      );
      final userIds = comments.map((c) => c['user_id'] as String).toSet().toList();
      if (userIds.isNotEmpty) {
        final profiles = <String, Map<String, dynamic>>{};
        final rows = await _db.from('profiles').select('id, pseudo, avatar_url').filter('id', 'in', '(${userIds.join(",")})');
        for (final row in List<Map<String, dynamic>>.from(rows)) {
          profiles[row['id'] as String] = row;
        }
        for (final comment in comments) {
          final uid = comment['user_id'] as String;
          comment['user'] = profiles[uid] ?? {'id': uid, 'pseudo': 'Inconnu', 'avatar_url': null};
        }
      }
      if (comments.isNotEmpty && userId != null) {
        final cids = comments.map((c) => c['id'] as String).toList();
        final allLikes = await _db
            .from('post_comment_likes')
            .select('comment_id, user_id')
            .filter('comment_id', 'in', '(${cids.join(",")})');
        final likesByComment = <String, List<Map<String, dynamic>>>{};
        for (final like in List<Map<String, dynamic>>.from(allLikes)) {
          final cid = like['comment_id'] as String;
          likesByComment.putIfAbsent(cid, () => []).add(like);
        }
        for (final comment in comments) {
          final cid = comment['id'] as String;
          final likes = likesByComment[cid] ?? [];
          comment['likes_count'] = likes.length;
          comment['is_liked'] = likes.any((l) => l['user_id'] == userId);
        }
      }
      return comments;
    } catch (e) {
      developer.log('getComments error: $e');
      return [];
    }
  }

  Future<void> deleteComment(String commentId) async {
    if (userId == null) return;
    try {
      await _db.from('post_comments').delete().eq('id', commentId).eq('user_id', userId!);
    } catch (e) {
      developer.log('deleteComment error: $e');
      rethrow;
    }
  }

  Future<void> likeComment(String commentId) async {
    if (userId == null) throw Exception('Not authenticated');
    await _db.from('post_comment_likes').insert({'comment_id': commentId, 'user_id': userId});
  }

  Future<void> unlikeComment(String commentId) async {
    if (userId == null) throw Exception('Not authenticated');
    await _db.from('post_comment_likes').delete().eq('comment_id', commentId).eq('user_id', userId!);
  }

  Future<int> _getPostCommentsCount(String postId) async {
    try {
      final res = await _db.from('post_comments').select('id').eq('post_id', postId);
      return res.length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> _isPostLiked(String postId) async {
    if (userId == null) return false;
    try {
      final res = await _db.from('post_likes').select('post_id').eq('post_id', postId).eq('user_id', userId!).maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<int> _getPostLikesCount(String postId) async {
    try {
      final res = await _db.from('post_likes').select('post_id').eq('post_id', postId);
      return res.length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<String>> _getFriendIds() async {
    if (userId == null) return [];
    try {
      final rows = await _db.from('friends').select('friend_id').eq('user_id', userId!);
      return rows.map((r) => r['friend_id'] as String).toList();
    } catch (e) {
      developer.log('_getFriendIds error: $e');
      return [];
    }
  }
}
