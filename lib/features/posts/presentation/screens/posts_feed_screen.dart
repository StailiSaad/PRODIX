import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../posts_cubit.dart';
import '../widgets/post_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_backend_service.dart';

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsCubit>().loadFeed(mode: FeedMode.fyp);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen feed
        BlocBuilder<PostsCubit, PostsState>(
          builder: (context, state) {
            if (state.isLoading && state.posts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.error != null && state.posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Error: ${state.error}', style: const TextStyle(color: AppTheme.errorColor)),
                ),
              );
            }

            if (state.posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: AppTheme.textVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      state.feedMode == FeedMode.fyp
                          ? 'No posts yet'
                          : 'No posts from friends',
                      style: const TextStyle(color: AppTheme.textVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.feedMode == FeedMode.fyp
                          ? 'Be the first to share something!'
                          : 'Add friends to see their posts here',
                      style: const TextStyle(color: AppTheme.textVariant, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<PostsCubit>().loadFeed(mode: state.feedMode),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 56, 12, 16),
                itemCount: state.posts.length,
                itemBuilder: (context, i) {
                  final post = state.posts[i];
                  final userId = post['user_id'] as String?;
                  final currentUserId = context.read<SupabaseBackendService>().userId;
                  return PostCard(
                    post: post,
                    showDelete: userId == currentUserId,
                    onDelete: () => _confirmDelete(context, post['id'] as String),
                  );
                },
              ),
            );
          },
        ),

        // Floating FYP/Amis toggle pill
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bgColor,
                  AppTheme.bgColor.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: BlocBuilder<PostsCubit, PostsState>(
                builder: (context, state) {
                  final isFyp = state.feedMode == FeedMode.fyp;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cardHighColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardHighestColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => context.read<PostsCubit>().switchMode(FeedMode.fyp),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isFyp ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.explore, size: 16, color: isFyp ? AppTheme.primaryColor : AppTheme.textVariant),
                                const SizedBox(width: 4),
                                Text(
                                  'FYP',
                                  style: TextStyle(
                                    color: isFyp ? AppTheme.primaryColor : AppTheme.textVariant,
                                    fontWeight: isFyp ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.read<PostsCubit>().switchMode(FeedMode.friends),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: !isFyp ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 16, color: !isFyp ? AppTheme.primaryColor : AppTheme.textVariant),
                                const SizedBox(width: 4),
                                Text(
                                  'Amis',
                                  style: TextStyle(
                                    color: !isFyp ? AppTheme.primaryColor : AppTheme.textVariant,
                                    fontWeight: !isFyp ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
