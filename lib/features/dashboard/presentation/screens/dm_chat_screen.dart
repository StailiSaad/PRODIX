import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
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
import '../../../call/presentation/screens/call_screen.dart';
import '../../../gamification/gamification_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DmChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  const DmChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _audioRecorder = AudioRecorder();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _isRecording = false;
  DateTime? _recordStart;
  Timer? _recordTimer;
  int _recordElapsed = 0;
  String? _currentUserId;
  List<Map<String, dynamic>> _pendingMedia = [];
  int _peerLevel = 1;
  final AudioPlayer _previewPlayer = AudioPlayer();
  int _previewPlayingIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<SupabaseBackendService>();
    _currentUserId = svc.userId;
    final msgs = await svc.getMessages(widget.peerId);
    final peerProfile = await svc.getOtherProfile(widget.peerId);
    final peerXp = peerProfile?['experience_points'] as int? ?? 0;
    _peerLevel = 1 + (peerXp ~/ 100);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    await svc.markMessagesAsSeen(widget.peerId);
    _scrollDown();
    _channel = svc.subscribeToMessages(
      'dm_${_currentUserId}_${widget.peerId}',
      (record) {
        final senderId = record['sender_id'] as String?;
        if (senderId == _currentUserId || senderId == widget.peerId) {
          if (mounted) {
            setState(() => _messages.add(record));
            _scrollDown();
          }
          if (senderId == widget.peerId) {
            svc.markMessagesAsSeen(widget.peerId);
          }
        }
      },
    );

  }



  Future<void> _startCall(String callType) async {
    final svc = context.read<SupabaseBackendService>();
    final callId = await svc.initiateCall(widget.peerId, callType: callType);
    if (callId == null || !mounted) return;
    await svc.sendDirectMessage(widget.peerId, 'Appel en cours...',
        mediaType: 'call_event', mediaName: 'ringing');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          peerId: widget.peerId,
          peerName: widget.peerName,
          callType: callType,
          isCaller: true,
        ),
      ),
    );
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
    _channel?.unsubscribe();

    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  // ── Send text + pending media ──
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
      final ok = await svc.sendDirectMessage(widget.peerId, text);
      if (ok && text.isNotEmpty) {
        if (mounted) {
          context.read<GamificationCubit>().recordEvent('chat_message_sent');
          final optimistic = <String, dynamic>{
            'id': 'opt_${DateTime.now().millisecondsSinceEpoch}',
            'sender_id': _currentUserId,
            'receiver_id': widget.peerId,
            'content': text,
            'status': 'sent',
            'created_at': DateTime.now().toIso8601String(),
          };
          setState(() => _messages.add(optimistic));
          _scrollDown();
        }
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
        final ok = await svc.sendDirectMessage(widget.peerId, msgText,
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

  // ── Pick image(s) ──
  Future<void> _pickImage() async {
    final picked =
        await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isEmpty || !mounted) return;
    final items = <Map<String, dynamic>>[];
    for (final p in picked) {
      final bytes = await p.readAsBytes();
      items.add({'bytes': bytes, 'name': p.name, 'type': 'image'});
    }
    setState(() => _pendingMedia.addAll(items));
  }

  // ── Pick file(s) ──
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

  // ── Voice recording ──
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

  // ── Delete message ──
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

  void _onHeaderTap() {
    final mediaMessages = _messages
        .where((m) => (m['media_url'] as String?)?.isNotEmpty == true)
        .toList();
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.cardHighColor,
                    backgroundImage:
                        (widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty)
                            ? NetworkImage(widget.peerAvatar!)
                            : null,
                    child: (widget.peerAvatar == null || widget.peerAvatar!.isEmpty)
                        ? Text(widget.peerName[0].toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.primaryColor, fontSize: 14))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(widget.peerName,
                      style: const TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('Médias partagés',
                  style: TextStyle(color: AppTheme.textMain)),
              trailing: Text('${mediaMessages.length}',
                  style: const TextStyle(color: AppTheme.textVariant)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _MediaGalleryScreen(messages: mediaMessages),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppTheme.primaryColor),
              title: const Text('Voir le profil',
                  style: TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                _showOtherProfile();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showOtherProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OtherProfileScreen(
          peerId: widget.peerId,
          peerName: widget.peerName,
          peerAvatar: widget.peerAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: GestureDetector(
          onTap: _onHeaderTap,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.cardHighColor,
                backgroundImage:
                    (widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty)
                        ? NetworkImage(widget.peerAvatar!)
                        : null,
                child: (widget.peerAvatar == null || widget.peerAvatar!.isEmpty)
                    ? Text(widget.peerName[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.primaryColor, fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 6),
              AnimatedBadge(level: _peerLevel, size: 20),
              const SizedBox(width: 4),
              Text(widget.peerName,
                  style: const TextStyle(color: AppTheme.textMain, fontSize: 16)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: AppTheme.tertiaryColor),
            onPressed: () => _startCall('audio'),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: AppTheme.tertiaryColor),
            onPressed: () => _startCall('video'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text('Start a conversation!',
                              style: TextStyle(color: AppTheme.textVariant)),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final msg = _messages[i];
                            final senderId = msg['sender_id'] as String?;
                            final content = msg['content'] as String? ?? '';
                            final time = msg['created_at'] as String? ?? '';
                            final status = msg['status'] as String?;
                            final mediaUrl = msg['media_url'] as String?;
                            final mediaType = msg['media_type'] as String?;
                            final mediaName = msg['media_name'] as String?;
                            final dur = msg['duration'] as int?;
                            final isMe = senderId == _currentUserId;
                            final msgId = msg['id'] as String?;
                            return _DmBubble(
                              message: content,
                              time: time,
                              isMe: isMe,
                              status: isMe ? status : null,
                              mediaUrl: mediaUrl,
                              mediaType: mediaType,
                              mediaName: mediaName,
                              duration: dur,
                              onDelete: msgId != null
                                  ? () => _deleteMessage(msgId)
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

  Widget _buildInputBar() {
    // ── Recording mode ──
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(top: BorderSide(color: AppTheme.cardHighestColor)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 22),
              onPressed: () => _stopRecording(discard: true),
            ),
            const SizedBox(width: 4),
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_recordElapsed ~/ 60}:${(_recordElapsed % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: AppTheme.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Text('0:00',
                style: TextStyle(color: AppTheme.textVariant, fontSize: 13)),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: IconButton(
                icon: const Icon(Icons.stop, color: Color(0xFF3F008E), size: 20),
                onPressed: () => _stopRecording(),
              ),
            ),
          ],
        ),
      );
    }

    // ── Normal mode ──
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.cardHighestColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingMedia.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _pendingMedia.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  final m = _pendingMedia[i];
                  final type = m['type'] as String;
                  final name = m['name'] as String;
                  final bytes = m['bytes'] as Uint8List;
                  final dur = m['duration'] as int?;
                  final localPath = m['localPath'] as String?;
                  if (type == 'voice') {
                    final isPlaying = _previewPlayingIndex == i;
                    return GestureDetector(
                      onTap: () => _togglePreview(i),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardHighColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                              color: AppTheme.primaryColor, size: 22,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dur != null
                                  ? '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}'
                                  : 'Voice',
                              style: const TextStyle(
                                  color: AppTheme.textMain, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _clearPendingMedia(i),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.cardHighColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        if (type == 'image')
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(bytes,
                                width: 48, height: 48, fit: BoxFit.cover),
                          )
                        else
                          Center(
                            child: Icon(Icons.insert_drive_file,
                                color: AppTheme.primaryColor, size: 20),
                          ),
                        Positioned(
                          top: -4, right: -4,
                          child: GestureDetector(
                            onTap: () => _clearPendingMedia(i),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Row(
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline,
                    color: AppTheme.primaryColor, size: 24),
                color: AppTheme.cardHighColor,
                onSelected: (v) {
                  switch (v) {
                    case 'image':
                      _pickImage();
                      break;
                    case 'file':
                      _pickFile();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'image',
                      child: ListTile(
                          leading: Icon(Icons.image, color: AppTheme.primaryColor),
                          title: Text('Image', style: TextStyle(color: AppTheme.textMain)),
                          dense: true)),
                  const PopupMenuItem(
                      value: 'file',
                      child: ListTile(
                          leading: Icon(Icons.attach_file, color: AppTheme.primaryColor),
                          title: Text('Fichier', style: TextStyle(color: AppTheme.textMain)),
                          dense: true)),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.mic, color: AppTheme.primaryColor, size: 24),
                onPressed: _startRecording,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(
                    hintText: 'Message ${widget.peerName}...',
                    hintStyle: const TextStyle(color: AppTheme.textVariant),
                    filled: true,
                    fillColor: AppTheme.cardHighColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ],
      ),
    );
  }
}

// ── Message bubble ──
class _DmBubble extends StatefulWidget {
  final String message;
  final String time;
  final bool isMe;
  final String? status;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaName;
  final int? duration;
  final VoidCallback? onDelete;

  const _DmBubble({
    required this.message,
    required this.time,
    required this.isMe,
    this.status,
    this.mediaUrl,
    this.mediaType,
    this.mediaName,
    this.duration,
    this.onDelete,
  });

  @override
  State<_DmBubble> createState() => _DmBubbleState();
}

class _DmBubbleState extends State<_DmBubble> {
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
    switch (widget.status) {
      case 'seen':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
                    bottomLeft:
                        !widget.isMe ? const Radius.circular(4) : null,
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
                    if (widget.isMe && widget.status != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.time,
                                style: const TextStyle(
                                    color: AppTheme.textVariant, fontSize: 10)),
                            const SizedBox(width: 4),
                            Icon(_statusIcon(),
                                size: 14, color: _statusColor()),
                          ],
                        ),
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
      case 'video':
        return IconButton(
          icon: const Icon(Icons.play_circle_fill,
              color: AppTheme.primaryColor, size: 48),
          onPressed: () => launchUrl(Uri.parse(widget.mediaUrl!)),
        );
      default:
        return GestureDetector(
          onTap: () => launchUrl(Uri.parse(widget.mediaUrl!)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_fileIcon(), color: AppTheme.primaryColor, size: 24),
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

  IconData _fileIcon() {
    switch (widget.mediaType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'audio':
        return Icons.audiotrack;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }
}

// ── Media Gallery Screen ──
class _MediaGalleryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  const _MediaGalleryScreen({required this.messages});

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

// ── Other player profile screen ──
class _OtherProfileScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  const _OtherProfileScreen({
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  @override
  State<_OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<_OtherProfileScreen> {
  Map<String, dynamic>? _profile;
  List<String> _favGames = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<SupabaseBackendService>();
    final profile = await svc.getOtherProfile(widget.peerId);
    final games = await svc.getFavoriteGames();
    if (mounted) {
      setState(() {
        _profile = profile;
        _favGames = games;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        title: Text(widget.peerName,
            style: const TextStyle(color: AppTheme.textMain)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(
                  child: Text('Profil introuvable',
                      style: TextStyle(color: AppTheme.textVariant)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppTheme.cardHighColor,
                        backgroundImage:
                            (widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty)
                                ? NetworkImage(widget.peerAvatar!)
                                : null,
                        child: (widget.peerAvatar == null ||
                                widget.peerAvatar!.isEmpty)
                            ? Text(widget.peerName[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppTheme.primaryColor, fontSize: 32))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(widget.peerName,
                          style: const TextStyle(
                              color: AppTheme.textMain,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),
                    _section('INFORMATIONS'),
                    const SizedBox(height: 8),
                    _infoCard([
                      _infoRow('Pseudo', widget.peerName),
                      _infoRow('Rang', _profile!['level'] ?? 'N/A'),
                      _infoRow('Rôle', _profile!['role'] ?? 'N/A'),
                      _infoRow('Région', _profile!['region'] ?? 'N/A'),
                      _infoRow('Disponibilité', _profile!['availability'] ?? 'N/A'),
                      _infoRow('Langue',
                          (_profile!['language'] as String? ?? '').toUpperCase()),
                      if (_profile!['bio'] != null &&
                          (_profile!['bio'] as String).isNotEmpty)
                        _infoRow('Bio', _profile!['bio']),
                    ]),
                    const SizedBox(height: 24),
                    _section('RÉSEAUX SOCIAUX'),
                    const SizedBox(height: 8),
                    _socialsCard(),
                    const SizedBox(height: 24),
                    if (_favGames.isNotEmpty) ...[
                      _section('JEUX FAVORIS'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _favGames
                            .map((g) => Chip(
                                  label: Text(g,
                                      style: const TextStyle(
                                          color: AppTheme.textWhite, fontSize: 12)),
                                  backgroundColor: AppTheme.cardColor,
                                  side: const BorderSide(
                                      color: AppTheme.primaryColor),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
    );
  }

  Widget _section(String title) {
    return Text(title,
        style: const TextStyle(
          color: AppTheme.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ));
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _socialsCard() {
    final insta = _profile!['social_instagram'] as String? ?? '';
    final fb = _profile!['social_facebook'] as String? ?? '';
    final gh = _profile!['social_github'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _socialLink(Icons.camera_alt, 'Instagram', insta, 'https://instagram.com/'),
          if (insta.isNotEmpty && fb.isNotEmpty)
            const Divider(color: AppTheme.cardHighestColor),
          _socialLink(Icons.facebook, 'Facebook', fb, 'https://facebook.com/'),
          if (fb.isNotEmpty && gh.isNotEmpty)
            const Divider(color: AppTheme.cardHighestColor),
          _socialLink(Icons.code, 'GitHub', gh, 'https://github.com/'),
        ],
      ),
    );
  }

  Widget _socialLink(IconData icon, String label, String value, String baseUrl) {
    final isEmpty = value.isEmpty;
    return GestureDetector(
      onTap: isEmpty
          ? null
          : () => launchUrl(
              Uri.parse(value.startsWith('http') ? value : '$baseUrl$value'),
              mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  isEmpty ? 'Non renseigné' : value,
                  style: TextStyle(
                    color: isEmpty ? AppTheme.textGrey : AppTheme.primaryColor,
                    fontSize: 14,
                    decoration: isEmpty ? null : TextDecoration.underline,
                  )),
            ),
            if (!isEmpty)
              const Icon(Icons.open_in_new, color: AppTheme.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }
}
