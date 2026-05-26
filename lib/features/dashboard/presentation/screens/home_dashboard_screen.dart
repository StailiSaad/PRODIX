import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../profile/profile_cubit.dart';
import '../../../../data/services/supabase_backend_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/animated_badge.dart';
import '../../../gamification/gamification_cubit.dart';
import 'main_screen.dart';
import 'dart:ui';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<Map<String, dynamic>> _games = [];
  bool _loadingGames = true;
  List<Map<String, dynamic>> _pendingInvitations = [];
  int _pollFailures = 0;
  static const int _maxPollFailures = 5;
  Duration _pollDelay = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadGames();
    _pollInvitations();
    _awardDailyLogin();
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

  void _pollInvitations() {
    _pollFailures = 0;
    _pollDelay = const Duration(seconds: 5);
    Future.microtask(() async {
      while (mounted && _pollFailures < _maxPollFailures) {
        await _loadInvitations();
        await Future.delayed(_pollDelay);
      }
    });
  }

  Future<void> _loadInvitations() async {
    final svc = context.read<SupabaseBackendService>();
    try {
      final invites = await svc.getInvitations();
      _pollFailures = 0;
      _pollDelay = const Duration(seconds: 5);
      if (mounted) setState(() { _pendingInvitations = invites; });
    } catch (_) {
      _pollFailures++;
      _pollDelay = Duration(seconds: (_pollDelay.inSeconds * 2).clamp(5, 60));
    }
  }

  Future<void> _respondInvite(String invitationId, bool accept) async {
    final svc = context.read<SupabaseBackendService>();
    try {
      await svc.respondInvitation(invitationId, accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept ? 'Invitation accepted!' : 'Invitation declined'),
          backgroundColor: accept ? Colors.green : Colors.red,
        ));
        if (accept) {
          context.read<GamificationCubit>().recordEvent('invitation_accepted');
          context.read<GamificationCubit>().recordEvent('friend_added');
        }
        _loadInvitations();
        // Trigger profile reload to update squads
        if (mounted) context.read<ProfileCubit>().loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showNotifications(BuildContext context) async {
    final theme = Theme.of(context);
    final svc = context.read<SupabaseBackendService>();
    try {
      final notifs = await svc.getNotifications();
      if (!mounted) return;
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

  Future<void> _loadGames() async {
    final svc = context.read<SupabaseBackendService>();
    try {
      final games = await svc.getGames();
      if (mounted) {
        setState(() {
          _games = games;
          _loadingGames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingGames = false;
        });
      }
    }
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
            icon: const Icon(Icons.notifications_outlined),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
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
                const SizedBox(height: 8),
                Text(
                  'Ready to dominate today?',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                // User Profile & Rank Card
                _buildGlassCard(
                  context: context,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -50,
                        bottom: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            boxShadow: [
                              BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.1), blurRadius: 50)
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2D3449),
                                  border: Border.all(color: theme.colorScheme.tertiary, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
                                      blurRadius: 15,
                                    )
                                  ],
                                  image: state.avatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(state.avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: state.avatarUrl == null
                                    ? Icon(Icons.military_tech, size: 40, color: theme.colorScheme.tertiary)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BlocBuilder<GamificationCubit, GamificationState>(
                                      builder: (context, gState) {
                                        final lvl = gState.progress?.level ?? 1;
                                        return AnimatedBadgeRow(level: lvl, badgeSize: 24);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(pseudo, style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface)),
                                    Text('Main Role: $role', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickStat(context, 'AMIS', friends, theme.colorScheme.primary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // CTA Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF0053DB)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                        blurRadius: 30,
                      )
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final mainState = context.findAncestorStateOfType<MainScreenState>();
                        if (mainState != null) {
                          mainState.switchToTab(1);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.sports_esports, size: 48, color: Colors.white),
                            const SizedBox(height: 16),
                            Text('Trouver une équipe', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Matchmaking Rapide', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Pending Invitations ─────────────────────────────────
                if (_pendingInvitations.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                        ),
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('Invitations', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${_pendingInvitations.length} new',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._pendingInvitations.take(5).map((inv) {
                    final sender = inv['sender'] as Map<String, dynamic>?;
                    final senderName = sender?['pseudo'] as String? ?? 'Unknown';
                    final senderAvatar = sender?['avatar_url'] as String?;
                    final invId = inv['id'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.cardColor,
                            AppTheme.primaryColor.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.cardHighColor,
                            backgroundImage: (senderAvatar != null && senderAvatar.isNotEmpty)
                                ? NetworkImage(senderAvatar)
                                : null,
                            child: (senderAvatar == null || senderAvatar.isEmpty)
                                ? Text(senderName[0].toUpperCase(),
                                    style: const TextStyle(color: AppTheme.primaryColor))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$senderName invited you to play!',
                                    style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child: FilledButton.icon(
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text('Accept', style: TextStyle(fontSize: 12)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppTheme.tertiaryColor,
                                            foregroundColor: const Color(0xFF003D1A),
                                          ),
                                          onPressed: () => _respondInvite(invId, true),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Decline', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.errorColor,
                                            side: const BorderSide(color: AppTheme.errorColor),
                                          ),
                                          onPressed: () => _respondInvite(invId, false),
                                        ),
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
                  }),
                  const SizedBox(height: 24),
                ],

                // Games List
                Text('Supported Games', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 16),
                _loadingGames 
                  ? const Center(child: CircularProgressIndicator())
                  : _games.isEmpty
                    ? Text('No games available.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                    : SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _games.length,
                          itemBuilder: (context, index) {
                            final game = _games[index];
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFF131B2E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.gamepad, color: theme.colorScheme.primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    game['name'] ?? 'Unknown',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    game['genre'] ?? '',
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 32),

                // Recent Activity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                      ),
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('Recent Activity', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface)),
                    ),
                    TextButton(
                      onPressed: () => _showNotifications(context),
                      child: Text('VIEW ALL', style: TextStyle(color: theme.colorScheme.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecentActivity(context, state),
                
                const SizedBox(height: 100), // padding for bottom nav
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, ProfileState state) {
    final theme = Theme.of(context);
    final items = <Widget>[];

    if (state.pseudo.isNotEmpty) {
      items.add(_buildActivityItem(
        context, 'Profile updated',
        '${state.gameType} • ${state.role}', 'Now',
        Icons.person, theme.colorScheme.primary,
      ));
    }

    if (items.isEmpty) {
      items.add(_buildActivityItem(
        context, 'Welcome to TeamUp!',
        'Complete your profile to get started', '',
        Icons.waving_hand, theme.colorScheme.primary,
      ));
    }

    return Column(children: items);
  }

  Widget _buildGlassCard({required Widget child, required BuildContext context}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2D3449).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildQuickStat(BuildContext context, String label, String value, Color valueColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF958DA1))),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(color: valueColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, String title, String subtitle, String time, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(time, style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF958DA1))),
        ],
      ),
    );
  }
}
