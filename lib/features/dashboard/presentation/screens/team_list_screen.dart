import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_backend_service.dart';
import 'team_chat_screen.dart';
import 'team_detail_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  List<Map<String, dynamic>> _teams = [];
  Map<String, int> _unreadCounts = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _pollUnread();
  }

  // TODO: Replace polling with Realtime subscription to messages table
  void _pollUnread() {
    Future.microtask(() async {
      while (mounted) {
        try {
          final counts = await context.read<SupabaseBackendService>().getTeamUnreadCounts();
          if (mounted) setState(() => _unreadCounts = counts);
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 60));
      }
    });
  }

  Future<void> _loadTeams() async {
    final svc = context.read<SupabaseBackendService>();
    setState(() { _loading = true; _error = null; });
    try {
      final teams = await svc.getMyTeams();
      if (mounted) setState(() { _teams = teams; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _createTeam() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('Create Team', style: TextStyle(color: AppTheme.textMain)),
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: AppTheme.textMain),
          decoration: const InputDecoration(hintText: 'Team name...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: Text('Create', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await context.read<SupabaseBackendService>().createTeam(name);
      await _loadTeams();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text('TEAMS', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: -1)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppTheme.primaryColor),
            onPressed: _createTeam,
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text('Error: $_error', style: TextStyle(color: theme.colorScheme.error)))
          : _teams.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield, size: 64, color: AppTheme.textVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('No teams yet', style: TextStyle(color: AppTheme.textVariant)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create your first team'),
                      onPressed: _createTeam,
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadTeams,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _teams.length,
                  itemBuilder: (context, i) {
                    final t = _teams[i];
                    final name = t['name'] ?? 'Unnamed';
                    final teamId = t['id'] as String? ?? '';
                    final ownerId = t['owner_id'] ?? '';
                    final teamAvatar = t['avatar_url'] as String?;
                    final currentUserId = context.read<SupabaseBackendService>().userId;
                    final members = t['team_members'] as List<dynamic>? ?? [];
                    final isOwner = ownerId == currentUserId;
                    final unread = _unreadCounts[teamId] ?? 0;
                    return GestureDetector(
                      onTap: () async {
                        final svc = context.read<SupabaseBackendService>();
                        final channelId = await svc.getTeamChannelId(teamId);
                        if (!mounted) return;
                        if (channelId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Salon de discussion indisponible')),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TeamChatScreen(
                              teamId: teamId,
                              teamName: name,
                              channelId: channelId,
                              teamAvatar: teamAvatar,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardHighestColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.cardHighColor,
                                  backgroundImage: teamAvatar != null
                                      ? NetworkImage(teamAvatar)
                                      : null,
                                  child: teamAvatar == null
                                      ? Text(name[0].toUpperCase(),
                                          style: TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontSize: 16))
                                      : null,
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: -4, bottom: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text('$unread',
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('${members.length} member${members.length == 1 ? '' : 's'}', style: TextStyle(color: AppTheme.textVariant, fontSize: 13)),
                                ],
                              ),
                            ),
                            if (isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.tertiaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Owner', style: TextStyle(color: AppTheme.tertiaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: AppTheme.textVariant),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
