import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/ai_gateway_service.dart';
import '../../../../data/services/supabase_backend_service.dart';
import '../../../../shared/widgets/voice_player_widget.dart';
import '../../../../shared/widgets/animated_badge.dart';
import '../../../call/presentation/screens/team_call_screen.dart';
import '../../../gamification/gamification_cubit.dart';
import 'team_detail_screen.dart';

class TeamChatScreen extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String channelId;
  final String? teamAvatar;

  const TeamChatScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.channelId,
    this.teamAvatar,
  });

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _audioRecorder = AudioRecorder();
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _loading = true;
  bool _isRecording = false;
  DateTime? _recordStart;
  Timer? _recordTimer;
  int _recordElapsed = 0;
  String? _currentUserId;
  String? _teamOwnerId;
  String? _teamAvatar;
  bool _isPending = true;
  String? _pendingError;
  List<Map<String, dynamic>> _pendingMedia = [];
  final AudioPlayer _previewPlayer = AudioPlayer();
  int _previewPlayingIndex = -1;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _sub?.cancel();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _startTeamCall(String callType) async {
    final svc = context.read<SupabaseBackendService>();
    final callId = await svc.initiateTeamCall(widget.teamId, callType: callType);
    if (callId == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamCallScreen(
          callId: callId,
          groupId: widget.teamId,
          groupName: widget.teamName,
          channelId: widget.channelId,
          callType: callType,
          isCaller: true,
          isTeamCall: true,
        ),
      ),
    );
  }

  Future<void> _load() async {
    final svc = context.read<SupabaseBackendService>();
    _currentUserId = svc.userId;
    try {
      final teamData = await svc.getTeamData(widget.teamId);
      _teamOwnerId = teamData?['owner_id'] as String?;
      _teamAvatar = teamData?['avatar_url'] as String? ?? widget.teamAvatar;
      _members = await svc.getTeamMembers(widget.teamId);
      final results = await Future.wait([
        svc.getChannelMessages(widget.channelId),
        svc.isPendingTeamMember(widget.teamId),
      ]);
      if (!mounted) return;
      svc.markChannelMessagesAsDelivered(widget.channelId);
      setState(() {
        _messages = results[0] as List<Map<String, dynamic>>;
        _isPending = results[1] as bool;
        _loading = false;
      });
      _scrollDown();
      _sub = svc.streamMessages(widget.channelId).listen((newMsgs) {
        if (mounted) {
          setState(() => _messages = newMsgs);
          _scrollDown();
        }
      })..onError((e) => debugPrint('TeamChat stream error: $e'));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _pendingMedia.isEmpty) return;

    if (text.isNotEmpty) {
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
    }

    final svc = context.read<SupabaseBackendService>();
    _msgCtrl.clear();

    if (_pendingMedia.isEmpty) {
      final ok = await svc.sendMessage(widget.channelId, text);
      if (ok && text.isNotEmpty) {
        if (mounted) context.read<GamificationCubit>().recordEvent('chat_message_sent');
      }
      return;
    }

    final media = List<Map<String, dynamic>>.from(_pendingMedia);
    setState(() => _pendingMedia.clear());

    for (final m in media) {
      final bytes = m['bytes'] as Uint8List;
      final name = m['name'] as String;
      final type = m['type'] as String;
      final dur = m['duration'] as int?;
      try {
        final url = await svc.uploadChatMedia(bytes, name);
        if (!mounted) return;
        final msgText = (m == media.last) ? text : '';
        final ok = await svc.sendMessage(widget.channelId, msgText,
            mediaUrl: url, mediaType: type, mediaName: name, duration: dur);
        if (ok && msgText.isNotEmpty) {
          if (mounted) context.read<GamificationCubit>().recordEvent('chat_message_sent');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur envoi média: $e'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isEmpty || !mounted) return;
    final items = <Map<String, dynamic>>[];
    for (final p in picked) {
      final bytes = await p.readAsBytes();
      items.add({'bytes': bytes, 'name': p.name, 'type': 'image'});
    }
    setState(() => _pendingMedia.addAll(items));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: true, allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final items = <Map<String, dynamic>>[];
    for (final file in result.files) {
      if (file.bytes == null) continue;
      final ext = file.name.split('.').last.toLowerCase();
      String type = 'file';
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) type = 'image';
      else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) type = 'video';
      else if (['mp3', 'wav', 'aac', 'ogg'].contains(ext)) type = 'audio';
      else if (['pdf'].contains(ext)) type = 'pdf';
      else if (['doc', 'docx'].contains(ext)) type = 'document';
      items.add({'bytes': file.bytes, 'name': file.name, 'type': type});
    }
    setState(() => _pendingMedia.addAll(items));
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission micro nécessaire'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    final now = DateTime.now();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordElapsed =
            DateTime.now().difference(now).inSeconds);
      }
    });
    setState(() {
      _isRecording = true;
      _recordStart = now;
      _recordElapsed = 0;
    });
  }

  Future<void> _stopRecording({bool discard = false}) async {
    final path = await _audioRecorder.stop();
    _recordTimer?.cancel();
    setState(() => _isRecording = false);
    if (path != null && !discard && mounted) {
      final file = File(path);
      final bytes = await file.readAsBytes();
      setState(() {
        _pendingMedia.add({
          'bytes': bytes,
          'name': 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
          'type': 'voice',
          'localPath': path,
          'duration': _recordElapsed,
        });
      });
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Supprimer le message',
            style: TextStyle(color: AppTheme.textMain)),
        content: const Text('Cette action est irréversible.',
            style: TextStyle(color: AppTheme.textVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context
          .read<SupabaseBackendService>()
          .deleteMessage(messageId);
      if (mounted) {
        setState(
            () => _messages.removeWhere((m) => m['id'] == messageId));
      }
    }
  }

  void _togglePreview(int index) async {
    final m = _pendingMedia[index];
    final localPath = m['localPath'] as String?;
    if (localPath == null) return;
    if (_previewPlayingIndex == index) {
      await _previewPlayer.stop();
      setState(() => _previewPlayingIndex = -1);
    } else {
      await _previewPlayer.stop();
      await _previewPlayer.play(DeviceFileSource(localPath));
      _previewPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _previewPlayingIndex = -1);
      });
      setState(() => _previewPlayingIndex = index);
    }
  }

  void _clearPendingMedia(int index) {
    if (_previewPlayingIndex == index) {
      _previewPlayer.stop();
      _previewPlayingIndex = -1;
    }
    setState(() => _pendingMedia.removeAt(index));
  }

  void _showTeamInfoSheet() {
    final mediaMessages = _messages
        .where((m) => (m['media_url'] as String?)?.isNotEmpty == true)
        .toList();
    final isOwner = _teamOwnerId == _currentUserId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TeamInfoScreen(
          teamId: widget.teamId,
          teamName: widget.teamName,
          teamAvatar: _teamAvatar,
          mediaMessages: mediaMessages,
          isOwner: isOwner,
          onLeave: _confirmAndLeave,
        ),
      ),
    );
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
            child: const Text('Quitter',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await context
            .read<SupabaseBackendService>()
            .leaveTeam(widget.teamId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: GestureDetector(
          onTap: _showTeamInfoSheet,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.cardHighColor,
                backgroundImage: _teamAvatar != null
                    ? NetworkImage(_teamAvatar!)
                    : null,
                child: _teamAvatar == null
                    ? Text(widget.teamName[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.primaryColor, fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(widget.teamName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textMain, fontSize: 16)),
              ),
            ],
          ),
        ),
        actions: [
          if (_members.any((m) => m['user_id'] != _currentUserId)) ...[
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.tertiaryColor),
              onPressed: () => _startTeamCall('audio'),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: AppTheme.tertiaryColor),
              onPressed: () => _startTeamCall('video'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.textVariant),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TeamDetailScreen(
                    teamId: widget.teamId,
                    teamName: widget.teamName,
                    isOwner: _teamOwnerId == _currentUserId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isPending || _pendingError != null
              ? _buildPendingLock()
              : Column(
                  children: [
                    if (_pendingMedia.isNotEmpty)
                      _buildPendingMediaBar(),
                    Expanded(
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text('Aucun message',
                                  style:
                                      TextStyle(color: AppTheme.textVariant)))
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) {
                                final msg = _messages[i];
                                final content =
                                    msg['content'] as String? ?? '';
                                final sender =
                                    msg['sender'] as Map<String, dynamic>?;
                                final senderName =
                                    sender?['pseudo'] as String? ?? 'Inconnu';
                                final senderAvatar =
                                    sender?['avatar_url'] as String?;
                                final senderXp = sender?['experience_points'] as int? ?? 0;
                                final senderLevel = 1 + (senderXp ~/ 100);
                                final senderId = sender?['id'] as String? ??
                                    msg['sender_id'] as String? ??
                                    '';
                                final createdAt =
                                    msg['created_at'] as String? ?? '';
                                final time = createdAt.length >= 16
                                    ? createdAt.substring(11, 16)
                                    : '';
                                final isMe = senderId == _currentUserId;
                                final mediaUrl =
                                    msg['media_url'] as String?;
                                final mediaType =
                                    msg['media_type'] as String?;
                                final mediaName =
                                    msg['media_name'] as String?;
                                final dur = msg['duration'] as int?;
                                return _MessageBubble(
                                  message: content,
                                  senderName: senderName,
                                  senderAvatar: senderAvatar,
                                  senderLevel: senderLevel,
                                  time: time,
                                  isMe: isMe,
                                  mediaUrl: mediaUrl,
                                  mediaType: mediaType,
                                  mediaName: mediaName,
                                  duration: dur,
                                  status: msg['status'] as String?,
                                  onDelete: isMe && msg['id'] != null
                                      ? () => _deleteMessage(
                                          msg['id'] as String)
                                      : null,
                                );
                              },
                            ),
                    ),
                    _buildInputBar(),
                  ],
                ),
    );
  }

  Widget _buildPendingLock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                size: 64, color: AppTheme.textVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Adhésion en attente d\'approbation',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMain, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Veuillez approuver votre adhésion dans les paramètres de l\'équipe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textVariant, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Paramètres de l\'équipe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamDetailScreen(
                      teamId: widget.teamId,
                      teamName: widget.teamName,
                      isOwner: _teamOwnerId == _currentUserId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingMediaBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingMedia.length,
        itemBuilder: (_, i) {
          final m = _pendingMedia[i];
          final type = m['type'] as String? ?? '';
          final bytes = m['bytes'] as Uint8List?;
          final localPath = m['localPath'] as String?;
          final dur = m['duration'] as int?;
          return Stack(
            children: [
              Container(
                width: 72,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardHighColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: type == 'image' && bytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      )
                    : type == 'voice'
                        ? GestureDetector(
                            onTap: () => _togglePreview(i),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _previewPlayingIndex == i
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    color: AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                  if (dur != null)
                                    Text(
                                      '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                          color: AppTheme.textVariant,
                                          fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.attach_file,
                                color: AppTheme.primaryColor, size: 28),
                          ),
              ),
              Positioned(
                top: -4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _clearPendingMedia(i),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
        color: AppTheme.cardColor,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _stopRecording(discard: true),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_recordElapsed ~/ 60}:${(_recordElapsed % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                  color: AppTheme.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text('0:30',
                style: const TextStyle(
                    color: AppTheme.textVariant, fontSize: 13)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _stopRecording(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop, color: AppTheme.primaryColor, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
      color: AppTheme.cardColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cardHighColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo, color: AppTheme.textVariant, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cardHighColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.attach_file, color: AppTheme.textVariant, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cardHighColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: AppTheme.primaryColor, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: AppTheme.textMain),
              decoration: InputDecoration(
                hintText: 'Message',
                hintStyle: const TextStyle(color: AppTheme.textVariant),
                filled: true,
                fillColor: AppTheme.cardHighColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send,
                  color: Colors.white,
                  size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final String message;
  final String senderName;
  final String? senderAvatar;
  final int senderLevel;
  final String time;
  final bool isMe;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaName;
  final int? duration;
  final String? status;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.senderName,
    required this.senderAvatar,
    required this.senderLevel,
    required this.time,
    required this.isMe,
    this.mediaUrl,
    this.mediaType,
    this.mediaName,
    this.duration,
    this.status,
    this.onDelete,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  IconData _statusIcon() {
    switch (widget.status) {
      case 'seen':
        return Icons.done_all;
      case 'delivered':
        return Icons.done_all;
      case 'sent':
        return Icons.done;
      default:
        return Icons.access_time;
    }
  }

  Color _statusColor() {
    return widget.status == 'seen' ? AppTheme.primaryColor : AppTheme.textVariant;
  }

  @override
  Widget build(BuildContext context) {
    // Render call events as centered system messages
    if (widget.mediaType == 'call_event') {
      final icon = _callEventIcon(widget.mediaName);
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
                Text(widget.message,
                    style: const TextStyle(
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
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.cardHighColor,
                backgroundImage: (widget.senderAvatar != null && widget.senderAvatar!.isNotEmpty)
                    ? NetworkImage(widget.senderAvatar!)
                    : null,
                child: (widget.senderAvatar == null || widget.senderAvatar!.isEmpty)
                    ? Text(widget.senderName[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11))
                    : null,
              ),
            ),
          Flexible(
            child: GestureDetector(
              onLongPress: widget.onDelete,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight: widget.isMe ? const Radius.circular(4) : null,
                    bottomLeft: !widget.isMe ? const Radius.circular(4) : null,
                  ),
                  border: Border.all(
                    color: widget.isMe
                        ? AppTheme.primaryColor.withValues(alpha: 0.3)
                        : AppTheme.cardHighestColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isMe)
                      Row(
                        children: [
                          AnimatedBadge(level: widget.senderLevel, size: 16),
                          const SizedBox(width: 4),
                          Text(widget.senderName,
                              style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    if (!widget.isMe) const SizedBox(height: 4),
                    _buildMediaContent(),
                    if (widget.message.isNotEmpty)
                      Padding(
                        padding: widget.mediaUrl != null
                            ? const EdgeInsets.only(top: 8)
                            : EdgeInsets.zero,
                        child: Text(widget.message,
                            style: const TextStyle(
                                color: AppTheme.textMain, fontSize: 14)),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.time,
                            style: const TextStyle(
                                color: AppTheme.textVariant, fontSize: 10)),
                        if (widget.isMe) ...[
                          const SizedBox(width: 4),
                          Icon(_statusIcon(),
                              size: 14, color: _statusColor()),
                        ],
                      ],
                    ),
                  ],
                ),
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

  Widget _buildMediaContent() {
    if (widget.mediaUrl == null || widget.mediaUrl!.isEmpty) {
      return const SizedBox.shrink();
    }
    switch (widget.mediaType) {
      case 'image':
        return GestureDetector(
          onTap: () => launchUrl(Uri.parse(widget.mediaUrl!)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(widget.mediaUrl!,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                    color: AppTheme.textVariant)),
          ),
        );
      case 'voice':
        return VoicePlayerWidget(
          url: widget.mediaUrl!,
          isMine: widget.isMe,
          fileName: widget.mediaName,
          initialDurationSec: widget.duration,
        );
      default:
        return GestureDetector(
          onTap: () => launchUrl(Uri.parse(widget.mediaUrl!)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(widget.mediaName ?? 'Fichier',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ),
        );
    }
  }
}

// ── Team info screen (media + role-based actions) ──
class _TeamInfoScreen extends StatelessWidget {
  final String teamId;
  final String teamName;
  final String? teamAvatar;
  final List<Map<String, dynamic>> mediaMessages;
  final bool isOwner;
  final VoidCallback onLeave;

  const _TeamInfoScreen({
    required this.teamId,
    required this.teamName,
    this.teamAvatar,
    required this.mediaMessages,
    required this.isOwner,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.cardHighColor,
              backgroundImage:
                  teamAvatar != null ? NetworkImage(teamAvatar!) : null,
              child: teamAvatar == null
                  ? Text(teamName[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primaryColor, fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 8),
            Text(teamName,
                style:
                    const TextStyle(color: AppTheme.textMain, fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (mediaMessages.isNotEmpty)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: mediaMessages.length,
                itemBuilder: (_, i) {
                  final m = mediaMessages[i];
                  final url = m['media_url'] as String? ?? '';
                  final type = m['media_type'] as String? ?? '';
                  final dur = m['duration'] as int?;
                  return GestureDetector(
                    onTap: type == 'voice'
                        ? null
                        : () => launchUrl(Uri.parse(url)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardHighColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: type == 'image'
                          ? Image.network(url, fit: BoxFit.cover)
                          : type == 'voice'
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.mic,
                                          color: AppTheme.primaryColor,
                                          size: 28),
                                      if (dur != null)
                                        Text(
                                          '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                              color: AppTheme.textVariant,
                                              fontSize: 10),
                                        ),
                                    ],
                                  ),
                                )
                              : Center(
                                  child: Icon(Icons.insert_drive_file,
                                      color: AppTheme.primaryColor, size: 28),
                                ),
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('Aucun média partagé',
                    style: TextStyle(color: AppTheme.textVariant)),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border(
                  top: BorderSide(color: AppTheme.textVariant.withValues(alpha: 0.1))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (isOwner)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.people, size: 18),
                        label: const Text('Gérer les membres'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => TeamDetailScreen(
                                teamId: teamId,
                                teamName: teamName,
                                isOwner: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (isOwner) const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: const Text('Quitter le groupe'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onLeave();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Team media gallery ──
class _TeamMediaGalleryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  const _TeamMediaGalleryScreen({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: const Text('Médias partagés',
            style: TextStyle(color: AppTheme.textMain)),
      ),
      body: messages.isEmpty
          ? const Center(
              child: Text('Aucun média partagé',
                  style: TextStyle(color: AppTheme.textVariant)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final url = m['media_url'] as String? ?? '';
                final name = m['media_name'] as String? ?? '';
                final type = m['media_type'] as String? ?? '';
                return Card(
                  color: AppTheme.cardColor,
                  child: ListTile(
                    leading: Icon(
                      type == 'image'
                          ? Icons.image
                          : type == 'voice'
                              ? Icons.mic
                              : Icons.attach_file,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(name,
                        style: const TextStyle(color: AppTheme.textMain)),
                    trailing: const Icon(Icons.open_in_new,
                        color: AppTheme.primaryColor),
                    onTap: () => launchUrl(Uri.parse(url)),
                  ),
                );
              },
            ),
    );
  }
}
