import 'dart:convert';
import 'package:flutter/services.dart';

class ShizukuStatus {
  final bool installed;
  final bool running;
  final bool granted;

  ShizukuStatus({
    required this.installed,
    required this.running,
    required this.granted,
  });

  factory ShizukuStatus.fromJson(Map<String, dynamic> json) {
    return ShizukuStatus(
      installed: json['installed'] as bool? ?? false,
      running: json['running'] as bool? ?? false,
      granted: json['granted'] as bool? ?? false,
    );
  }
}

class NonRootService {
  static const _channel = MethodChannel('com.example.prodix/android_tweaker');

  static Future<ShizukuStatus> getShizukuStatus() async {
    final raw = await _channel.invokeMethod<String>('getShizukuStatus') ?? '{}';
    return ShizukuStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<bool> requestShizukuPermission() async {
    final result = await _channel.invokeMethod<bool>('requestShizukuPermission');
    return result ?? false;
  }
}
