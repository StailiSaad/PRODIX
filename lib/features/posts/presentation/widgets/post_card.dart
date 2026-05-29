import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../posts_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../screens/post_detail_screen.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool showDelete;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.showDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = post['user'] as Map<String, dynamic>?;
    final pseudo = user?['pseudo'] as String? ?? 'Inconnu';
    final avatarUrl = user?['avatar_url'] as String?;
    final caption = post['caption'] as String? ?? '';
    final mediaUrls = (post['media_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    final mediaTypes = (post['media_types'] as List<dynamic>?)?.cast<String>() ?? [];
    final likesCount = (post['likes_count'] as int?) ?? 0;
    final commentsCount = (post['comments_count'] as int?) ?? 0;
    final isLiked = post['is_liked'] == true;
    final createdAt = post['created_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardHighestColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, pseudo, avatarUrl, createdAt, theme),
          if (mediaUrls.isNotEmpty)
            _buildMedia(context, mediaUrls, mediaTypes, theme),
          _buildActions(context, post['id'] as String, isLiked, theme),
          _buildLikesCount(likesCount, theme),
          if (caption.isNotEmpty)
            _buildCaption(pseudo, caption, theme),
          _buildCommentsLink(context, post['id'] as String, commentsCount, theme),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String pseudo, String? avatarUrl, String createdAt, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.cardHighColor,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(pseudo[0].toUpperCase(),
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 14))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(pseudo,
                style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          if (showDelete && onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 20),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context, List<String> urls, List<String> types, ThemeData theme) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (urls.length == 1) {
          return ClipRRect(
            child: Image.network(
              urls[0],
              width: width,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 300,
                color: AppTheme.cardHighColor,
                child: Center(child: Icon(Icons.broken_image, color: AppTheme.textVariant, size: 48)),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 300,
                  color: AppTheme.cardHighColor,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          );
        }

        return SizedBox(
          height: 350,
          child: PageView.builder(
            itemCount: urls.length,
            itemBuilder: (_, i) => Image.network(
              urls[i],
              width: width,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.cardHighColor,
                child: Center(child: Icon(Icons.broken_image, color: AppTheme.textVariant, size: 48)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, String postId, bool isLiked, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          BlocBuilder<PostsCubit, PostsState>(
            builder: (context, state) {
              final idx = state.posts.indexWhere((p) => p['id'] == postId);
              final liked = idx != -1 ? state.posts[idx]['is_liked'] == true : isLiked;
              return IconButton(
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.redAccent : AppTheme.textVariant,
                  size: 26,
                ),
                onPressed: () => context.read<PostsCubit>().toggleLike(postId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: AppTheme.textVariant, size: 22),
            onPressed: () => _openDetail(context, postId),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.share_outlined, color: AppTheme.textVariant, size: 22),
            onPressed: () => _sharePost(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          if (showDelete && onDelete != null)
            IconButton(
              icon: Icon(Icons.more_horiz, color: AppTheme.textVariant, size: 22),
              onPressed: () => _showOptions(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildLikesCount(int count, ThemeData theme) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '$count likes',
        style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildCaption(String pseudo, String caption, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: AppTheme.textMain, fontSize: 13),
          children: [
            TextSpan(
              text: '$pseudo  ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: caption),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsLink(BuildContext context, String postId, int count, ThemeData theme) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => _openDetail(context, postId),
        child: Text(
          'View all $count comments',
          style: TextStyle(color: AppTheme.textVariant, fontSize: 13),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String postId) {
    final cubit = context.read<PostsCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId, cubit: cubit),
      ),
    );
  }

  void _sharePost(BuildContext context) {
    final postId = post['id'] as String? ?? '';
    final user = post['user'] as Map<String, dynamic>?;
    final pseudo = user?['pseudo'] as String? ?? 'Inconnu';
    final caption = post['caption'] as String? ?? '';
    Share.share('Check out $pseudo\'s post on TeamUp: https://teamup.app/post/$postId\n\n$caption');
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.delete, color: AppTheme.errorColor),
              title: Text('Delete post', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
