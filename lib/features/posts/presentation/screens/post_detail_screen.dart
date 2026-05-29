import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../posts_cubit.dart';
import '../widgets/comment_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_backend_service.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final PostsCubit? cubit;

  const PostDetailScreen({super.key, required this.postId, this.cubit});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PostsCubit _cubit;
  Map<String, dynamic>? _post;
  bool _loading = true;
  final _commentCtrl = TextEditingController();
  String? _replyingTo;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? PostsCubit(context.read<SupabaseBackendService>());
    _loadPost();
  }

  @override
  void dispose() {
    if (widget.cubit == null) _cubit.close();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    final svc = context.read<SupabaseBackendService>();
    _post = await svc.getPostById(widget.postId);
    if (mounted) {
      setState(() => _loading = false);
      if (_post != null) {
        _cubit.loadComments(widget.postId);
      }
    }
  }

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _cubit.addComment(widget.postId, text, parentId: _replyingTo);
    _commentCtrl.clear();
    setState(() {
      _replyingTo = null;
      _replyingToName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        title: Text('Post', style: TextStyle(color: AppTheme.textMain)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? Center(child: Text('Post not found', style: TextStyle(color: AppTheme.textVariant)))
              : BlocProvider<PostsCubit>.value(
                  value: _cubit,
                  child: _buildContent(context),
                ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final user = _post!['user'] as Map<String, dynamic>?;
    final pseudo = user?['pseudo'] as String? ?? 'Inconnu';
    final avatarUrl = user?['avatar_url'] as String?;
    final caption = _post!['caption'] as String? ?? '';
    final mediaUrls = (_post!['media_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    final createdAt = _post!['created_at'] as String? ?? '';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.cardHighColor,
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(pseudo[0].toUpperCase(),
                                style: TextStyle(color: AppTheme.primaryColor, fontSize: 16))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(pseudo, style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),

                if (mediaUrls.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: double.infinity,
                        child: mediaUrls.length == 1
                            ? Image.network(
                                mediaUrls[0],
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 300,
                                  color: AppTheme.cardHighColor,
                                  child: Center(child: Icon(Icons.broken_image, color: AppTheme.textVariant, size: 48)),
                                ),
                              )
                            : SizedBox(
                                height: 350,
                                child: PageView.builder(
                                  itemCount: mediaUrls.length,
                                  itemBuilder: (_, i) => Image.network(
                                    mediaUrls[i],
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppTheme.cardHighColor,
                                      child: Center(child: Icon(Icons.broken_image, color: AppTheme.textVariant, size: 48)),
                                    ),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      BlocBuilder<PostsCubit, PostsState>(
                        builder: (context, state) {
                          final idx = state.posts.indexWhere((p) => p['id'] == widget.postId);
                          final liked = idx != -1 ? state.posts[idx]['is_liked'] == true : (_post!['is_liked'] == true);
                          final lCount = idx != -1 ? (state.posts[idx]['likes_count'] as int? ?? 0) : (_post!['likes_count'] as int? ?? 0);
                          return Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  liked ? Icons.favorite : Icons.favorite_border,
                                  color: liked ? Colors.redAccent : AppTheme.textVariant,
                                  size: 28,
                                ),
                                onPressed: () => _cubit.toggleLike(widget.postId),
                              ),
                              if (lCount > 0)
                                Text('$lCount', style: TextStyle(color: AppTheme.textMain, fontSize: 13)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: AppTheme.textVariant, size: 26),
                        onPressed: () => _showComments(context),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.share_outlined, color: AppTheme.textVariant, size: 26),
                        onPressed: () {
                          final postId = _post!['id'] as String? ?? '';
                          Share.share('Check out $pseudo\'s post on TeamUp: https://teamup.app/post/$postId\n\n$caption');
                        },
                      ),
                    ],
                  ),
                ),

                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                        children: [
                          TextSpan(text: '$pseudo  ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: caption),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    createdAt,
                    style: TextStyle(color: AppTheme.textVariant, fontSize: 11),
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: AppTheme.cardHighestColor),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Comments', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 15)),
                ),

                BlocBuilder<PostsCubit, PostsState>(
                  builder: (context, state) {
                    final loading = state.commentsLoading[widget.postId] ?? false;
                    final comments = state.comments[widget.postId] ?? [];

                    if (loading) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (comments.isEmpty) {
                      return GestureDetector(
                        onTap: () => _showComments(context),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No comments yet. Tap to add one.',
                                style: TextStyle(color: AppTheme.textVariant)),
                          ),
                        ),
                      );
                    }

                    final childrenOf = <String?, List<Map<String, dynamic>>>{};
                    for (final c in comments) {
                      final pid = c['parent_id'] as String?;
                      childrenOf.putIfAbsent(pid, () => []).add(c);
                    }

                    Widget buildCommentTree(String? parentId, int depth) {
                      final list = childrenOf[parentId] ?? [];
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: list.map((c) => Padding(
                          padding: EdgeInsets.only(left: depth > 0 ? depth * 24.0 : 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CommentTile(
                                comment: c,
                                isReply: depth > 0,
                                onReply: (id, name) {
                                  setState(() {
                                    _replyingTo = id;
                                    _replyingToName = name;
                                  });
                                },
                              ),
                              buildCommentTree(c['id'] as String?, depth + 1),
                              Divider(color: AppTheme.cardHighestColor, height: 1),
                            ],
                          ),
                        )).toList(),
                      );
                    }

                    return ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        buildCommentTree(null, 0),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.reply, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Replying to $_replyingToName',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() { _replyingTo = null; _replyingToName = null; }),
                  child: Icon(Icons.close, size: 16, color: AppTheme.textVariant),
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
                  style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _replyingTo != null ? 'Write a reply...' : 'Add a comment...',
                    hintStyle: TextStyle(color: AppTheme.textVariant),
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
                icon: Icon(Icons.send, color: AppTheme.primaryColor, size: 22),
                onPressed: _sendComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider<PostsCubit>.value(
        value: _cubit,
        child: CommentSheet(postId: widget.postId),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isReply;
  final void Function(String id, String name) onReply;

  _CommentTile({
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
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 10))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: AppTheme.textMain, fontSize: 13),
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
                      child: Text('Reply', style: TextStyle(color: AppTheme.textVariant, fontSize: 11, fontWeight: FontWeight.bold)),
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
