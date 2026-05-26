import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prodix/core/services/notification_service.dart';

const String periodicCheckTask = 'periodicCallCheck';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == periodicCheckTask) {
      final url = inputData?['supabaseUrl'] as String?;
      final key = inputData?['supabaseAnonKey'] as String?;
      if (url == null || key == null) return Future.value(false);
      Supabase.initialize(url: url, anonKey: key);
      final client = Supabase.instance.client;
      await _checkNewCallsAndMessages(client);
    }
    return Future.value(true);
  });
}

Future<void> _checkNewCallsAndMessages(SupabaseClient supabase) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;
    final notif = NotificationService();
  final calls = await supabase
      .from('calls')
      .select('id, caller_id, call_type, status, created_at')
      .eq('callee_id', userId)
      .eq('status', 'ringing')
      .order('created_at', ascending: false)
      .limit(5);
  for (final call in calls) {
    final callerId = call['caller_id'] as String?;
    if (callerId == null) continue;
    final profile = await supabase
        .from('profiles')
        .select('pseudo')
        .eq('id', callerId)
        .single();
    final name = profile['pseudo'] as String? ?? 'Quelqu\'un';
    final callType = call['call_type'] as String? ?? 'audio';
    final callId = call['id'] as String;
    await notif.showIncomingCallNotification(
      id: 100 + (callId.hashCode % 100),
      callerName: name,
      callType: callType,
      callId: callId,
      callerId: callerId,
    );
  }
  final conversations = await supabase
      .from('conversations')
      .select(
          '*, profiles!conversations_participant1_id_fkey(pseudo), profiles!conversations_participant2_id_fkey(pseudo)')
      .or('participant1_id.eq.$userId,participant2_id.eq.$userId');
  int msgIndex = 0;
  for (final conv in conversations) {
    final otherProfile = conv['participant1_id'] == userId
        ? (conv['profiles!conversations_participant2_id_fkey'] as Map?)
        : (conv['profiles!conversations_participant1_id_fkey'] as Map?);
    final otherName = otherProfile?['pseudo'] as String? ?? 'Quelqu\'un';
    final msgs = await supabase
        .from('messages')
        .select('content')
        .eq('conversation_id', conv['id'])
        .neq('sender_id', userId)
        .neq('media_type', 'call_event')
        .order('created_at', ascending: false)
        .limit(3);
    for (final msg in msgs) {
      final content = msg['content'] as String? ?? '';
      if (content.isEmpty) continue;
      await notif.showMessageNotification(
        id: 200 + msgIndex,
        title: otherName,
        body: content,
      );
      msgIndex++;
    }
  }
}
