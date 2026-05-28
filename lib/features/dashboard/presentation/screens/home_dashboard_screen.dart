import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../profile/profile_cubit.dart';
import '../../../../data/services/supabase_backend_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/animated_badge.dart';
import '../../../gamification/gamification_cubit.dart';
import '../../../posts/posts_cubit.dart';
import '../../../posts/presentation/screens/posts_feed_screen.dart';
import '../../../posts/presentation/screens/create_post_screen.dart';
import 'main_screen.dart';
import 'dart:ui';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late final PostsCubit _postsCubit;
  int _unreadNotifCount = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _postsCubit = PostsCubit(context.read<SupabaseBackendService>());
    _awardDailyLogin();
    _refreshUnreadCount();
    _notifTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshUnreadCount());
  }

  @override
  void dispose() {
    _postsCubit.close();
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnreadCount() async {
    final count = await context.read<SupabaseBackendService>().getUnreadNotificationCount();
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  Future<void> _awardDailyLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastLogin = prefs.getString('last_login_date');
    if (lastLogin != today) {
      await prefs.setString('last_login_date', today);
      if (mounted) {
        context.read<GamificationCubit>().recordEvent('daily_login');
      }
    }
  }

  Future<void> _showNotifications(BuildContext context) async {
    final theme = Theme.of(context);
    final svc = context.read<SupabaseBackendService>();
    try {
      final notifs = await svc.getNotifications();
      if (!context.mounted) return;

      // Mark all as read
      for (final n in notifs.where((n) => n['is_read'] != true)) {
        svc.markNotificationRead(n['id']);
      }
      _refreshUnreadCount();

      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Notifications', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary)),
            ),
            if (notifs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No notifications yet', style: TextStyle(color: AppTheme.textVariant)),
              )
            else
              ...notifs.take(10).map((n) {
                final payload = n['payload'] as Map<String, dynamic>?;
                final title = payload?['title'] as String? ?? n['type'] as String? ?? 'Notification';
                final body = payload?['body'] as String? ?? '';
                return ListTile(
                  leading: Icon(Icons.notifications, color: theme.colorScheme.primary),
                  title: Text(title, style: const TextStyle(color: AppTheme.textMain)),
                  subtitle: body.isNotEmpty ? Text(body, style: const TextStyle(color: AppTheme.textVariant)) : null,
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Row(
          children: [
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, pState) {
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                    image: pState.avatarUrl != null && pState.avatarUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(pState.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: pState.avatarUrl == null || pState.avatarUrl!.isEmpty
                      ? Icon(Icons.person, size: 18, color: theme.colorScheme.primary)
                      : null,
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              'TEAMUP',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              );
              if (created == true && mounted) {
                _postsCubit.loadFeed(mode: _postsCubit.state.feedMode);
              }
            },
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadNotifCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '$_unreadNotifCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: () => _showNotifications(context),
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final pseudo = state.pseudo.isNotEmpty ? state.pseudo : 'Player';
          final role = state.role.isNotEmpty ? state.role : 'Any Role';
          final friends = '${state.friendsCount} amis';

          return Column(
            children: [
              // Compact header
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BlocBuilder<GamificationCubit, GamificationState>(
                          builder: (context, gState) {
                            final lvl = gState.progress?.level ?? 1;
                            return AnimatedBadge(level: lvl, size: 28);
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Welcome back, ',
                              style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onSurface),
                              children: [
                                TextSpan(
                                  text: pseudo,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    shadows: [
                                      Shadow(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to dominate today?',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2D3449),
                            border: Border.all(color: theme.colorScheme.tertiary, width: 2),
                            image: state.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(state.avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: state.avatarUrl == null
                              ? Icon(Icons.military_tech, size: 24, color: theme.colorScheme.tertiary)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  BlocBuilder<GamificationCubit, GamificationState>(
                                    builder: (context, gState) {
                                      final lvl = gState.progress?.level ?? 1;
                                      return AnimatedBadgeRow(level: lvl, badgeSize: 18);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(pseudo,
                                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                              Text('$role ● $friends',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF0053DB)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            final mainState = context.findAncestorStateOfType<MainScreenState>();
                            if (mainState != null) mainState.switchToTab(1);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.sports_esports, size: 20, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Find a team',
                                    style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                Text('— Quick Matchmaking',
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Posts Feed (takes remaining space)
              Expanded(
                child: BlocProvider<PostsCubit>.value(
                  value: _postsCubit,
                  child: const PostsFeedScreen(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}
