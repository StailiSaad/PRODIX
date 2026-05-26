import 'package:flutter/services.dart';

class ForegroundCallService {
  static const _channel = MethodChannel('com.example.prodix/call_service');

  static Future<void> start({
    required String peerName,
    required String callType,
    String callState = 'connected',
    String? callId,
    bool isMuted = false,
    bool isSpeaker = false,
  }) async {
    try {
      await _channel.invokeMethod('startForegroundService', {
        'peerName': peerName,
        'callType': callType,
        'callState': callState,
        'callId': callId ?? '',
        'isMuted': isMuted,
        'isSpeaker': isSpeaker,
      });
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
      await _channel.invokeMethod('stopOverlay');
    } catch (_) {}
  }

  static Future<void> startOverlay() async {
    try {
      await _channel.invokeMethod('startOverlay');
    } catch (_) {}
  }

  static Future<void> stopOverlay() async {
    try {
      await _channel.invokeMethod('stopOverlay');
    } catch (_) {}
  }

  static Future<bool> canDrawOverlays() async {
    try {
      final result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  static void setMethodCallHandler(Future<dynamic> Function(MethodCall) handler) {
    _channel.setMethodCallHandler(handler);
  }
}
