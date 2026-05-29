import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_root.dart';
import '../../data/services/supabase_backend_service.dart';
import '../../features/dashboard/presentation/screens/dm_chat_screen.dart';
import '../../features/posts/presentation/screens/post_detail_screen.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';

final FlutterLocalNotificationsPlugin _bgPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _bgPlugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    final data = message.data;
    final type = data['type'];

    if (type == 'call') {
      final callerName = data['caller_name'] ?? 'Someone';
      final callType = data['call_type'] ?? 'audio';
      final typeLabel = callType == 'video' ? 'vidéo' : 'audio';
      final callId = data['call_id'] ?? '';
      final callerId = data['caller_id'] ?? '';
      final teamId = data['team_id'] as String?;
      final squadId = data['squad_id'] as String?;
      final groupName = data['group_name'] as String?;

      final payload = jsonEncode({
        'callId': callId,
        'callerId': callerId,
        'callType': callType,
        'type': 'incoming_call',
        if (teamId != null) 'teamId': teamId,
        if (squadId != null) 'squadId': squadId,
        if (groupName != null) 'groupName': groupName,
      });

      final androidDetails = AndroidNotificationDetails(
        NotificationService.incomingCallChannel,
        'Appels entrants',
        channelDescription: "Notifications d'appels entrants avec actions",
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.call,
        tag: 'incoming_call',
        actions: [
          AndroidNotificationAction('answer', 'Répondre', showsUserInterface: true),
          AndroidNotificationAction('decline', 'Refuser', showsUserInterface: false),
        ],
      );
      await _bgPlugin.show(
        1001, // fixed ID for incoming call
        groupName != null ? 'Appel de groupe: $groupName' : callerName,
        groupName != null ? 'Appel $typeLabel de $callerName' : 'Appel $typeLabel entrant',
        NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } else if (type == 'missed_call') {
      final callerName = data['caller_name'] ?? 'Someone';
      await _bgPlugin.cancel(1001);
      final androidDetails = AndroidNotificationDetails(
        NotificationService.messagesChannel,
        'Messages',
        channelDescription: 'Notifications de messages',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      await _bgPlugin.show(
        1002, // fixed ID for missed call
        'Missed call',
        'from $callerName',
        NotificationDetails(android: androidDetails),
      );
    } else if (type == 'message') {
      final senderName = data['sender_name'] ?? 'Someone';
      final content = data['content'] ?? '';

      final androidDetails = AndroidNotificationDetails(
        NotificationService.messagesChannel,
        'Messages',
        channelDescription: 'Notifications de messages',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      await _bgPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        senderName,
        content,
        NotificationDetails(android: androidDetails),
      );
    } else if (type == 'post_like' || type == 'post_comment' || type == 'comment_like' || type == 'comment_reply') {
      final senderName = data['sender_name'] ?? 'Someone';
      final content = data['content'] ?? '';
      final androidDetails = AndroidNotificationDetails(
        NotificationService.messagesChannel,
        'Messages',
        channelDescription: 'Notifications de messages',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      await _bgPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        senderName,
        content,
        NotificationDetails(android: androidDetails),
      );
    }
  } catch (e) {
    debugPrint('firebaseBackgroundHandler error: $e');
  }
}

class PushNavigationBus {
  static final _controller = StreamController<Map<String, dynamic>>.broadcast();
  static void add(Map<String, dynamic> data) => _controller.add(data);
  static Stream<Map<String, dynamic>> get stream => _controller.stream;
  static void dispose() => _controller.close();
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  FirebaseMessaging? _messaging;
  StreamSubscription? _tokenSub;

  bool get isAvailable => _messaging != null;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    } catch (e) {
      debugPrint('PushNotificationService.init error: $e');
    }
  }

  Future<void> register(String userId) async {
    if (_messaging == null) return;

    final permission = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      criticalAlert: true,
    );

    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push permission denied');
      return;
    }

    try {
      final token = await _messaging!.getToken();
      if (token != null) {
        await _upsertDeviceToken(userId, token);
      }
    } catch (e) {
      debugPrint('PushNotificationService.getToken error: $e');
    }

    _tokenSub?.cancel();
    _tokenSub = _messaging!.onTokenRefresh.listen((token) {
      _upsertDeviceToken(userId, token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  }

  Future<void> unregister() async {
    _tokenSub?.cancel();
    try {
      if (_messaging != null) {
        final token = await _messaging!.getToken();
        if (token != null) {
          await Supabase.instance.client
              .from('devices')
              .delete()
              .eq('token', token);
        }
      }
    } catch (e) {
      debugPrint('PushNotificationService.unregister error: $e');
    }
  }

  Future<void> _upsertDeviceToken(String userId, String token) async {
    try {
      await Supabase.instance.client.from('devices').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      debugPrint('PushNotificationService._upsertDeviceToken error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (type == 'call') {
      final callId = data['call_id'] ?? '';
      final callerId = data['caller_id'] ?? '';
      final callType = data['call_type'] ?? 'audio';
      final callerName = data['caller_name'] ?? 'Someone';
      final teamId = data['team_id'] as String?;
      final squadId = data['squad_id'] as String?;
      final groupName = data['group_name'] as String?;
      if (callId.isNotEmpty && callerId.isNotEmpty) {
        NotificationService().showIncomingCallNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          callerName: callerName,
          callType: callType,
          callId: callId,
          callerId: callerId,
          teamId: teamId,
          squadId: squadId,
          groupName: groupName,
        );
      }
    } else if (type == 'missed_call') {
      final callerName = data['caller_name'] ?? 'Someone';
      NotificationService().cancelNotification(1001);
      NotificationService().showMessageNotification(
        id: 1002,
        title: 'Missed call',
        body: 'from $callerName',
      );
    } else if (type == 'message') {
      final senderName = data['sender_name'] ?? 'Someone';
      final content = data['content'] ?? '';
      NotificationService().showMessageNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: senderName,
        body: content,
      );
    } else if (type == 'post_like' || type == 'post_comment' || type == 'comment_like' || type == 'comment_reply') {
      final senderName = data['sender_name'] ?? 'Someone';
      final content = data['content'] ?? '';
      NotificationService().showMessageNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: senderName,
        body: content,
      );
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final navKey = ProdixApp.navigatorKey;
    final context = navKey.currentContext;
    if (context == null) return;

    if (type == 'call') {
      // Just open the app — the call is NOT accepted.
      // The user must press "Répondre" action button to answer.
    } else if (type == 'message') {
      final senderId = data['sender_id'] as String? ?? '';
      if (senderId.isNotEmpty) {
        context.read<SupabaseBackendService>().getOtherProfile(senderId).then((profile) {
          final name = profile?['pseudo'] as String? ?? 'Inconnu';
          final avatar = profile?['avatar_url'] as String?;
          navKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => DmChatScreen(
                peerId: senderId,
                peerName: name,
                peerAvatar: avatar,
              ),
            ),
          );
        });
      }
    } else if (type == 'post_like' || type == 'post_comment' || type == 'comment_reply' || type == 'comment_like') {
      final postId = data['post_id'] as String?;
      if (postId != null && postId.isNotEmpty) {
        _navigateToPostDetail(navKey, postId);
      }
    } else if (type == 'missed_call') {
      final callerId = data['caller_id'] as String? ?? '';
      if (callerId.isNotEmpty) {
        context.read<SupabaseBackendService>().getOtherProfile(callerId).then((profile) {
          final name = profile?['pseudo'] as String? ?? 'Inconnu';
          final avatar = profile?['avatar_url'] as String?;
          navKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => DmChatScreen(
                peerId: callerId,
                peerName: name,
                peerAvatar: avatar,
              ),
            ),
          );
        });
      }
    } else if (type == 'invitation') {
      PushNavigationBus.add(data);
    }
  }

  void _navigateToPostDetail(GlobalKey<NavigatorState> navKey, String postId) {
    navKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }
}
