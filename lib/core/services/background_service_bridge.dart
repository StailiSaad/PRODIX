import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundServiceBridge {
  static const _channel = MethodChannel('com.example.prodix/background_service');

  static Future<void> start({
    required String supabaseUrl,
    required String anonKey,
    required String userId,
    required String authToken,
  }) async {
    try {
      await _channel.invokeMethod('startBackgroundService', {
        'supabaseUrl': supabaseUrl,
        'anonKey': anonKey,
        'userId': userId,
        'authToken': authToken,
      });
    } catch (e) {
      debugPrint('BackgroundServiceBridge.start error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopBackgroundService');
    } catch (e) {
      debugPrint('BackgroundServiceBridge.stop error: $e');
    }
  }

  static Future<void> updateToken(String authToken) async {
    try {
      await _channel.invokeMethod('updateBackgroundToken', {
        'authToken': authToken,
      });
    } catch (e) {
      debugPrint('BackgroundServiceBridge.updateToken error: $e');
    }
  }
}
