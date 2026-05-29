import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_backend_service.dart';
import '../../../../shared/widgets/animated_badge.dart';
import '../../../call/presentation/screens/call_screen.dart';
import 'dm_chat_screen.dart';
import 'team_chat_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  final String teamName;
  final bool isOwner;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.isOwner = false,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _error;
  String? _channelId;
  String? _currentUserId;
  String? _teamAvatar;
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<SupabaseBackendService>();
    _currentUserId = svc.userId;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        svc.getTeamMembers(widget.teamId),
        svc.getTeamChannelId(widget.teamId),
        svc.isPendingTeamMember(widget.teamId),
        svc.getTeamData(widget.teamId),
      ]);
      if (mounted) {
        final teamData = results[3] as Map<String, dynamic>?;
        setState(() {
          _members = results[0] as List<Map<String, dynamic>>;
          _channelId = results[1] as String?;
          _isPending = results[2] as bool;
          _teamAvatar = teamData?['avatar_url'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _changeTeamAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final svc = context.read<SupabaseBackendService>();
    final url = await svc.updateTeamAvatar(widget.teamId, bytes);
    if (url != null && mounted) {
      setState(() => _teamAvatar = url);
    }
  }

  void _confirmAndLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Quitter l\'équipe',
            style: TextStyle(color: AppTheme.textMain)),
        content: const Text('Êtes-vous sûr de vouloir quitter cette équipe ?',
            style: TextStyle(color: AppTheme.textVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await context.read<SupabaseBackendService>().leaveTeam(widget.teamId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  void _confirmAndKick(String targetUserId, String targetName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Exclure le membre',
            style: TextStyle(color: AppTheme.textMain)),
        content: Text('Exclure $targetName de l\'équipe ?',
            style: const TextStyle(color: AppTheme.textVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exclure', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await context
            .read<SupabaseBackendService>()
            .kickMember(widget.teamId, targetUserId);
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  void _showAddFriendsSheet() async {
    final svc = context.read<SupabaseBackendService>();
    final friends = await svc.getTeamInvitableFriends(widget.teamId);
    if (!mounted) return;

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
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ajouter des amis',
                  style: const TextStyle(
                      color: AppTheme.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            if (friends.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Tous vos amis sont déjà dans l\'équipe',
                    style: TextStyle(color: AppTheme.textVariant)),
              )
            else
              ...friends.map((f) {
                final id = f['id'] as String? ?? '';
                final name = f['pseudo'] as String? ?? 'Inconnu';
                final avatar = f['avatar_url'] as String?;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.cardHighColor,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(name[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.primaryColor))
                        : null,
                  ),
                  title: Text(name,
                      style: const TextStyle(color: AppTheme.textMain)),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Inviter'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor),
                    onPressed: () async {
                      try {
                        await svc.addMemberToTeam(widget.teamId, id);
                        Navigator.pop(ctx);
                        await _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('$name a rejoint l\'équipe !')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      }
                    },
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openDm(Map<String, dynamic> member) {
    final profile = member['profiles'] as Map<String, dynamic>? ?? {};
    final id = profile['id'] as String? ?? member['user_id'] as String? ?? '';
    final name = profile['pseudo'] as String? ?? 'Inconnu';
    final avatar = profile['avatar_url'] as String?;
    if (id.isEmpty || id == _currentUserId) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DmChatScreen(
          peerId: id,
          peerName: name,
          peerAvatar: avatar,
        ),
      ),
    );
  }

  Future<void> _callMember(Map<String, dynamic> member, String callType) async {
    final profile = member['profiles'] as Map<String, dynamic>? ?? {};
    final id = profile['id'] as String? ?? member['user_id'] as String? ?? '';
    final name = profile['pseudo'] as String? ?? 'Inconnu';
    if (id.isEmpty || id == _currentUserId) return;
    final svc = context.read<SupabaseBackendService>();
    final callId = await svc.initiateCall(id, callType: callType);
    if (callId == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          peerId: id,
          peerName: name,
          callType: callType,
          isCaller: true,
        ),
      ),
    );
  }

  void _openTeamChat() {
    if (_channelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salon de discussion indisponible')),
      );
      return;
    }
    if (_isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approuvez d\'abord votre adhésion pour accéder au chat')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamChatScreen(
          teamId: widget.teamId,
          teamName: widget.teamName,
          channelId: _channelId!,
          teamAvatar: _teamAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(widget.teamName,
            style: const TextStyle(color: AppTheme.textMain, fontSize: 18)),
        actions: [
          if (_channelId != null)
            IconButton(
              icon: const Icon(Icons.chat, color: AppTheme.primaryColor),
              tooltip: 'Chat d\'équipe',
              onPressed: _openTeamChat,
            ),
          if (widget.isOwner)
            IconButton(
              icon: const Icon(Icons.person_add, color: AppTheme.primaryColor),
              tooltip: 'Ajouter des amis',
              onPressed: _showAddFriendsSheet,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: TextStyle(color: theme.colorScheme.error)))
              : Column(
                  children: [
                    // Pending approval banner
                    if (_isPending)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppTheme.primaryColor, size: 28),
                            const SizedBox(height: 8),
                            const Text(
                              'Vous avez été invité à rejoindre cette équipe.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textMain, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text(
                              'Acceptez-vous de rester dans l\'équipe ?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textVariant, fontSize: 13)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.exit_to_app, size: 18),
                                  label: const Text('Quitter'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  onPressed: () async {
                                    await context
                                        .read<SupabaseBackendService>()
                                        .declineTeamMembership(widget.teamId);
                                    if (mounted) Navigator.pop(context);
                                  },
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Rester'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await context
                                        .read<SupabaseBackendService>()
                                        .approveTeamMembership(widget.teamId);
                                    await _load();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    // Team avatar & info
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.cardColor,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: widget.isOwner ? _changeTeamAvatar : null,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: AppTheme.cardHighColor,
                                  backgroundImage: _teamAvatar != null
                                      ? NetworkImage(_teamAvatar!)
                                      : null,
                                  child: _teamAvatar == null
                                      ? Text(
                                          widget.teamName[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontSize: 28),
                                        )
                                      : null,
                                ),
                                if (widget.isOwner)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.teamName,
                                    style: const TextStyle(
                                        color: AppTheme.textMain,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                    '${_members.length} membre${_members.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        color: AppTheme.textVariant,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                          if (!widget.isOwner)
                            TextButton.icon(
                              icon: const Icon(Icons.exit_to_app,
                                  color: Colors.red, size: 18),
                              label: const Text('Quitter',
                                  style: TextStyle(color: Colors.red)),
                              onPressed: _confirmAndLeave,
                            ),
                        ],
                      ),
                    ),
                    // Members list
                    Expanded(
                      child: _members.isEmpty
                          ? const Center(
                              child: Text('Aucun membre',
                                  style: TextStyle(color: AppTheme.textVariant)))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _members.length,
                                itemBuilder: (context, i) {
                                  final m = _members[i];
                                  final profile = m['profiles']
                                      as Map<String, dynamic>? ??
                                      {};
                                  final pseudo =
                                      profile['pseudo'] as String? ?? 'Unknown';
                                  final avatarUrl =
                                      profile['avatar_url'] as String?;
                                  final role =
                                      m['role'] as String? ?? 'member';
                                  final userId = profile['id'] as String? ??
                                      m['user_id'] as String? ??
                                      '';
                                  final isMe = userId == _currentUserId;
                                  final isLeader = role == 'leader';
                                  final xp = profile['experience_points'] as int? ?? 0;
                                  final memberLevel = 1 + (xp ~/ 100);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: AppTheme.cardHighestColor
                                              .withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: AppTheme.cardHighColor,
                                          backgroundImage:
                                              (avatarUrl != null &&
                                                      avatarUrl.isNotEmpty)
                                                  ? NetworkImage(avatarUrl)
                                                  : null,
                                          child: (avatarUrl == null ||
                                                  avatarUrl.isEmpty)
                                              ? Text(pseudo[0].toUpperCase(),
                                                  style: const TextStyle(
                                                      color:
                                                          AppTheme.primaryColor))
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(pseudo,
                                                       style: const TextStyle(
                                                           color:
                                                               AppTheme.textMain,
                                                           fontWeight:
                                                               FontWeight.bold,
                                                           fontSize: 15)),
                                                  const SizedBox(width: 4),
                                                  AnimatedBadge(level: memberLevel, size: 18),
                                                  const SizedBox(width: 4),
                                                  if (isLeader)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .tertiaryColor
                                                            .withValues(
                                                                alpha: 0.15),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: const Text(
                                                          'Leader',
                                                          style: TextStyle(
                                                              color: AppTheme
                                                                  .tertiaryColor,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                  if (isMe)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              left: 4),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .primaryColor
                                                            .withValues(
                                                                alpha: 0.15),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: const Text('Vous',
                                                          style: TextStyle(
                                                              color: AppTheme
                                                                  .primaryColor,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isMe) ...[
                                          IconButton(
                                            icon: const Icon(Icons.message,
                                                color: AppTheme.primaryColor,
                                                size: 20),
                                            tooltip: 'Message',
                                            onPressed: () => _openDm(m),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.phone,
                                                color: AppTheme.tertiaryColor,
                                                size: 20),
                                            tooltip: 'Appel audio',
                                            onPressed: () =>
                                                _callMember(m, 'audio'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.videocam,
                                                color: AppTheme.tertiaryColor,
                                                size: 20),
                                            tooltip: 'Appel vidéo',
                                            onPressed: () =>
                                                _callMember(m, 'video'),
                                          ),
                                          if (widget.isOwner && !isLeader)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.person_remove,
                                                  color: Colors.red,
                                                  size: 20),
                                              tooltip: 'Exclure',
                                              onPressed: () =>
                                                  _confirmAndKick(
                                                      userId, pseudo),
                                            ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
