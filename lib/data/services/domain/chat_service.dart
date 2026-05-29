import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService({required this.supabaseUrl});

  final String supabaseUrl;

  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> getChannelMessages(String channelId, {int retry = 0, int limit = 100, int offset = 0}) async {
    try {
      final msgs = List<Map<String, dynamic>>.from(
        await _db
            .from('messages')
            .select()
            .eq('channel_id', channelId)
            .order('created_at', ascending: false)
            .limit(limit)
            .range(offset, offset + limit - 1),
      );
      if (msgs.isEmpty) return msgs;
      final senderIds = msgs.map((m) => m['sender_id'] as String).toSet().toList();
      if (senderIds.isNotEmpty) {
        final profiles = await _db.from('profiles').select('id, pseudo, avatar_url, experience_points').filter('id', 'in', '(${senderIds.join(",")})');
        final profileMap = {for (final p in profiles) p['id'] as String: p};
        for (final msg in msgs) {
          msg['sender'] = profileMap[msg['sender_id'] as String] ?? {};
        }
      }
      return msgs..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    } catch (e) {
      developer.log('ChatService error: $e');
      if (retry < 3) {
        await Future.delayed(const Duration(seconds: 1));
        return getChannelMessages(channelId, retry: retry + 1, limit: limit, offset: offset);
      }
      return [];
    }
  }

  Future<bool> sendDirectMessage(
    String receiverId,
    String content, {
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
    int? duration,
  }) async {
    if (userId == null) return false;
    try {
      await _db.from('messages').insert({
        'sender_id': userId,
        'receiver_id': receiverId,
        'content': content,
        'status': 'sent',
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaType != null) 'media_type': mediaType,
        if (mediaName != null) 'media_name': mediaName,
        if (duration != null) 'duration': duration,
      });
      return true;
    } catch (e) {
      developer.log('sendDirectMessage error: $e');
      return false;
    }
  }

  Future<bool> sendMessage(
    String channelId,
    String content, {
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
    int? duration,
  }) async {
    if (userId == null) return false;
    try {
      await _db.from('messages').insert({
        'sender_id': userId,
        'channel_id': channelId,
        'content': content,
        'status': 'sent',
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaType != null) 'media_type': mediaType,
        if (mediaName != null) 'media_name': mediaName,
        if (duration != null) 'duration': duration,
      });
      return true;
    } catch (e) {
      developer.log('sendMessage error: $e');
      return false;
    }
  }

  Future<bool> sendCallEventMessage(
    String channelId,
    String callEventType, {
    String? callerName,
  }) async {
    if (userId == null) return false;
    final messages = {
      'started': 'Appel démarré',
      'ended': 'Appel terminé',
      'refused': 'Appel refusé',
      'missed': 'Appel sans réponse',
      'ringing': 'Appel en cours...',
    };
    final content = messages[callEventType] ?? 'Événement d\'appel';
    try {
      await _db.from('messages').insert({
        'sender_id': userId,
        'channel_id': channelId,
        'content': content,
        'status': 'sent',
        'media_type': 'call_event',
        'media_name': callEventType,
      });
      return true;
    } catch (e) {
      developer.log('sendCallEventMessage error: $e');
      return false;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (userId == null) return;
    try {
      await _db.from('messages').delete().eq('id', messageId);
    } catch (e) {
      developer.log('deleteMessage error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String peerId, {int retry = 0, int limit = 100, int offset = 0}) async {
    if (userId == null) return [];
    try {
      final sent = await _db
          .from('messages')
          .select()
          .eq('sender_id', userId!)
          .eq('receiver_id', peerId)
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);
      final received = await _db
          .from('messages')
          .select()
          .eq('sender_id', peerId)
          .eq('receiver_id', userId!)
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);
      final merged = {...sent, ...received}.toList();
      merged.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return merged.take(limit).toList()..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    } catch (e) {
      developer.log('getMessages error: $e');
      if (retry < 3) {
        await Future.delayed(const Duration(seconds: 1));
        return getMessages(peerId, retry: retry + 1, limit: limit, offset: offset);
      }
      return [];
    }
  }

  Future<void> markMessagesAsSeen(String peerId) async {
    if (userId == null) return;
    try {
      await _db
          .from('messages')
          .update({'status': 'seen'})
          .eq('sender_id', peerId)
          .eq('receiver_id', userId!)
          .neq('status', 'seen');
    } catch (e) {
      developer.log('markMessagesAsSeen error: $e');
    }
  }

  Future<void> markChannelMessagesAsDelivered(String channelId) async {
    if (userId == null) return;
    try {
      await _db
          .from('messages')
          .update({'status': 'delivered'})
          .eq('channel_id', channelId)
          .neq('sender_id', userId!)
          .eq('status', 'sent');
    } catch (_) {}
  }

  Future<Map<String, int>> getUnreadCounts() async {
    if (userId == null) return {};
    try {
      final rows = await _db
          .from('messages')
          .select('sender_id, status')
          .eq('receiver_id', userId!)
          .neq('status', 'seen');
      final counts = <String, int>{};
      for (final r in rows) {
        final sid = r['sender_id'] as String?;
        if (sid != null) {
          counts[sid] = (counts[sid] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      developer.log('getUnreadCounts error: $e');
      return {};
    }
  }

  Future<Map<String, int>> getTeamUnreadCounts() async {
    if (userId == null) return {};
    try {
      final teamRows = await _db
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId!);
      final teamIds = teamRows.map((t) => t['team_id'] as String).toList();
      if (teamIds.isEmpty) return {};
      final result = <String, int>{};
      for (final teamId in teamIds) {
        try {
          final channelId = await _getTeamChannelId(teamId);
          if (channelId == null) continue;
          final unread = await _db
              .from('messages')
              .select('id')
              .eq('channel_id', channelId)
              .neq('sender_id', userId!)
              .eq('status', 'sent');
          result[teamId] = unread.length;
        } catch (_) {
          result[teamId] = 0;
        }
      }
      return result;
    } catch (e) {
      developer.log('getTeamUnreadCounts error: $e');
      return {};
    }
  }

  Future<String?> _getTeamChannelId(String teamId) async {
    try {
      final team = await _db
          .from('teams')
          .select('squad_id')
          .eq('id', teamId)
          .maybeSingle();
      var squadId = team?['squad_id'] as String?;
      if (squadId == null) return null;
      final channels = await _db.from('channels').select('id').eq('squad_id', squadId).limit(1);
      if (channels.isNotEmpty) return channels.first['id'] as String;
    } catch (_) {}
    return null;
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String channelId) {
    final raw = _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .order('created_at', ascending: true);
    return raw.asyncMap((msgs) async {
      if (msgs.isEmpty) return msgs;
      final senderIds = msgs.map((m) => m['sender_id'] as String).toSet().toList();
      try {
        final profiles = await _db
            .from('profiles')
            .select('id, pseudo, avatar_url, experience_points')
            .filter('id', 'in', '(${senderIds.join(",")})');
        final profileMap = {for (final p in profiles) p['id'] as String: p};
        for (final msg in msgs) {
          msg['sender'] = profileMap[msg['sender_id'] as String] ?? {};
        }
      } catch (_) {
        for (final msg in msgs) {
          msg['sender'] = <String, dynamic>{};
        }
      }
      return msgs;
    });
  }

  RealtimeChannel subscribeToMessages(
      String channelName, void Function(Map<String, dynamic>) onMessage) {
    final channel = _db.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
    return channel;
  }
}
