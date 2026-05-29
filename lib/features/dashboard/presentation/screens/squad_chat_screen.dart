import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/animated_badge.dart';
import '../../../../data/services/ai_gateway_service.dart';
import '../../../../data/services/supabase_backend_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../gamification/gamification_cubit.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../call/presentation/screens/team_call_screen.dart';

class SquadChatScreen extends StatefulWidget {
  final String squadId;
  final String squadName;
  final String channelId;

  SquadChatScreen({
    super.key,
    required this.squadId,
    required this.squadName,
    required this.channelId,
  });

  @override
  State<SquadChatScreen> createState() => _SquadChatScreenState();
}

class _SquadChatScreenState extends State<SquadChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<SupabaseBackendService>();
    final msgs = await svc.getChannelMessages(widget.channelId);
    final members = await svc.getSquadMembers(widget.squadId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _members = members;
      _loading = false;
    });
    _scrollDown();
    // Subscribe to real-time
    _sub = svc.streamMessages(widget.channelId).listen((newMsgs) {
      if (mounted) {
        setState(() => _messages = newMsgs);
        _scrollDown();
      }
    })
    ..onError((e) => debugPrint('Realtime stream error: $e'));
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    try {
      final ai = context.read<AiGatewayService>();
      final (isToxic, reason) = await ai.analyzeToxicity(text);
      if (!mounted) return;

      if (isToxic) {
        _msgCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.shade800,
          ),
        );
        return;
      }
    } catch (_) {
      // AI gateway unavailable — skip toxicity check
    }

    _msgCtrl.clear();
    final ok = await context.read<SupabaseBackendService>().sendMessage(widget.channelId, text);
    if (ok && text.isNotEmpty) {
      if (mounted) context.read<GamificationCubit>().recordEvent('chat_message_sent');
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Erreur d'envoi"),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _startCallPeer(String peerId, String peerName, String callType) async {
    final svc = context.read<SupabaseBackendService>();
    final callId = await svc.initiateCall(peerId, callType: callType);
    if (callId == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          peerId: peerId,
          peerName: peerName,
          callType: callType,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> _startSquadCall(String callType) async {
    final svc = context.read<SupabaseBackendService>();
    final callId = await svc.initiateSquadCall(widget.squadId, callType: callType);
    if (callId == null || !mounted) return;
    await svc.sendCallEventMessage(widget.channelId, 'ringing');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamCallScreen(
          callId: callId,
          groupId: widget.squadId,
          groupName: widget.squadName,
          channelId: widget.channelId,
          callType: callType,
          isCaller: true,
          isTeamCall: false,
        ),
      ),
    );
  }

  void _showCallPicker() {
    final currentUserId = context.read<SupabaseBackendService>().userId;
    final others = _members.where((m) => m['user_id'] != currentUserId).toList();
    if (others.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('Appeler un membre',
                      style: TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ...others.map((m) {
              final profile = m['profiles'] as Map<String, dynamic>? ?? {};
              final uid = m['user_id'] as String? ?? '';
              final name = profile['pseudo'] as String? ?? 'Membre';
              final avatar = profile['avatar_url'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.cardHighColor,
                  backgroundImage: (avatar != null && avatar.isNotEmpty)
                      ? NetworkImage(avatar)
                      : null,
                  child: (avatar == null || avatar.isEmpty)
                      ? Text(name[0].toUpperCase(),
                          style: TextStyle(
                              color: AppTheme.primaryColor, fontSize: 14))
                      : null,
                ),
                title: Text(name,
                    style: TextStyle(color: AppTheme.textMain)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.phone,
                          color: AppTheme.tertiaryColor),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startCallPeer(uid, name, 'audio');
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.videocam,
                          color: AppTheme.tertiaryColor),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startCallPeer(uid, name, 'video');
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<SupabaseBackendService>().userId;
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.squadName, style: TextStyle(color: AppTheme.textMain, fontSize: 16)),
            Text('${_members.length} members', style: TextStyle(color: AppTheme.textVariant, fontSize: 11)),
          ],
        ),
        actions: [
          if (_members.any((m) => m['user_id'] != currentUserId)) ...[
            IconButton(
              icon: Icon(Icons.phone, color: AppTheme.tertiaryColor),
              onPressed: () => _startSquadCall('audio'),
            ),
            IconButton(
              icon: Icon(Icons.videocam, color: AppTheme.tertiaryColor),
              onPressed: () => _startSquadCall('video'),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Members row
                if (_members.isNotEmpty)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _members.map((m) {
                        final profile = m['profiles'] as Map<String, dynamic>? ?? {};
                        final pseudo = profile['pseudo'] as String? ?? '?';
                        final avatar = profile['avatar_url'] as String?;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.cardHighColor,
                            backgroundImage: (avatar != null && avatar.isNotEmpty)
                                ? NetworkImage(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? Text(pseudo[0].toUpperCase(),
                                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12))
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Divider(height: 1, color: AppTheme.cardHighestColor),

                // Messages
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text('No messages yet. Say hello!',
                              style: TextStyle(color: AppTheme.textVariant)),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final msg = _messages[i];
                            final sender = msg['sender'] as Map<String, dynamic>?;
                            final senderName = sender?['pseudo'] as String? ?? 'Unknown';
                            final senderAvatar = sender?['avatar_url'] as String?;
                            final senderXp = sender?['experience_points'] as int? ?? 0;
                            final senderLevel = 1 + (senderXp ~/ 100);
                            final content = msg['content'] as String? ?? '';
                            final time = msg['created_at'] as String? ?? '';
                            final isMe = sender?['id'] == context.read<SupabaseBackendService>().userId;
                            final mediaType = msg['media_type'] as String?;
                            final mediaName = msg['media_name'] as String?;
                            return _MessageBubble(
                              message: content,
                              senderName: senderName,
                              senderAvatar: senderAvatar,
                              senderLevel: senderLevel,
                              time: time,
                              isMe: isMe,
                              mediaType: mediaType,
                              mediaName: mediaName,
                            );
                          },
                        ),
                ),

                // Input
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    border: Border(top: BorderSide(color: AppTheme.cardHighestColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          style: TextStyle(color: AppTheme.textMain),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: AppTheme.textVariant),
                            filled: true,
                            fillColor: AppTheme.cardHighColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF3F008E), size: 18),
                          onPressed: _send,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final String senderName;
  final String? senderAvatar;
  final int senderLevel;
  final String time;
  final bool isMe;
  final String? mediaType;
  final String? mediaName;

  _MessageBubble({
    required this.message,
    required this.senderName,
    required this.senderAvatar,
    required this.senderLevel,
    required this.time,
    required this.isMe,
    this.mediaType,
    this.mediaName,
  });

  @override
  Widget build(BuildContext context) {
    // Render call events as centered system messages
    if (mediaType == 'call_event') {
      final icon = _callEventIcon(mediaName);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardHighColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, color: AppTheme.textVariant, size: 14),
                if (icon != null) const SizedBox(width: 6),
                Text(message,
                    style: TextStyle(
                        color: AppTheme.textVariant, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.cardHighColor,
                backgroundImage: (senderAvatar != null && senderAvatar!.isNotEmpty)
                    ? NetworkImage(senderAvatar!)
                    : null,
                child: (senderAvatar == null || senderAvatar!.isEmpty)
                    ? Text(senderName[0].toUpperCase(),
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 11))
                    : null,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMe ? const Radius.circular(4) : null,
                  bottomLeft: !isMe ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: isMe
                      ? AppTheme.primaryColor.withValues(alpha: 0.3)
                      : AppTheme.cardHighestColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Row(
                      children: [
                        AnimatedBadge(level: senderLevel, size: 16),
                        const SizedBox(width: 4),
                        Text(senderName,
                            style: TextStyle(
                                color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  if (!isMe) const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: AppTheme.textMain, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData? _callEventIcon(String? eventType) {
    switch (eventType) {
      case 'started': return Icons.phone_in_talk;
      case 'ended': return Icons.call_end;
      case 'refused': return Icons.phone_disabled;
      case 'missed': return Icons.phone_missed;
      case 'ringing': return Icons.phone_forwarded;
      default: return null;
    }
  }
}
