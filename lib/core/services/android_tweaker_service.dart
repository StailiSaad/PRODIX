import 'dart:convert';
import 'package:flutter/services.dart';

class TweakerStatus {
  final bool serviceEnabled;
  final bool isRunning;
  final bool isRootAvailable;
  final int mode;
  final bool touchBoostEnabled;
  final bool startOnBoot;
  final bool accessibilityEnabled;
  final String currentApp;

  TweakerStatus({
    required this.serviceEnabled,
    required this.isRunning,
    required this.isRootAvailable,
    required this.mode,
    required this.touchBoostEnabled,
    required this.startOnBoot,
    required this.accessibilityEnabled,
    required this.currentApp,
  });

  factory TweakerStatus.fromJson(Map<String, dynamic> json) {
    return TweakerStatus(
      serviceEnabled: json['serviceEnabled'] as bool? ?? false,
      isRunning: json['isRunning'] as bool? ?? false,
      isRootAvailable: json['isRootAvailable'] as bool? ?? false,
      mode: json['mode'] as int? ?? 0,
      touchBoostEnabled: json['touchBoostEnabled'] as bool? ?? true,
      startOnBoot: json['startOnBoot'] as bool? ?? true,
      accessibilityEnabled: json['accessibilityEnabled'] as bool? ?? false,
      currentApp: json['currentApp'] as String? ?? '',
    );
  }
}

class InstalledApp {
  final String packageName;
  final String label;

  InstalledApp({required this.packageName, required this.label});

  factory InstalledApp.fromJson(Map<String, dynamic> json) {
    return InstalledApp(
      packageName: json['packageName'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class AppMode {
  final String packageName;
  final int mode;

  AppMode({required this.packageName, required this.mode});

  factory AppMode.fromJson(Map<String, dynamic> json) {
    return AppMode(
      packageName: json['packageName'] as String? ?? '',
      mode: json['mode'] as int? ?? 0,
    );
  }
}

class AndroidTweakerService {
  static const _channel = MethodChannel('com.example.prodix/android_tweaker');

  static const modeLabels = {
    0: 'Auto',
    1: 'Eco',
    2: 'Balanced',
    3: 'Performance',
    4: 'Gaming',
  };

  static const modeIcons = {
    0: '♻️',
    1: '🔋',
    2: '⚖️',
    3: '🚀',
    4: '🎮',
  };

  static Future<TweakerStatus> getStatus() async {
    final raw = await _channel.invokeMethod<String>('getStatus') ?? '{}';
    return TweakerStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod('setEnabled', {'enabled': enabled});
  }

  static Future<void> setMode(int modeCode) async {
    await _channel.invokeMethod('setMode', {'modeCode': modeCode});
  }

  static Future<void> setTouchBoost(bool enabled) async {
    await _channel.invokeMethod('setTouchBoost', {'enabled': enabled});
  }

  static Future<void> setStartOnBoot(bool enabled) async {
    await _channel.invokeMethod('setStartOnBoot', {'enabled': enabled});
  }

  static Future<List<InstalledApp>> getInstalledApps() async {
    final raw = await _channel.invokeMethod<String>('getInstalledApps') ?? '[]';
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => InstalledApp.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<AppMode>> getAppModes() async {
    final raw = await _channel.invokeMethod<String>('getAppModes') ?? '[]';
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => AppMode.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> setAppMode(String packageName, int modeCode) async {
    await _channel.invokeMethod('setAppMode', {
      'packageName': packageName,
      'modeCode': modeCode,
    });
  }

  static Future<void> removeAppMode(String packageName) async {
    await _channel.invokeMethod('removeAppMode', {'packageName': packageName});
  }

  static Future<void> launchTweaker() async {
    await _channel.invokeMethod('launchTweaker');
  }
}
