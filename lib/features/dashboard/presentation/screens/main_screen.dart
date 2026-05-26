import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'home_dashboard_screen.dart';
import 'matchmaking_search_screen.dart';
import 'dm_chat_screen.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../call/presentation/screens/team_call_screen.dart';
import 'team_list_screen.dart';
import '../../../profile/presentation/screens/detailed_stats_screen.dart';
import '../../../../data/services/supabase_backend_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/foreground_call_service.dart';
import 'dart:ui';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _pendingInvites = 0;
  int _totalUnread = 0;
  int _teamUnreadCount = 0;
  RealtimeChannel? _callChannel;
  RealtimeChannel? _teamCallChannel;
  RealtimeChannel? _squadCallChannel;
  RealtimeChannel? _invitationChannel;

  void switchToTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _currentIndex = index);
    }
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeDashboardScreen(),
      const MatchmakingSearchScreen(),
      const TeamListScreen(),
      const _TeammatesTab(),
      const DetailedStatsScreen(),
    ];
    _subscribeToInvitations();
    _pollUnread();
    _pollTeamUnread();
    _subscribeToCalls();
    _subscribeToTeamCalls();
    _subscribeToSquadCalls();
  }


  @override
  void dispose() {
    _callChannel?.unsubscribe();
    _teamCallChannel?.unsubscribe();
    _squadCallChannel?.unsubscribe();
    _invitationChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToCalls() {
    final svc = context.read<SupabaseBackendService>();
    final uid = svc.userId;
    if (uid == null) return;
    _callChannel = svc.subscribeToCalls(uid, (record) {
      if (!mounted) return;
      final callerId = record['caller_id'] as String?;
      final callType = record['call_type'] as String? ?? 'audio';
      final callId = record['id'] as String? ?? '';
      if (callerId == null || callerId == uid) return;
      _showIncomingCall(callerId, callType, callId);
    });
  }

  void _showIncomingCall(String callerId, String callType, String callId) {
    final svc = context.read<SupabaseBackendService>();
    svc.getOtherProfile(callerId).then((profile) {
      if (!mounted) return;
      final callerName = profile?['pseudo'] as String? ?? 'Inconnu';
      ForegroundCallService.start(
        peerName: callerName,
        callType: callType,
        callState: 'ringing',
        callId: callId,
      );
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _IncomingCallDialog(
          callerId: callerId,
          callType: callType,
          callId: callId,
          onAccept: () {
            Navigator.pop(ctx);
            ForegroundCallService.stop();
            _navigateToCall(callerId, callType, callId);
          },
          onDecline: () {
            svc.updateCallStatus(callId, 'ended');
            svc.sendDirectMessage(callerId, 'Appel refusé',
                mediaType: 'call_event', mediaName: 'refused');
            ForegroundCallService.stop();
            Navigator.pop(ctx);
          },
        ),
      );
    });
  }

  void _navigateToCall(String peerId, String callType, String callId) {
    context.read<SupabaseBackendService>().getOtherProfile(peerId).then((profile) {
      if (!mounted) return;
      final name = profile?['pseudo'] as String? ?? 'Inconnu';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: callId,
            peerId: peerId,
            peerName: name,
            callType: callType,
            isCaller: false,
          ),
        ),
      );
    });
  }

  void _subscribeToTeamCalls() {
    final svc = context.read<SupabaseBackendService>();
    final uid = svc.userId;
    if (uid == null) return;
    _teamCallChannel = svc.subscribeToIncomingTeamCalls(uid, (record) {
      if (!mounted) return;
      final callId = record['id'] as String? ?? '';
      final teamId = record['team_id'] as String? ?? '';
      final callType = record['call_type'] as String? ?? 'audio';
      final callerId = record['caller_id'] as String? ?? '';
      if (callId.isEmpty || teamId.isEmpty || callerId.isEmpty || callerId == uid) return;
      _showIncomingTeamCall(callId, teamId, callType, callerId);
    });
  }

  void _showIncomingTeamCall(String callId, String teamId, String callType, String callerId) {
    final svc = context.read<SupabaseBackendService>();
    Future.wait([
      svc.getTeamData(teamId),
      svc.getOtherProfile(callerId),
      svc.getTeamChannelId(teamId),
    ]).then((raw) {
      if (!mounted) return;
      final results = raw.cast<dynamic>();
      final teamName = (results[0] as Map<String, dynamic>?)?['name'] as String? ?? 'Équipe';
      final callerName = (results[1] as Map<String, dynamic>?)?['pseudo'] as String? ?? 'Inconnu';
      final channelId = results[2] as String?;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _IncomingTeamCallDialog(
          teamName: teamName,
          callerName: callerName,
          callType: callType,
          onAccept: () {
            Navigator.pop(ctx);
            _navigateToTeamCall(callId, teamId, teamName, callType, channelId ?? '');
          },
          onDecline: () {
            svc.declineTeamCall(callId);
            if (channelId != null) {
              svc.sendCallEventMessage(channelId, 'refused');
            }
            Navigator.pop(ctx);
          },
        ),
      );
    });
  }

  void _navigateToTeamCall(String callId, String teamId, String teamName, String callType, String channelId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamCallScreen(
          callId: callId,
          groupId: teamId,
          groupName: teamName,
          channelId: channelId,
          callType: callType,
          isCaller: false,
          isTeamCall: true,
        ),
      ),
    );
  }

  void _subscribeToSquadCalls() {
    final svc = context.read<SupabaseBackendService>();
    final uid = svc.userId;
    if (uid == null) return;
    _squadCallChannel = svc.subscribeToIncomingSquadCalls(uid, (record) {
      if (!mounted) return;
      final callId = record['id'] as String? ?? '';
      final squadId = record['squad_id'] as String? ?? '';
      final callType = record['call_type'] as String? ?? 'audio';
      final callerId = record['caller_id'] as String? ?? '';
      if (callId.isEmpty || squadId.isEmpty || callerId.isEmpty || callerId == uid) return;
      _showIncomingSquadCall(callId, squadId, callType, callerId);
    });
  }

  void _showIncomingSquadCall(String callId, String squadId, String callType, String callerId) {
    final svc = context.read<SupabaseBackendService>();
    Future.wait([
      svc.getOtherProfile(callerId),
      svc.getSquadChannelId(squadId),
    ]).then((raw) {
      if (!mounted) return;
      final results = raw.cast<dynamic>();
      final callerName = (results[0] as Map<String, dynamic>?)?['pseudo'] as String? ?? 'Inconnu';
      final channelId = results[1] as String?;
      final groupName = 'Squad';
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _IncomingTeamCallDialog(
          teamName: groupName,
          callerName: callerName,
          callType: callType,
          onAccept: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeamCallScreen(
                  callId: callId,
                  groupId: squadId,
                  groupName: groupName,
                  channelId: channelId ?? '',
                  callType: callType,
                  isCaller: false,
                  isTeamCall: false,
                ),
              ),
            );
          },
          onDecline: () {
            svc.declineSquadCall(callId);
            if (channelId != null) {
              svc.sendCallEventMessage(channelId, 'refused');
            }
            Navigator.pop(ctx);
          },
        ),
      );
    });
  }

  void _subscribeToInvitations() {
    final svc = context.read<SupabaseBackendService>();
    final uid = svc.userId;
    if (uid == null) return;
    _invitationChannel = svc.subscribeToInvitations(uid, (_) {
      _refreshInviteCount();
    });
    _refreshInviteCount();
  }

  Future<void> _refreshInviteCount() async {
    try {
      final count = await context.read<SupabaseBackendService>().getPendingInvitationsCount();
      if (mounted) setState(() => _pendingInvites = count);
    } catch (_) {}
  }

  void _pollUnread() {
    Future.microtask(() async {
      while (mounted) {
        try {
          final counts = await context.read<SupabaseBackendService>().getUnreadCounts();
          final total = counts.values.fold<int>(0, (sum, v) => sum + v);
          if (mounted) setState(() => _totalUnread = total);
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 10));
      }
    });
  }

  void _pollTeamUnread() {
    Future.microtask(() async {
      while (mounted) {
        try {
          final counts = await context.read<SupabaseBackendService>().getTeamUnreadCounts();
          final total = counts.values.fold<int>(0, (sum, v) => sum + v);
          if (mounted) setState(() => _teamUnreadCount = total);
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 10));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                )
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              showUnselectedLabels: true,
              selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              unselectedLabelStyle: theme.textTheme.labelSmall,
              items: [
                _buildNavItem(Icons.home_rounded, 'Home', 0, badge: _pendingInvites),
                _buildNavItem(Icons.sports_esports, 'Match', 1),
                _buildNavItem(Icons.shield_rounded, 'Teams', 2, badge: _teamUnreadCount),
                _buildNavItem(Icons.groups_rounded, 'Teammates', 3, badge: _totalUnread),
                _buildNavItem(Icons.person_rounded, 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index, {int badge = 0}) {
    final isActive = _currentIndex == index;
    final theme = Theme.of(context);

    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Icon(
              icon,
              shadows: isActive
                  ? [Shadow(color: theme.colorScheme.primary.withValues(alpha: 0.8), blurRadius: 8)]
                  : null,
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -6,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: Text('$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      label: label,
    );
  }
}

// ─── Incoming Call Dialog ───────────────────────────────────────────────────
class _IncomingCallDialog extends StatefulWidget {
  final String callerId;
  final String callType;
  final String callId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallDialog({
    required this.callerId,
    required this.callType,
    required this.callId,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<_IncomingCallDialog> {
  String _callerName = '...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await context
        .read<SupabaseBackendService>()
        .getOtherProfile(widget.callerId);
    if (mounted) {
      setState(() => _callerName = profile?['pseudo'] as String? ?? 'Inconnu');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: Row(
        children: [
          Icon(
            widget.callType == 'video' ? Icons.videocam : Icons.phone,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text('Appel de $_callerName',
              style: const TextStyle(color: AppTheme.textMain)),
        ],
      ),
      content: Text('Appel ${widget.callType == 'video' ? 'vidéo' : 'audio'} entrant...',
          style: const TextStyle(color: AppTheme.textVariant)),
      actions: [
        TextButton(
          onPressed: widget.onDecline,
          child: const Text('Refuser', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: widget.onAccept,
          child: const Text('Accepter',
              style: TextStyle(color: AppTheme.primaryColor)),
        ),
      ],
    );
  }
}

// ─── Incoming Team Call Dialog ──────────────────────────────────────────────
class _IncomingTeamCallDialog extends StatelessWidget {
  final String teamName;
  final String callerName;
  final String callType;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingTeamCallDialog({
    required this.teamName,
    required this.callerName,
    required this.callType,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: Row(
        children: [
          const Icon(Icons.groups, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text('Appel d\'équipe',
                style: const TextStyle(color: AppTheme.textMain)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$teamName',
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Par $callerName',
              style: const TextStyle(color: AppTheme.textVariant, fontSize: 13)),
          const SizedBox(height: 8),
          Text('Appel ${callType == 'video' ? 'vidéo' : 'audio'} de groupe',
              style: const TextStyle(color: AppTheme.textVariant)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDecline,
          child: const Text('Refuser', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: onAccept,
          child: const Text('Rejoindre',
              style: TextStyle(color: AppTheme.primaryColor)),
        ),
      ],
    );
  }
}

// ─── Teammates Tab ──────────────────────────────────────────────────────────
class _TeammatesTab extends StatefulWidget {
  const _TeammatesTab();

  @override
  State<_TeammatesTab> createState() => _TeammatesTabState();
}

class _TeammatesTabState extends State<_TeammatesTab> {
  List<Map<String, dynamic>> _teammates = [];
  Map<String, int> _unreadCounts = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _pollUnread();
  }

  void _pollUnread() {
    Future.microtask(() async {
      while (mounted) {
        try {
          final counts = await context.read<SupabaseBackendService>().getUnreadCounts();
          if (mounted) setState(() => _unreadCounts = counts);
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 10));
      }
    });
  }

  Future<void> _load() async {
    final svc = context.read<SupabaseBackendService>();
    setState(() { _loading = true; _error = null; });
    try {
      final friends = await svc.getFriends();
      if (mounted) setState(() { _teammates = friends; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openDm(Map<String, dynamic> teammate) {
    final id = teammate['id'] as String? ?? '';
    final name = teammate['pseudo'] as String? ?? 'Unknown';
    final avatar = teammate['avatar_url'] as String?;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DmChatScreen(peerId: id, peerName: name, peerAvatar: avatar),
      ),
    );
  }

  void _callTeammate(Map<String, dynamic> teammate) {
    // Navigate to DM chat which has call buttons in the app bar
    _openDm(teammate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text('TEAMMATES', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: -1)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text('Error: $_error', style: TextStyle(color: theme.colorScheme.error)))
          : _teammates.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: AppTheme.textVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('No teammates yet', style: TextStyle(color: AppTheme.textVariant)),
                    const SizedBox(height: 8),
                    Text('Accept invitations to add teammates',
                        style: TextStyle(color: AppTheme.textVariant, fontSize: 12)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _teammates.length,
                  itemBuilder: (context, i) {
                    final t = _teammates[i];
                    final id = t['id'] as String? ?? '';
                    final name = t['pseudo'] as String? ?? 'Unknown';
                    final avatar = t['avatar_url'] as String?;
                    final gameType = t['game_type'] as String? ?? '';
                    final region = t['region'] as String? ?? '';
                    final unread = _unreadCounts[id] ?? 0;
                    return GestureDetector(
                      onTap: () => _openDm(t),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
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
                                backgroundImage: (avatar != null && avatar.isNotEmpty)
                                    ? NetworkImage(avatar)
                                    : null,
                                child: (avatar == null || avatar.isEmpty)
                                    ? Text(name[0].toUpperCase(),
                                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 18))
                                    : null,
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: -2, bottom: -2,
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
                                Text(name,
                                    style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                                if (gameType.isNotEmpty || region.isNotEmpty)
                                  Text('$gameType • $region',
                                      style: const TextStyle(color: AppTheme.textVariant, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: AppTheme.primaryColor, size: 20),
                            onPressed: () => _openDm(t),
                            tooltip: 'Message',
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: AppTheme.tertiaryColor, size: 20),
                            onPressed: () => _callTeammate(t),
                            tooltip: 'Call',
                          ),
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

