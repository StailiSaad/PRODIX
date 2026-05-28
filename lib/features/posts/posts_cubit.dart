import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/supabase_backend_service.dart';

enum FeedMode { fyp, friends }

class PostsState extends Equatable {
  const PostsState({
    this.isLoading = false,
    this.isCreating = false,
    this.posts = const [],
    this.error,
    this.feedMode = FeedMode.fyp,
    this.comments = const {},
    this.commentsLoading = const {},
  });

  final bool isLoading;
  final bool isCreating;
  final List<Map<String, dynamic>> posts;
  final String? error;
  final FeedMode feedMode;
  final Map<String, List<Map<String, dynamic>>> comments;
  final Map<String, bool> commentsLoading;

  PostsState copyWith({
    bool? isLoading,
    bool? isCreating,
    List<Map<String, dynamic>>? posts,
    String? error,
    FeedMode? feedMode,
    Map<String, List<Map<String, dynamic>>>? comments,
    Map<String, bool>? commentsLoading,
  }) {
    return PostsState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      posts: posts ?? this.posts,
      error: error,
      feedMode: feedMode ?? this.feedMode,
      comments: comments ?? this.comments,
      commentsLoading: commentsLoading ?? this.commentsLoading,
    );
  }

  @override
  List<Object?> get props => [isLoading, isCreating, posts, error, feedMode, comments, commentsLoading];
}

class PostsCubit extends Cubit<PostsState> {
  PostsCubit(this._svc) : super(const PostsState());

  final SupabaseBackendService _svc;

  Future<void> loadFeed({FeedMode mode = FeedMode.fyp}) async {
    emit(state.copyWith(isLoading: true, feedMode: mode, error: null));
    try {
      final posts = await _svc.getFeedPosts(friendsOnly: mode == FeedMode.friends);
      emit(state.copyWith(isLoading: false, posts: posts));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> loadUserPosts() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final uid = _svc.userId;
      if (uid == null) {
        emit(state.copyWith(isLoading: false, posts: []));
        return;
      }
      final posts = await _svc.getUserPosts(uid);
      emit(state.copyWith(isLoading: false, posts: posts));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<bool> createPost({
    required String caption,
    required List<Uint8List> mediaBytes,
    required List<String> mediaExtensions,
  }) async {
    emit(state.copyWith(isCreating: true, error: null));
    try {
      await _svc.createPost(
        caption: caption,
        mediaBytes: mediaBytes,
        mediaExtensions: mediaExtensions,
      );
      emit(state.copyWith(isCreating: false));
      await loadFeed(mode: state.feedMode);
      return true;
    } catch (e) {
      emit(state.copyWith(isCreating: false, error: e.toString()));
      return false;
    }
  }

  Future<void> toggleLike(String postId) async {
    final idx = state.posts.indexWhere((p) => p['id'] == postId);

    if (idx == -1) {
      try {
        final post = await _svc.getPostById(postId);
        if (post == null) return;
        final wasLiked = post['is_liked'] == true;
        if (wasLiked) {
          await _svc.unlikePost(postId);
        } else {
          await _svc.likePost(postId);
        }
      } catch (_) {}
      return;
    }

    final post = Map<String, dynamic>.from(state.posts[idx]);
    final wasLiked = post['is_liked'] == true;
    final likesCount = (post['likes_count'] as int?) ?? 0;

    post['is_liked'] = !wasLiked;
    post['likes_count'] = wasLiked ? likesCount - 1 : likesCount + 1;

    final updated = List<Map<String, dynamic>>.from(state.posts);
    updated[idx] = post;
    emit(state.copyWith(posts: updated));

    try {
      if (wasLiked) {
        await _svc.unlikePost(postId);
      } else {
        await _svc.likePost(postId);
      }
    } catch (_) {
      // Revert optimistic update on failure
      post['is_liked'] = wasLiked;
      post['likes_count'] = likesCount;
      updated[idx] = post;
      emit(state.copyWith(posts: updated));
    }
  }

  Future<void> loadComments(String postId) async {
    // If already loading or already cached, skip
    if (state.commentsLoading[postId] == true) return;
    if (state.comments[postId] != null) return;

    final loading = Map<String, bool>.from(state.commentsLoading);
    loading[postId] = true;
    emit(state.copyWith(commentsLoading: loading));

    try {
      final comments = await _svc.getComments(postId);
      final all = Map<String, List<Map<String, dynamic>>>.from(state.comments);
      all[postId] = comments;
      loading[postId] = false;
      emit(state.copyWith(comments: all, commentsLoading: loading));
    } catch (e) {
      loading[postId] = false;
      emit(state.copyWith(commentsLoading: loading));
    }
  }

  Future<void> addComment(String postId, String content, {String? parentId}) async {
    try {
      final comment = await _svc.addComment(
        postId: postId,
        content: content,
        parentId: parentId,
      );

      final all = Map<String, List<Map<String, dynamic>>>.from(state.comments);
      final existing = List<Map<String, dynamic>>.from(all[postId] ?? []);
      existing.add(comment);
      all[postId] = existing;
      emit(state.copyWith(comments: all));

      final idx = state.posts.indexWhere((p) => p['id'] == postId);
      if (idx != -1) {
        final post = Map<String, dynamic>.from(state.posts[idx]);
        post['comments_count'] = ((post['comments_count'] as int?) ?? 0) + 1;
        final updated = List<Map<String, dynamic>>.from(state.posts);
        updated[idx] = post;
        emit(state.copyWith(posts: updated));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> toggleCommentLike(String commentId, String postId) async {
    final all = Map<String, List<Map<String, dynamic>>>.from(state.comments);
    final existing = List<Map<String, dynamic>>.from(all[postId] ?? []);
    final idx = existing.indexWhere((c) => c['id'] == commentId);
    if (idx == -1) return;

    final comment = Map<String, dynamic>.from(existing[idx]);
    final wasLiked = comment['is_liked'] == true;
    final likesCount = (comment['likes_count'] as int?) ?? 0;

    comment['is_liked'] = !wasLiked;
    comment['likes_count'] = wasLiked ? likesCount - 1 : likesCount + 1;
    existing[idx] = comment;
    all[postId] = existing;
    emit(state.copyWith(comments: all));

    try {
      if (wasLiked) {
        await _svc.unlikeComment(commentId);
      } else {
        await _svc.likeComment(commentId);
      }
    } catch (_) {
      comment['is_liked'] = wasLiked;
      comment['likes_count'] = likesCount;
      existing[idx] = comment;
      all[postId] = existing;
      emit(state.copyWith(comments: all));
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _svc.deletePost(postId);
      final updated = state.posts.where((p) => p['id'] != postId).toList();
      emit(state.copyWith(posts: updated));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void switchMode(FeedMode mode) {
    if (state.feedMode != mode) {
      loadFeed(mode: mode);
    }
  }
}
