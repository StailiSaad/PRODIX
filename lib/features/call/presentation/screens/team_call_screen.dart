import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/foreground_call_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../data/services/supabase_backend_service.dart';

class TeamCallScreen extends StatefulWidget {
  final String callId;
  final String groupId;
  final String groupName;
  final String callType;
  final String channelId;
  final bool isCaller;
  final bool isTeamCall;

  const TeamCallScreen({
    super.key,
    required this.callId,
    required this.groupId,
    required this.groupName,
    required this.callType,
    required this.channelId,
    required this.isCaller,
    this.isTeamCall = true,
  });

  @override
  State<TeamCallScreen> createState() => _TeamCallScreenState();
}

class _TeamCallScreenState extends State<TeamCallScreen> {
  List<Map<String, dynamic>> _participants = [];
  bool _loading = true;
  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _speakerEnabled = false;
  bool _callEnded = false;
  bool _hasSentStartedEvent = false;

  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  final Map<String, _PeerConnectionState> _connections = {};
  StreamSubscription<List<Map<String, dynamic>>>? _participantsSub;
  RealtimeChannel? _statusChannel;
  String? _currentUserId;
  String? _myParticipantId;
  StreamSubscription<CallAction>? _callActionSub;

  @override
  void initState() {
    super.initState();
    _init();
    ForegroundCallService.start(
      peerName: widget.groupName,
      callType: widget.callType,
      callState: widget.isCaller ? 'waiting' : 'ringing',
      isMuted: _micEnabled,
      isSpeaker: _speakerEnabled,
      callId: widget.callId,
    );
    _callActionSub = CallActionBus.stream.listen((action) {
      if (_callEnded) return;
      switch (action) {
        case CallAction.toggleMute:
          _toggleMic();
          break;
        case CallAction.toggleSpeaker:
          _toggleSpeaker();
          break;
        case CallAction.endCall:
          _endCall();
          break;
      }
    });
  }

  SupabaseBackendService get _svc => context.read<SupabaseBackendService>();

  // Service method dispatchers
  Future<List<Map<String, dynamic>>> _getParticipants() =>
      widget.isTeamCall
          ? _svc.getTeamCallParticipants(widget.callId)
          : _svc.getSquadCallParticipants(widget.callId);

  Stream<List<Map<String, dynamic>>> _streamParticipants() =>
      widget.isTeamCall
          ? _svc.streamTeamCallParticipants(widget.callId)
          : _svc.streamSquadCallParticipants(widget.callId);

  Future<void> _joinGroupCall() =>
      widget.isTeamCall
          ? _svc.joinTeamCall(widget.callId)
          : _svc.joinSquadCall(widget.callId);

  Future<void> _endGroupCall() =>
      widget.isTeamCall
          ? _svc.endTeamCall(widget.callId)
          : _svc.endSquadCall(widget.callId);

  Future<void> _leaveGroupCall() =>
      widget.isTeamCall
          ? _svc.leaveTeamCall(widget.callId)
          : _svc.leaveSquadCall(widget.callId);

  void _subscribeStatus(void Function(Map<String, dynamic>) onChange) =>
      _statusChannel = widget.isTeamCall
          ? _svc.subscribeToTeamCallStatus(widget.callId, onChange)
          : _svc.subscribeToSquadCallStatus(widget.callId, onChange);

  void _addIceCandidate(String pid, String c, String? mid, int? idx) =>
      widget.isTeamCall
          ? _svc.addTeamCallIceCandidate(pid, c, mid, idx)
          : _svc.addSquadCallIceCandidate(pid, c, mid, idx);

  void _updateSdp(String pid, String json, String type) =>
      widget.isTeamCall
          ? _svc.updateTeamCallParticipantSdp(pid, json, type)
          : _svc.updateSquadCallParticipantSdp(pid, json, type);

  RealtimeChannel _subscribeSdp(String pid, void Function(Map<String, dynamic>) cb) =>
      widget.isTeamCall
          ? _svc.subscribeToTeamCallSdp(pid, cb)
          : _svc.subscribeToSquadCallSdp(pid, cb);

  RealtimeChannel _subscribeIce(String pid, String uid, void Function(Map<String, dynamic>) cb) =>
      widget.isTeamCall
          ? _svc.subscribeToTeamCallIceCandidates(pid, uid, cb)
          : _svc.subscribeToSquadCallIceCandidates(pid, uid, cb);

  Future<List<Map<String, dynamic>>> _getIceCandidates(String pid) =>
      widget.isTeamCall
          ? _svc.getTeamCallIceCandidates(pid)
          : _svc.getSquadCallIceCandidates(pid);

  Future<Map<String, dynamic>?> _getMyParticipant() =>
      widget.isTeamCall
          ? _svc.getTeamCallParticipant(widget.callId, _currentUserId!)
          : _svc.getSquadCallParticipant(widget.callId, _currentUserId!);

  Future<void> _init() async {
    _currentUserId = _svc.userId;
    try {
      await _localRenderer.initialize();
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.callType == 'video'
            ? {'facingMode': 'user', 'width': 480, 'height': 640}
            : false,
      });
      if (mounted && _localStream != null) {
        _localRenderer.srcObject = _localStream;
      }

      if (widget.isCaller) {
        await _svc.sendCallEventMessage(widget.channelId, 'ringing');
      }

      await _loadParticipants();
      if (!mounted) return;

      if (!widget.isCaller) {
        await _joinGroupCall();
        await _loadParticipants();
      }

      _subscribeToParticipantChanges();
      _subscribeStatus((record) {
        final status = record['status'] as String?;
        if (status == 'ended' && mounted) _endCall();
      });
    } catch (e) {
      developer.log('TeamCallScreen init error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadParticipants() async {
    final participants = await _getParticipants();
    if (!mounted) return;
    setState(() {
      _participants = participants;
      _loading = false;
    });

    for (final p in participants) {
      final uid = p['user_id'] as String?;
      if (uid == _currentUserId) {
        _myParticipantId = p['id'] as String?;
      }
    }

    if (widget.isCaller) {
      for (final p in participants) {
        final status = p['status'] as String?;
        final uid = p['user_id'] as String?;
        if (status == 'joined' && uid != _currentUserId) {
          await _ensureConnection(p);
        }
      }
    } else if (_myParticipantId != null) {
      _listenForOffer(_myParticipantId!);
      _replayIceCandidates(_myParticipantId!);
      for (final p in participants) {
        final status = p['status'] as String?;
        final uid = p['user_id'] as String?;
        if (status == 'joined' && uid != _currentUserId) {
          await _ensureConnection(p);
        }
      }
    }
  }

  void _subscribeToParticipantChanges() {
    _participantsSub = _streamParticipants().listen((list) {
      if (!mounted) return;
      setState(() {
        for (final updated in list) {
          final idx = _participants.indexWhere((p) => p['id'] == updated['id']);
          if (idx >= 0) {
            _participants[idx] = updated;
          } else {
            _participants.add(updated);
          }
        }
      });
      for (final p in _participants) {
        final status = p['status'] as String?;
        final uid = p['user_id'] as String?;
        if (status == 'joined' && uid != _currentUserId) {
          _ensureConnection(p);
        }
      }
      _checkSendStartedEvent(_participants);
    });
  }

  void _checkSendStartedEvent(List<Map<String, dynamic>> list) {
    if (_hasSentStartedEvent) return;
    final joined = list.where((p) => p['status'] == 'joined' && p['user_id'] != _currentUserId);
    if (joined.isNotEmpty) {
      _hasSentStartedEvent = true;
      ForegroundCallService.start(
        peerName: widget.groupName,
        callType: widget.callType,
        callState: 'connected',
        isMuted: _micEnabled,
        isSpeaker: _speakerEnabled,
        callId: widget.callId,
      );
      _safeTryOverlay();
      _svc.sendCallEventMessage(widget.channelId, 'started');
    }
  }

  Future<void> _safeTryOverlay() async {
    final canOverlay = await ForegroundCallService.canDrawOverlays();
    if (canOverlay) {
      await ForegroundCallService.startOverlay();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Activer "Afficher par-dessus autres apps" pour voir le bubble'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () => ForegroundCallService.openOverlaySettings(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _ensureConnection(Map<String, dynamic> participant) async {
    final pid = participant['id'] as String;
    if (_connections.containsKey(pid)) return;
    if (_localStream == null) return;

    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    final state = _PeerConnectionState(
      participantId: pid,
      remoteRenderer: renderer,
    );
    _connections[pid] = state;

    try {
      await state.initConnection(_localStream!);

      state.pc!.onTrack = (event) {
        if (event.track.kind == 'video') {
          state.hasRemoteVideo = true;
        }
        if (mounted) {
          state.remoteStream = event.streams[0];
          state.remoteRenderer?.srcObject = state.remoteStream;
          setState(() {});
        }
      };

      state.pc!.onIceCandidate = (candidate) {
        final c = candidate.candidate;
        if (c == null || c.isEmpty) return;
        _addIceCandidate(pid, c, candidate.sdpMid, candidate.sdpMLineIndex);
      };

      state.pc!.onIceConnectionState = (s) {
        if (mounted) setState(() {});
      };

      final offer = await state.pc!.createOffer();
      await state.pc!.setLocalDescription(offer);
      _updateSdp(pid, jsonEncode(offer.toMap()), 'offer');

      state.sdpSub = _subscribeSdp(pid, (record) {
        final answer = record['answer_sdp'] as String?;
        if (answer != null && !state.answerHandled) {
          state.answerHandled = true;
          _handleAnswer(pid, answer).catchError((e) {
            developer.log('handleAnswer error: $e');
          });
        }
      });

      state.iceSub = _subscribeIce(pid, _currentUserId!, (data) {
        try {
          state.pc?.addCandidate(RTCIceCandidate(
            data['candidate'] as String,
            data['sdp_mid'] as String?,
            (data['sdp_mline_index'] as num?)?.toInt(),
          ));
        } catch (e) {
          developer.log('addIceCandidate error: $e');
        }
      });

      _replayExistingIceCandidates(pid, state);
    } catch (e) {
      developer.log('ensureConnection error: $e');
    }
  }

  Future<void> _replayExistingIceCandidates(String pid, _PeerConnectionState state) async {
    final candidates = await _getIceCandidates(pid);
    for (final data in candidates) {
      if (data['sender_id'] == _svc.userId) continue;
      try {
        state.pc?.addCandidate(RTCIceCandidate(
          data['candidate'] as String,
          data['sdp_mid'] as String?,
          (data['sdp_mline_index'] as num?)?.toInt(),
        ));
      } catch (e) {
        developer.log('replayIceCandidate error: $e');
      }
    }
  }

  Future<void> _handleAnswer(String participantId, String answerJson) async {
    final state = _connections[participantId];
    if (state == null || state.pc == null) return;
    try {
      final sdp = jsonDecode(answerJson)['sdp'] as String?;
      if (sdp == null) return;
      await state.pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    } catch (e) {
      developer.log('handleAnswer error: $e');
    }
  }

  void _listenForOffer(String participantId) {
    if (_connections.containsKey(participantId)) return;
    final state = _PeerConnectionState(participantId: participantId);
    _connections[participantId] = state;

    Future.microtask(() async {
      try {
        final participant = await _getMyParticipant();
        if (participant != null && participant['offer_sdp'] != null && !state.offerHandled) {
          await _handleParticipantOffer(participantId, participant['offer_sdp'] as String, state);
        }
      } catch (e) {
        developer.log('checkExistingOffer error: $e');
      }
    });

    state.sdpSub = _subscribeSdp(participantId, (record) async {
      final offer = record['offer_sdp'] as String?;
      if (offer != null && !state.offerHandled && _localStream != null) {
        await _handleParticipantOffer(participantId, offer, state);
      }
    });

    state.iceSub = _subscribeIce(participantId, _currentUserId!, (data) {
      try {
        state.pc?.addCandidate(RTCIceCandidate(
          data['candidate'] as String,
          data['sdp_mid'] as String?,
          (data['sdp_mline_index'] as num?)?.toInt(),
        ));
      } catch (e) {
        developer.log('addIceCandidate error: $e');
      }
    });

    _replayIceCandidates(participantId);
  }

  Future<void> _handleParticipantOffer(
      String participantId, String offerJson, _PeerConnectionState state) async {
    if (_localStream == null) return;
    state.offerHandled = true;

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    state.remoteRenderer = renderer;

    try {
      await state.initConnection(_localStream!);

      state.pc!.onTrack = (event) {
        if (event.track.kind == 'video') {
          state.hasRemoteVideo = true;
        }
        if (mounted) {
          state.remoteStream = event.streams[0];
          state.remoteRenderer?.srcObject = state.remoteStream;
          setState(() {});
        }
      };

      state.pc!.onIceCandidate = (candidate) {
        final c = candidate.candidate;
        if (c == null || c.isEmpty) return;
        _addIceCandidate(participantId, c, candidate.sdpMid, candidate.sdpMLineIndex);
      };

      state.pc!.onIceConnectionState = (s) {
        if (mounted) setState(() {});
      };

      final sdp = jsonDecode(offerJson)['sdp'] as String?;
      if (sdp == null) return;
      await state.pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      final answer = await state.pc!.createAnswer();
      await state.pc!.setLocalDescription(answer);
      _updateSdp(participantId, jsonEncode(answer.toMap()), 'answer');
    } catch (e) {
      developer.log('handleOffer error: $e');
    }
  }

  void _replayIceCandidates(String participantId) async {
    final state = _connections[participantId];
    if (state == null) return;
    final candidates = await _getIceCandidates(participantId);
    for (final data in candidates) {
      if (data['sender_id'] == _svc.userId) continue;
      try {
        state.pc?.addCandidate(RTCIceCandidate(
          data['candidate'] as String,
          data['sdp_mid'] as String?,
          (data['sdp_mline_index'] as num?)?.toInt(),
        ));
      } catch (e) {
        developer.log('replayIceCandidate error: $e');
      }
    }
  }

  void _toggleMic() {
    try {
      _localStream?.getAudioTracks().forEach((t) => t.enabled = !_micEnabled);
      setState(() => _micEnabled = !_micEnabled);
      ForegroundCallService.start(
        peerName: widget.groupName,
        callType: widget.callType,
        callState: 'connected',
        isMuted: !_micEnabled,
        isSpeaker: _speakerEnabled,
        callId: widget.callId,
      );
    } catch (_) {}
  }

  void _toggleCam() {
    try {
      _localStream?.getVideoTracks().forEach((t) => t.enabled = !_camEnabled);
      setState(() => _camEnabled = !_camEnabled);
    } catch (_) {}
  }

  void _toggleSpeaker() {
    _speakerEnabled = !_speakerEnabled;
    try {
      _localStream?.getAudioTracks().forEach((track) {
        track.enableSpeakerphone(_speakerEnabled);
      });
    } catch (_) {}
    ForegroundCallService.start(
      peerName: widget.groupName,
      callType: widget.callType,
      callState: 'connected',
      isMuted: _micEnabled,
      isSpeaker: _speakerEnabled,
      callId: widget.callId,
    );
    setState(() {});
  }

  void _switchCamera() {
    try {
      final tracks = _localStream?.getVideoTracks();
      if (tracks != null && tracks.isNotEmpty) {
        Helper.switchCamera(tracks.first);
      }
    } catch (_) {}
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;
    if (widget.isCaller) {
      await _endGroupCall();
    } else {
      await _leaveGroupCall();
    }
    await _svc.sendCallEventMessage(widget.channelId, 'ended');
    await ForegroundCallService.stop();
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  void _cleanup() {
    _participantsSub?.cancel();
    _statusChannel?.unsubscribe();
    for (final entry in _connections.values) {
      entry.dispose();
    }
    _connections.clear();
    try {
      if (_localStream != null) {
        for (final t in _localStream!.getTracks()) { t.stop(); }
        _localStream!.dispose();
      }
      _localRenderer.dispose();
    } catch (e) {
      developer.log('cleanup error: $e');
    }
  }

  @override
  void dispose() {
    _callEnded = true;
    _callActionSub?.cancel();
    _cleanup();
    super.dispose();
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final remoteParticipants = _participants.where((p) => p['user_id'] != _currentUserId).toList();
    final selfParticipant = _participants.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['user_id'] == _currentUserId,
      orElse: () => null,
    );

    final topInset = MediaQuery.of(context).padding.top;
    const topBarH = 48.0;
    const controlsH = 100.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote participants grid
          Positioned.fill(
            top: topInset + topBarH,
            bottom: controlsH,
            child: _buildMainContent(remoteParticipants),
          ),

          // Self-view PIP
          if (selfParticipant != null)
            Positioned(
              top: topInset + topBarH + 8,
              right: 12,
              child: _buildPipTile(selfParticipant),
            ),

          // Controls at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),

          // Top bar with group name
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: topInset + 8, left: 16, right: 16, bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
              child: Text(
                widget.groupName,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> remoteParticipants) {
    if (remoteParticipants.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text('En attente que les participants rejoignent...',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = remoteParticipants.length;
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;

        const spacing = 2.0;
        int cols, rows;
        if (count == 1) { cols = 1; rows = 1; }
        else if (count == 2) { cols = 2; rows = 1; }
        else { cols = (count <= 4) ? 2 : ((count <= 6) ? 3 : 4); rows = (count + cols - 1) ~/ cols; }

        final tileW = (availW - spacing * (cols - 1)) / cols;
        final tileH = (availH - spacing * (rows - 1)) / rows;

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: tileW / tileH,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
          ),
          itemCount: count,
          itemBuilder: (_, i) => _buildParticipantTile(remoteParticipants[i]),
        );
      },
    );
  }

  Widget _buildPipTile(Map<String, dynamic> p) {
    final profile = p['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['pseudo'] as String? ?? 'Membre';
    final isVideoCall = widget.callType == 'video';

    return GestureDetector(
      onTap: null,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isVideoCall && _localStream != null && _camEnabled)
              RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Container(
                color: const Color(0xFF1A1A2E),
                child: Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.cardHighColor,
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(3)),
                child: Text('Vous', style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
            if (!_micEnabled)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.mic_off, color: Colors.red, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> p) {
    final profile = p['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['pseudo'] as String? ?? 'Membre';
    final isVideoCall = widget.callType == 'video';
    final pid = p['id'] as String? ?? '';
    final conn = _connections[pid];
    final renderer = conn?.remoteRenderer;
    final hasVideo = conn?.hasRemoteVideo == true && conn?.remoteStream != null && isVideoCall;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: const Color(0xFF1A1A2E),
        child: Stack(
          children: [
            if (hasVideo && renderer != null)
              RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.cardHighColor,
                      child: Text(name[0].toUpperCase(),
                          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 6),
                    Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ctrlBtn(_micEnabled ? Icons.mic : Icons.mic_off,
                _micEnabled ? Colors.white : Colors.red, _toggleMic),
            const SizedBox(width: 20),
            if (widget.callType == 'video') ...[
              _ctrlBtn(_camEnabled ? Icons.videocam : Icons.videocam_off,
                  _camEnabled ? Colors.white : Colors.red, _toggleCam),
              const SizedBox(width: 20),
              _ctrlBtn(Icons.flip_camera_android, Colors.white, _switchCamera),
              const SizedBox(width: 20),
            ],
            _ctrlBtn(_speakerEnabled ? Icons.volume_up : Icons.volume_down,
                _speakerEnabled ? AppTheme.primaryColor : Colors.white, _toggleSpeaker),
            const SizedBox(width: 20),
            _ctrlBtn(Icons.call_end, Colors.red, _endCall, 36),
            const SizedBox(width: 20),
            _ctrlBtn(Icons.people, Colors.white, _showParticipants),
          ],
        ),
      ),
    );
  }

  void _showParticipants() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Participants (${_participants.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ..._participants.map((p) {
              final profile = p['profiles'] as Map<String, dynamic>? ?? {};
              final name = profile['pseudo'] as String? ?? 'Membre';
              final isMe = p['user_id'] == _currentUserId;
              final status = p['status'] as String? ?? '';
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.cardHighColor,
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                ),
                title: Text('$name${isMe ? ' (Vous)' : ''}',
                    style: const TextStyle(color: Colors.white)),
                trailing: Text(status,
                    style: TextStyle(
                        color: status == 'joined' ? Colors.green : Colors.white54,
                        fontSize: 12)),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, Color color, VoidCallback onTap, [double size = 24]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color == Colors.red ? Colors.red : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color == Colors.red ? Colors.white : color, size: size),
      ),
    );
  }
}

class _PeerConnectionState {
  final String participantId;
  RTCPeerConnection? pc;
  RTCVideoRenderer? remoteRenderer;
  RealtimeChannel? sdpSub;
  RealtimeChannel? iceSub;
  MediaStream? remoteStream;
  bool hasRemoteVideo = false;
  bool offerHandled = false;
  bool answerHandled = false;

  _PeerConnectionState({
    required this.participantId,
    this.remoteRenderer,
  });

  Future<void> initConnection(MediaStream localStream) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
    };
    pc = await createPeerConnection(config);
    for (final track in localStream.getTracks()) {
      await pc?.addTrack(track, localStream);
    }
  }

  void dispose() {
    sdpSub?.unsubscribe();
    iceSub?.unsubscribe();
    remoteRenderer?.dispose();
    remoteStream?.dispose();
    pc?.close();
  }
}
