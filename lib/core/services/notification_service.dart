import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CallActionBus {
  static final _controller = StreamController<CallAction>.broadcast();

  static void add(CallAction action) => _controller.add(action);
  static Stream<CallAction> get stream => _controller.stream;

  static void dispose() => _controller.close();
}

enum CallAction { toggleMute, toggleSpeaker, endCall }

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String actionId, String? payload)? onNotificationAction;

  static const _incomingCallChannel = 'incoming_calls_channel';
  static const _ongoingCallChannel = 'ongoing_call_channel';
  static const _callsChannel = 'calls_channel';
  static const _messagesChannel = 'messages_channel';

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    debugPrint('NotificationService action: $actionId payload: $payload');
    if (actionId == null) return;
    if (actionId == 'mute' || actionId == 'unmute' || actionId == 'speaker' || actionId == 'speaker_off') {
      if (actionId == 'mute' || actionId == 'unmute') {
        CallActionBus.add(CallAction.toggleMute);
      } else {
        CallActionBus.add(CallAction.toggleSpeaker);
      }
      return;
    }
    if (actionId == 'end_call') {
      CallActionBus.add(CallAction.endCall);
    }
    if (onNotificationAction != null) {
      onNotificationAction!(actionId, payload);
    }
  }

  Future<void> showIncomingCallNotification({
    required int id,
    required String callerName,
    required String callType,
    required String callId,
    required String callerId,
    String? teamId,
    String? squadId,
    String? groupName,
  }) async {
    final typeLabel = callType == 'video' ? 'vidéo' : 'audio';
    final androidDetails = AndroidNotificationDetails(
      _incomingCallChannel,
      'Appels entrants',
      channelDescription: 'Notifications d\'appels entrants avec actions',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.call,
      actions: [
        AndroidNotificationAction('answer', 'Répondre',
            showsUserInterface: true),
        AndroidNotificationAction('decline', 'Refuser',
            showsUserInterface: true),
      ],
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(
      1001,
      groupName != null ? 'Appel de groupe: $groupName' : 'Appel $typeLabel de $callerName',
      groupName != null ? 'Appel $typeLabel de $callerName' : 'Appel $typeLabel entrant',
      details,
      payload: jsonEncode({
        'callId': callId,
        'callerId': callerId,
        'callType': callType,
        'type': 'incoming_call',
        if (teamId != null) 'teamId': teamId,
        if (squadId != null) 'squadId': squadId,
        if (groupName != null) 'groupName': groupName,
      }),
    );
  }

  Future<void> showOngoingCallNotification({
    required int id,
    required String peerName,
    required String callType,
    String callState = 'connected',
    bool isMuted = false,
    bool isSpeaker = false,
    String? callId,
  }) async {
    final typeLabel = callType == 'video' ? 'vidéo' : 'audio';
    final body = callState == 'ringing'
        ? 'En attente de réponse...'
        : (isMuted ? 'Micro coupé' : 'Micro actif');
    final actions = <AndroidNotificationAction>[
      if (callState == 'connected') ...[
        AndroidNotificationAction(
          isMuted ? 'unmute' : 'mute',
          isMuted ? 'Activer micro' : 'Muet',
        ),
        AndroidNotificationAction(
          isSpeaker ? 'speaker_off' : 'speaker',
          isSpeaker ? 'Haut-parleur off' : 'Haut-parleur',
        ),
      ],
      AndroidNotificationAction('end_call', 'Raccrocher'),
    ];
    final androidDetails = AndroidNotificationDetails(
      _ongoingCallChannel,
      'Appel en cours',
      channelDescription: 'Notification persistante pour appel actif',
      importance: Importance.low,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      actions: actions,
    );
    final details = NotificationDetails(android: androidDetails);
    final payload = callId != null ? jsonEncode({'callId': callId, 'type': 'ongoing_call'}) : null;
    await _plugin.show(
      id,
      'Appel $typeLabel - $peerName',
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showCallNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _callsChannel,
      'Appels',
      channelDescription: 'Notifications d\'appels entrants',
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> showMessageNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _messagesChannel,
      'Messages',
      channelDescription: 'Notifications de messages',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
