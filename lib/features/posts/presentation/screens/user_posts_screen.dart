import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../posts_cubit.dart';
import '../widgets/post_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_backend_service.dart';

class UserPostsScreen extends StatefulWidget {
  final String? userId;

  const UserPostsScreen({super.key, this.userId});

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  late final PostsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = PostsCubit(context.read<SupabaseBackendService>());
    _cubit.loadUserPosts();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        title: const Text('My Posts', style: TextStyle(color: AppTheme.textMain)),
      ),
      body: BlocProvider<PostsCubit>.value(
        value: _cubit,
        child: BlocBuilder<PostsCubit, PostsState>(
          builder: (context, state) {
            if (state.isLoading && state.posts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: AppTheme.textVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    const Text('No posts yet', style: TextStyle(color: AppTheme.textVariant)),
                    const SizedBox(height: 8),
                    const Text('Create your first post!', style: TextStyle(color: AppTheme.textVariant, fontSize: 12)),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _cubit.loadUserPosts(),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: state.posts.length,
                itemBuilder: (context, i) {
                  final post = state.posts[i];
                  final uid = context.read<SupabaseBackendService>().userId;
                  return PostCard(
                    post: post,
                    showDelete: post['user_id'] == uid,
                    onDelete: () => _confirmDelete(context, post['id'] as String),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete post?', style: TextStyle(color: AppTheme.textMain)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppTheme.textVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textVariant)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PostsCubit>().deletePost(postId);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
