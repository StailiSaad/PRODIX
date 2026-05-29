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

class CallScreen extends StatefulWidget {
  final String callId;
  final String peerId;
  final String peerName;
  final String callType;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.callType,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RealtimeChannel? _iceChannel;
  RealtimeChannel? _sdpChannel;
  RealtimeChannel? _statusChannel;
  Timer? _statusPollTimer;
  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _speakerEnabled = false;
  bool _isRemoteVideo = false;
  bool _callEnded = false;
  bool _connecting = true;
  bool _hasError = false;
  String _errorMsg = '';
  String _callStatus = 'connecting';
  bool _sdpHandled = false;
  bool _hasSentStartedEvent = false;
  bool _remoteDescriptionSet = false;
  Timer? _missedTimer;
  StreamSubscription<CallAction>? _callActionSub;
  final List<RTCIceCandidate> _pendingIceCandidates = [];

  @override
  void initState() {
    super.initState();
    _start();
    ForegroundCallService.start(
      peerName: widget.peerName,
      callType: widget.callType,
      callState: widget.isCaller ? 'waiting' : 'ringing',
      isMuted: _micEnabled,
      isSpeaker: _speakerEnabled,
      callId: widget.callId,
    );
    _missedTimer = Timer(const Duration(seconds: 30), () {
      if (!_callEnded && _callStatus != 'connected') {
        _sendCallEvent('missed');
        _endCall();
      }
    });
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

  Future<void> _start() async {
    try {
      final svc = context.read<SupabaseBackendService>();
      final call = await svc.getCall(widget.callId);
      final status = call?['status'] as String?;
      if (status == 'ended' || status == 'missed') {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _createPeerConnection();
      _subscribeToIceCandidates();
      _subscribeToCallStatus();
      if (widget.isCaller) {
        await _createOffer();
      } else {
        await _fetchAndHandleOffer();
      }
      _replayExistingIceCandidates();
      _startStatusPolling();
    } catch (e) {
      developer.log('CallScreen init error: $e');
      _safeShowError('Erreur de connexion: $e');
    }
  }

  Future<void> _replayExistingIceCandidates() async {
    final svc = context.read<SupabaseBackendService>();
    final candidates = await svc.getIceCandidates(widget.callId);
    for (final data in candidates) {
      if (data['sender_id'] == svc.userId) continue;
      _addIceCandidate(RTCIceCandidate(
        data['candidate'] as String,
        data['sdp_mid'] as String?,
        (data['sdp_mline_index'] as num?)?.toInt(),
      ));
    }
  }

  void _addIceCandidate(RTCIceCandidate candidate) {
    if (_remoteDescriptionSet) {
      try {
        _pc?.addCandidate(candidate);
      } catch (e) {
        developer.log('addIceCandidate error: $e');
      }
    } else {
      _pendingIceCandidates.add(candidate);
    }
  }

  void _flushPendingIceCandidates() {
    for (final c in _pendingIceCandidates) {
      try {
        _pc?.addCandidate(c);
      } catch (e) {
        developer.log('flushIceCandidate error: $e');
      }
    }
    _pendingIceCandidates.clear();
  }

  void _safeShowError(String msg) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMsg = msg;
      _connecting = false;
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _sendCallEvent(String eventType) async {
    final svc = context.read<SupabaseBackendService>();
    final uid = svc.userId;
    if (uid == null) return;
    final messages = {
      'started': 'Appel démarré',
      'ended': 'Appel terminé',
      'ringing': 'Appel en cours...',
    };
    final content = messages[eventType] ?? 'Événement d\'appel';
    try {
      await svc.sendDirectMessage(
        widget.peerId,
        content,
        mediaType: 'call_event',
        mediaName: eventType,
      );
    } catch (e) {
      developer.log('sendCallEvent error: $e');
    }
  }

  void _checkSendStarted() {
    if (_hasSentStartedEvent) return;
    if (_callStatus == 'connected' || (_pc?.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateConnected)) {
      _hasSentStartedEvent = true;
      _sendCallEvent('started');
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

  Future<void> _createPeerConnection() async {
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

    _pc = await createPeerConnection(config);

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.callType == 'video'
            ? {'facingMode': 'user', 'width': 480, 'height': 640}
            : false,
      });
    } catch (e) {
      developer.log('getUserMedia error: $e');
      rethrow;
    }

    if (!mounted) return;

    if (_localStream != null) {
      _localRenderer.srcObject = _localStream;
      for (final track in _localStream!.getTracks()) {
        await _pc?.addTrack(track, _localStream!);
      }
    }

    _pc!.onTrack = (event) {
      if (event.track.kind == 'video') {
        _safeSetState(() => _isRemoteVideo = true);
      }
      if (mounted) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
      }
    };

    _pc!.onIceCandidate = _sendIceCandidate;

    _pc!.onIceConnectionState = (state) {
      _safeSetState(() {
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
          case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            _connecting = false;
            _callStatus = 'connected';
            _missedTimer?.cancel();
            ForegroundCallService.start(
              peerName: widget.peerName,
              callType: widget.callType,
              callState: 'connected',
              isMuted: _micEnabled,
              isSpeaker: _speakerEnabled,
              callId: widget.callId,
            );
            _safeTryOverlay();
            _checkSendStarted();
            break;
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            _callStatus = 'disconnected';
            break;
          case RTCIceConnectionState.RTCIceConnectionStateClosed:
            _callStatus = 'ended';
            break;
          default:
            break;
        }
      });
    };
  }

  Future<void> _createOffer() async {
    if (_pc == null) return;
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    final svc = context.read<SupabaseBackendService>();
    await svc.updateCallSdp(widget.callId, jsonEncode(offer.toMap()), 'offer');
    await svc.updateCallStatus(widget.callId, 'ringing');
    _subscribeToSdpChanges();
  }

  Future<void> _fetchAndHandleOffer() async {
    final svc = context.read<SupabaseBackendService>();
    Map<String, dynamic>? call;
    for (int attempt = 0; attempt < 10; attempt++) {
      call = await svc.getCall(widget.callId);
      if (call != null && call['offer_sdp'] != null) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (call != null && call['offer_sdp'] != null && !_sdpHandled) {
      await _handleOffer(call['offer_sdp'] as String);
    }
    _subscribeToSdpChanges();
  }

  Future<void> _handleOffer(String offerJson) async {
    if (_callEnded || _sdpHandled || _pc == null) return;
    _sdpHandled = true;
    try {
      final sdp = jsonDecode(offerJson)['sdp'] as String?;
      if (sdp == null) return;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      _remoteDescriptionSet = true;
      _flushPendingIceCandidates();
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      final svc = context.read<SupabaseBackendService>();
      await svc.updateCallSdp(widget.callId, jsonEncode(answer.toMap()), 'answer');
      await svc.updateCallStatus(widget.callId, 'ongoing');
    } catch (e) {
      developer.log('handleOffer error: $e');
      _safeShowError('Erreur lors de l\'appel: $e');
    }
  }

  Future<void> _handleAnswer(String answerJson) async {
    if (_callEnded || _sdpHandled || _pc == null) return;
    _sdpHandled = true;
    try {
      final sdp = jsonDecode(answerJson)['sdp'] as String?;
      if (sdp == null) return;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      _remoteDescriptionSet = true;
      _flushPendingIceCandidates();
      await context
          .read<SupabaseBackendService>()
          .updateCallStatus(widget.callId, 'ongoing');
    } catch (e) {
      developer.log('handleAnswer error: $e');
      _safeShowError('Erreur lors de la réponse: $e');
    }
  }

  void _subscribeToSdpChanges() {
    final svc = context.read<SupabaseBackendService>();
    _sdpChannel = svc.subscribeToCallSdp(widget.callId, (record) {
      if (_callEnded || _sdpHandled) return;
      if (widget.isCaller) {
        final sdp = record['answer_sdp'] as String?;
        if (sdp != null) {
          _handleAnswer(sdp).catchError((e) {
            developer.log('SDP handleAnswer error: $e');
          });
        }
      } else {
        final sdp = record['offer_sdp'] as String?;
        if (sdp != null) {
          _handleOffer(sdp).catchError((e) {
            developer.log('SDP handleOffer error: $e');
          });
        }
      }
    });
  }

  void _sendIceCandidate(RTCIceCandidate candidate) {
    final c = candidate.candidate;
    if (c == null || c.isEmpty) return;
    try {
      context.read<SupabaseBackendService>().addIceCandidate(
            widget.callId,
            c,
            candidate.sdpMid,
            candidate.sdpMLineIndex,
          );
    } catch (e) {
      developer.log('sendIceCandidate error: $e');
    }
  }

  void _subscribeToIceCandidates() {
    final svc = context.read<SupabaseBackendService>();
    _iceChannel = svc.subscribeToIceCandidates(widget.callId, (data) {
      _addIceCandidate(RTCIceCandidate(
        data['candidate'] as String,
        data['sdp_mid'] as String?,
        (data['sdp_mline_index'] as num?)?.toInt(),
      ));
    });
  }

  void _subscribeToCallStatus() {
    final uid = context.read<SupabaseBackendService>().userId;
    if (uid == null) return;
    _statusChannel = context
        .read<SupabaseBackendService>()
        .subscribeToCallStatus(widget.callId, (record) {
      final status = record['status'] as String?;
      if (status == 'ended' && mounted) _endCall();
    });
  }

  // Fallback poller; status changes are already delivered via Realtime _statusChannel
  void _startStatusPolling() {
    _statusPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_callEnded) return;
      try {
        final svc = context.read<SupabaseBackendService>();
        final call = await svc.getCall(widget.callId);
        final status = call?['status'] as String?;
        if ((status == 'ended' || status == 'missed') && mounted) {
          _endCall();
        }
      } catch (_) {}
    });
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;
    try {
      await context
          .read<SupabaseBackendService>()
          .updateCallStatus(widget.callId, 'ended');
      await _sendCallEvent('ended');
    await ForegroundCallService.stop();
    } catch (_) {}
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  void _cleanup() {
    try {
      _missedTimer?.cancel();
      _statusPollTimer?.cancel();
      _iceChannel?.unsubscribe();
      _sdpChannel?.unsubscribe();
      _statusChannel?.unsubscribe();
      if (_localStream != null) {
        for (final t in _localStream!.getTracks()) {
          t.stop();
        }
        _localStream!.dispose();
      }
      _remoteStream?.dispose();
      _pc?.close();
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    } catch (e) {
      developer.log('cleanup error: $e');
    }
  }

  void _toggleMic() {
    try {
      _localStream?.getAudioTracks().forEach((t) => t.enabled = !_micEnabled);
      _safeSetState(() => _micEnabled = !_micEnabled);
      ForegroundCallService.start(
        peerName: widget.peerName,
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
      _safeSetState(() => _camEnabled = !_camEnabled);
    } catch (_) {}
  }

  void _toggleSpeaker() {
    _safeSetState(() => _speakerEnabled = !_speakerEnabled);
    try {
      _localStream?.getAudioTracks().forEach((track) {
        track.enableSpeakerphone(_speakerEnabled);
      });
    } catch (_) {}
    ForegroundCallService.start(
      peerName: widget.peerName,
      callType: widget.callType,
      callState: 'connected',
      isMuted: _micEnabled,
      isSpeaker: _speakerEnabled,
      callId: widget.callId,
    );
  }

  void _switchCamera() {
    try {
      final tracks = _localStream?.getVideoTracks();
      if (tracks != null && tracks.isNotEmpty) {
        Helper.switchCamera(tracks.first);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _callEnded = true;
    _callActionSub?.cancel();
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(_errorMsg,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_remoteStream != null && _isRemoteVideo)
                  RTCVideoView(_remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                else
                  Container(
                    color: const Color(0xFF1A1A2E),
                    child: Center(
                      child: CircleAvatar(
                        radius: 64,
                        backgroundColor: AppTheme.cardHighColor,
                        child: Text(
                          widget.peerName[0].toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.callType == 'video')
                  Positioned(
                    right: 16,
                    top: 48,
                    width: 120,
                    height: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _localStream != null
                          ? RTCVideoView(_localRenderer,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                          : Container(color: Colors.black54),
                    ),
                  ),
                Positioned(
                  top: 48,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(widget.peerName,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _callStatus == 'connected'
                            ? 'En ligne'
                            : _callStatus == 'ringing'
                                ? 'Sonnerie...'
                                : 'Connexion...',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (_connecting)
                  const Center(child: CircularProgressIndicator(color: Colors.white)),
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _btn(_micEnabled ? Icons.mic : Icons.mic_off,
                          _micEnabled ? Colors.white : Colors.red, _toggleMic),
                      const SizedBox(width: 24),
                      if (widget.callType == 'video') ...[
                        _btn(_camEnabled ? Icons.videocam : Icons.videocam_off,
                            _camEnabled ? Colors.white : Colors.red, _toggleCam),
                        const SizedBox(width: 24),
                        _btn(Icons.flip_camera_android, Colors.white, _switchCamera),
                        const SizedBox(width: 24),
                      ],
                      _btn(Icons.call_end, Colors.red, _endCall, 36),
                      const SizedBox(width: 24),
                      _btn(_speakerEnabled ? Icons.volume_up : Icons.volume_down,
                          _speakerEnabled ? AppTheme.primaryColor : Colors.white, _toggleSpeaker),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap, [double size = 24]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color == Colors.red ? Colors.red : Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color == Colors.red ? Colors.white : color, size: size),
      ),
    );
  }
}
