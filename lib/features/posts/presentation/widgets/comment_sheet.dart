import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../posts_cubit.dart';
import '../../../../core/theme/app_theme.dart';

class CommentSheet extends StatefulWidget {
  final String postId;

  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _commentCtrl = TextEditingController();
  String? _replyingTo;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsCubit>().loadComments(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<PostsCubit>().addComment(widget.postId, text, parentId: _replyingTo);
    _commentCtrl.clear();
    setState(() {
      _replyingTo = null;
      _replyingToName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Comments', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary)),
            ),
            const Divider(color: AppTheme.cardHighestColor, height: 1),
            Expanded(
              child: BlocBuilder<PostsCubit, PostsState>(
                builder: (context, state) {
                  final loading = state.commentsLoading[widget.postId] ?? false;
                  final comments = state.comments[widget.postId] ?? [];

                  if (loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textVariant.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('No comments yet', style: TextStyle(color: AppTheme.textVariant)),
                        ],
                      ),
                    );
                  }

                  final topComments = comments.where((c) => c['parent_id'] == null).toList();
                  final replies = comments.where((c) => c['parent_id'] != null).toList();

                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: topComments.length,
                    itemBuilder: (context, i) {
                      final comment = topComments[i];
                      final commentReplies = replies.where((r) => r['parent_id'] == comment['id']).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CommentTile(
                            comment: comment,
                            onReply: (id, name) {
                              setState(() {
                                _replyingTo = id;
                                _replyingToName = name;
                              });
                            },
                          ),
                          if (commentReplies.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: commentReplies.map((reply) => _CommentTile(
                                  comment: reply,
                                  isReply: true,
                                  onReply: (id, name) {
                                    setState(() {
                                      _replyingTo = id;
                                      _replyingToName = name;
                                    });
                                  },
                                )).toList(),
                              ),
                            ),
                          const Divider(color: AppTheme.cardHighestColor, height: 1),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Replying to $_replyingToName',
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() { _replyingTo = null; _replyingToName = null; }),
                      child: const Icon(Icons.close, size: 16, color: AppTheme.textVariant),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              decoration: BoxDecoration(
                color: AppTheme.cardHighColor,
                border: Border(top: BorderSide(color: AppTheme.cardHighestColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: AppTheme.textMain, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null ? 'Write a reply...' : 'Add a comment...',
                        hintStyle: const TextStyle(color: AppTheme.textVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.cardColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.primaryColor, size: 22),
                    onPressed: _sendComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isReply;
  final void Function(String id, String name) onReply;

  const _CommentTile({
    required this.comment,
    this.isReply = false,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final user = comment['user'] as Map<String, dynamic>?;
    final name = user?['pseudo'] as String? ?? 'Inconnu';
    final avatarUrl = user?['avatar_url'] as String?;
    final content = comment['content'] as String? ?? '';
    final likesCount = (comment['likes_count'] as int?) ?? 0;
    final isLiked = comment['is_liked'] == true;
    final postId = comment['post_id'] as String;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 0 : 0, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.cardHighColor,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                    children: [
                      TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: '  '),
                      TextSpan(text: content),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onReply(comment['id'] as String, name),
                      child: const Text('Reply', style: TextStyle(color: AppTheme.textVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => context.read<PostsCubit>().toggleCommentLike(comment['id'] as String, postId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 12,
                            color: isLiked ? Colors.redAccent : AppTheme.textVariant,
                          ),
                          if (likesCount > 0) ...[
                            const SizedBox(width: 2),
                            Text('$likesCount', style: TextStyle(color: isLiked ? Colors.redAccent : AppTheme.textVariant, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
