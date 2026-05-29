import 'package:flutter/foundation.dart';
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
    } catch (e) {
      debugPrint('ForegroundCallService.start error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
      await _channel.invokeMethod('stopOverlay');
    } catch (e) {
      debugPrint('ForegroundCallService.stop error: $e');
    }
  }

  static Future<void> startOverlay() async {
    try {
      await _channel.invokeMethod('startOverlay');
    } catch (e) {
      debugPrint('ForegroundCallService.startOverlay error: $e');
    }
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
    } catch (e) {
      debugPrint('ForegroundCallService.canDrawOverlays error: $e');
      return false;
    }
  }

  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (e) {
      debugPrint('ForegroundCallService.openOverlaySettings error: $e');
    }
  }

  static void setMethodCallHandler(Future<dynamic> Function(MethodCall) handler) {
    _channel.setMethodCallHandler(handler);
  }
}
