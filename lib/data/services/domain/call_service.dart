import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class CallService {
  CallService({required this.supabaseUrl});

  final String supabaseUrl;

  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

  // ─── P2P Calls ────────────────────────────────────────────────

  Future<String?> initiateCall(String calleeId, {String callType = 'audio'}) async {
    if (userId == null) return null;
    try {
      final res = await _db.from('calls').insert({
        'caller_id': userId,
        'callee_id': calleeId,
        'status': 'ringing',
        'call_type': callType,
      }).select().single();
      return res['id'] as String?;
    } catch (e) {
      developer.log('initiateCall error: $e');
      return null;
    }
  }

  Future<void> updateCallStatus(String callId, String status) async {
    try {
      await _db.from('calls').update({'status': status}).eq('id', callId);
    } catch (e) {
      developer.log('updateCallStatus error: $e');
    }
  }

  Future<Map<String, dynamic>?> getCall(String callId) async {
    try {
      return await _db.from('calls').select().eq('id', callId).maybeSingle();
    } catch (e) {
      developer.log('getCall error: $e');
      return null;
    }
  }

  Future<void> updateCallSdp(String callId, String sdpJson, String type) async {
    try {
      final update = type == 'offer'
          ? {'offer_sdp': sdpJson}
          : {'answer_sdp': sdpJson};
      await _db.from('calls').update(update).eq('id', callId);
    } catch (e) {
      developer.log('updateCallSdp error: $e');
    }
  }

  Future<void> addIceCandidate(
    String callId,
    String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  ) async {
    if (userId == null) return;
    try {
      await _db.from('call_ice_candidates').insert({
        'call_id': callId,
        'sender_id': userId,
        'candidate': candidate,
        'sdp_mid': sdpMid,
        'sdp_mline_index': sdpMLineIndex,
      });
    } catch (e) {
      developer.log('addIceCandidate error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getIceCandidates(String callId) async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db
            .from('call_ice_candidates')
            .select()
            .eq('call_id', callId)
            .order('created_at', ascending: true),
      );
    } catch (e) {
      developer.log('getIceCandidates error: $e');
      return [];
    }
  }

  Future<void> cleanStaleCalls() async {
    if (userId == null) return;
    try {
      final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String();
      await _db
          .from('calls')
          .update({'status': 'missed'})
          .eq('callee_id', userId!)
          .eq('status', 'ringing')
          .lt('created_at', cutoff);
    } catch (e) {
      developer.log('cleanStaleCalls error: $e');
    }
  }

  RealtimeChannel subscribeToCalls(
    String userId,
    void Function(Map<String, dynamic>) onCall,
  ) {
    final channel = _db.channel('calls_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          callback: (payload) {
            final calleeId = payload.newRecord['callee_id'] as String?;
            if (calleeId == userId) onCall(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToIceCandidates(
    String callId,
    void Function(Map<String, dynamic>) onCandidate,
  ) {
    final channel = _db.channel('ice_$callId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_ice_candidates',
          callback: (payload) {
            if (payload.newRecord['sender_id'] != userId) {
              onCandidate(payload.newRecord);
            }
          },
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToCallSdp(
    String callId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('sdp_$callId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['offer_sdp'] != null || newRecord['answer_sdp'] != null) {
              onChange(newRecord);
            }
          },
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToCallStatus(
    String callId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('callstatus_$callId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          callback: (payload) {
            onChange(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  // ─── Team Calls ───────────────────────────────────────────────

  Future<String?> initiateTeamCall(String teamId, {String callType = 'audio'}) async {
    if (userId == null) return null;
    try {
      final res = await _db.from('team_calls').insert({
        'team_id': teamId,
        'caller_id': userId,
        'call_type': callType,
        'status': 'ringing',
      }).select().single();
      final callId = res['id'] as String;
      final members = await _getTeamMembers(teamId);
      for (final m in members) {
        final uid = m['user_id'] as String;
        if (uid != userId) {
          await _db.from('team_call_participants').insert({
            'call_id': callId,
            'user_id': uid,
            'status': 'ringing',
          });
        }
      }
      await _db.from('team_call_participants').insert({
        'call_id': callId,
        'user_id': userId!,
        'status': 'joined',
        'joined_at': DateTime.now().toIso8601String(),
      });
      return callId;
    } catch (e) {
      developer.log('initiateTeamCall error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTeamCall(String callId) async {
    try {
      return await _db.from('team_calls').select().eq('id', callId).maybeSingle();
    } catch (e) {
      developer.log('getTeamCall error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTeamCallParticipants(String callId) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await _db.from('team_call_participants').select().eq('call_id', callId),
      );
      final ids = rows.map((r) => r['user_id'] as String).toList();
      if (ids.isNotEmpty) {
        final profiles = await _db.from('profiles').select('id, pseudo, avatar_url').filter('id', 'in', '(${ids.join(",")})');
        final profileMap = {for (final p in profiles) p['id'] as String: p};
        for (final r in rows) {
          r['profiles'] = profileMap[r['user_id'] as String] ?? {};
        }
      }
      return rows;
    } catch (e) {
      developer.log('getTeamCallParticipants error: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamTeamCallParticipants(String callId) {
    return _db
      .from('team_call_participants')
      .stream(primaryKey: ['id'])
      .eq('call_id', callId)
      .asyncMap((rows) async {
        if (rows.isEmpty) return rows;
        final ids = rows.map((r) => r['user_id'] as String).toList();
        try {
          final profiles = await _db
            .from('profiles')
            .select('id, pseudo, avatar_url')
            .filter('id', 'in', '(${ids.join(",")})');
          final profileMap = {for (final p in profiles) p['id'] as String: p};
          for (final r in rows) {
            r['profiles'] = profileMap[r['user_id'] as String] ?? {};
          }
        } catch (_) {
          for (final r in rows) {
            r['profiles'] = <String, dynamic>{};
          }
        }
        return rows;
      });
  }

  Future<void> joinTeamCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('team_call_participants')
        .update({'status': 'joined', 'joined_at': DateTime.now().toIso8601String()})
        .eq('call_id', callId)
        .eq('user_id', userId!);
    } catch (e) {
      developer.log('joinTeamCall error: $e');
    }
  }

  Future<void> declineTeamCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('team_call_participants')
        .update({'status': 'declined'})
        .eq('call_id', callId)
        .eq('user_id', userId!);
    } catch (e) {
      developer.log('declineTeamCall error: $e');
    }
  }

  Future<void> endTeamCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('team_calls')
        .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
        .eq('id', callId)
        .eq('caller_id', userId!);
    } catch (e) {
      developer.log('endTeamCall error: $e');
    }
  }

  Future<void> leaveTeamCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('team_call_participants')
        .update({'status': 'left', 'left_at': DateTime.now().toIso8601String()})
        .eq('call_id', callId)
        .eq('user_id', userId!);
    } catch (e) {
      developer.log('leaveTeamCall error: $e');
    }
  }

  Future<void> updateTeamCallParticipantSdp(String participantId, String sdpJson, String type) async {
    try {
      final update = type == 'offer' ? {'offer_sdp': sdpJson} : {'answer_sdp': sdpJson};
      await _db.from('team_call_participants').update(update).eq('id', participantId);
    } catch (e) {
      developer.log('updateTeamCallParticipantSdp error: $e');
    }
  }

  Future<Map<String, dynamic>?> getTeamCallParticipant(String callId, String userId) async {
    try {
      return await _db
        .from('team_call_participants')
        .select()
        .eq('call_id', callId)
        .eq('user_id', userId)
        .maybeSingle();
    } catch (e) {
      developer.log('getTeamCallParticipant error: $e');
      return null;
    }
  }

  Future<void> addTeamCallIceCandidate(
    String participantId,
    String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  ) async {
    if (userId == null) return;
    try {
      await _db.from('team_call_ice_candidates').insert({
        'participant_id': participantId,
        'sender_id': userId,
        'candidate': candidate,
        'sdp_mid': sdpMid,
        'sdp_mline_index': sdpMLineIndex,
      });
    } catch (e) {
      developer.log('addTeamCallIceCandidate error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTeamCallIceCandidates(String participantId) async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db
          .from('team_call_ice_candidates')
          .select()
          .eq('participant_id', participantId)
          .order('created_at', ascending: true),
      );
    } catch (e) {
      developer.log('getTeamCallIceCandidates error: $e');
      return [];
    }
  }

  RealtimeChannel subscribeToTeamCallParticipants(
    String callId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('tcp_$callId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'team_call_participants',
        callback: (payload) {
          final recCallId = payload.newRecord['call_id'] as String?;
          if (recCallId == callId) onChange(payload.newRecord);
        },
      )
      .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToTeamCallSdp(
    String participantId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('tcsdp_$participantId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'team_call_participants',
        callback: (payload) {
          if (payload.newRecord['id'] == participantId &&
              (payload.newRecord['offer_sdp'] != null || payload.newRecord['answer_sdp'] != null)) {
            onChange(payload.newRecord);
          }
        },
      )
      .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToTeamCallStatus(
    String callId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('tcstatus_$callId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'team_calls',
        callback: (payload) {
          if (payload.newRecord['id'] == callId) onChange(payload.newRecord);
        },
      )
      .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToIncomingTeamCalls(
    String userId,
    void Function(Map<String, dynamic>) onCall,
  ) {
    final channel = _db.channel('incoming_tc_$userId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'team_call_participants',
        callback: (payload) {
          if (payload.newRecord['user_id'] == userId &&
              payload.newRecord['status'] == 'ringing') {
            getTeamCall(payload.newRecord['call_id'] as String).then((call) {
              if (call != null) onCall(call);
            });
          }
        },
      )
      .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToTeamCallIceCandidates(
    String participantId,
    String userId,
    void Function(Map<String, dynamic>) onCandidate,
  ) {
    final channel = _db.channel('tcice_$participantId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'team_call_ice_candidates',
        callback: (payload) {
          if (payload.newRecord['sender_id'] != userId) {
            onCandidate(payload.newRecord);
          }
        },
      )
      .subscribe();
    return channel;
  }

  // ─── Squad Calls ──────────────────────────────────────────────

  Future<String?> initiateSquadCall(String squadId, {String callType = 'audio'}) async {
    if (userId == null) return null;
    try {
      final res = await _db.from('squad_calls').insert({
        'squad_id': squadId,
        'caller_id': userId,
        'call_type': callType,
        'status': 'ringing',
      }).select().single();
      final callId = res['id'] as String;
      final members = await _getSquadMembers(squadId);
      for (final m in members) {
        final uid = m['user_id'] as String;
        if (uid != userId) {
          await _db.from('squad_call_participants').insert({
            'call_id': callId,
            'user_id': uid,
            'status': 'ringing',
          });
        }
      }
      await _db.from('squad_call_participants').insert({
        'call_id': callId,
        'user_id': userId!,
        'status': 'joined',
        'joined_at': DateTime.now().toIso8601String(),
      });
      return callId;
    } catch (e) {
      developer.log('initiateSquadCall error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSquadCall(String callId) async {
    try {
      return await _db.from('squad_calls').select().eq('id', callId).maybeSingle();
    } catch (e) {
      developer.log('getSquadCall error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSquadCallParticipants(String callId) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await _db.from('squad_call_participants').select().eq('call_id', callId),
      );
      final ids = rows.map((r) => r['user_id'] as String).toList();
      if (ids.isNotEmpty) {
        final profiles = await _db.from('profiles').select('id, pseudo, avatar_url').filter('id', 'in', '(${ids.join(",")})');
        final profileMap = {for (final p in profiles) p['id'] as String: p};
        for (final r in rows) {
          r['profiles'] = profileMap[r['user_id'] as String] ?? {};
        }
      }
      return rows;
    } catch (e) {
      developer.log('getSquadCallParticipants error: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamSquadCallParticipants(String callId) {
    return _db
      .from('squad_call_participants')
      .stream(primaryKey: ['id'])
      .eq('call_id', callId)
      .asyncMap((rows) async {
        if (rows.isEmpty) return rows;
        final ids = rows.map((r) => r['user_id'] as String).toList();
        try {
          final profiles = await _db
            .from('profiles')
            .select('id, pseudo, avatar_url')
            .filter('id', 'in', '(${ids.join(",")})');
          final profileMap = {for (final p in profiles) p['id'] as String: p};
          for (final r in rows) {
            r['profiles'] = profileMap[r['user_id'] as String] ?? {};
          }
        } catch (_) {
          for (final r in rows) {
            r['profiles'] = <String, dynamic>{};
          }
        }
        return rows;
      });
  }

  Future<void> joinSquadCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('squad_call_participants')
        .update({'status': 'joined', 'joined_at': DateTime.now().toIso8601String()})
        .eq('call_id', callId)
        .eq('user_id', userId!);
    } catch (e) {
      developer.log('joinSquadCall error: $e');
    }
  }

  Future<void> declineSquadCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('squad_call_participants')
        .update({'status': 'declined'})
        .eq('call_id', callId)
        .eq('user_id', userId!);
    } catch (e) {
      developer.log('declineSquadCall error: $e');
    }
  }

  Future<void> endSquadCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('squad_calls')
        .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
        .eq('id', callId)
        .eq('caller_id', userId!);
    } catch (e) {
      developer.log('endSquadCall error: $e');
    }
  }

  Future<void> leaveSquadCall(String callId) async {
    if (userId == null) return;
    try {
      await _db.from('squad_call_participants')
        .update({'status': 'left', 'left_at': DateTime.now().toIso8601String()})
        .eq('call_id', callId)
        .eq('user_id', userId!);
    } catch (e) {
      developer.log('leaveSquadCall error: $e');
    }
  }

  Future<void> updateSquadCallParticipantSdp(String participantId, String sdpJson, String type) async {
    try {
      final update = type == 'offer' ? {'offer_sdp': sdpJson} : {'answer_sdp': sdpJson};
      await _db.from('squad_call_participants').update(update).eq('id', participantId);
    } catch (e) {
      developer.log('updateSquadCallParticipantSdp error: $e');
    }
  }

  Future<Map<String, dynamic>?> getSquadCallParticipant(String callId, String userId) async {
    try {
      return await _db
        .from('squad_call_participants')
        .select()
        .eq('call_id', callId)
        .eq('user_id', userId)
        .maybeSingle();
    } catch (e) {
      developer.log('getSquadCallParticipant error: $e');
      return null;
    }
  }

  Future<void> addSquadCallIceCandidate(
    String participantId,
    String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  ) async {
    if (userId == null) return;
    try {
      await _db.from('squad_call_ice_candidates').insert({
        'participant_id': participantId,
        'sender_id': userId,
        'candidate': candidate,
        'sdp_mid': sdpMid,
        'sdp_mline_index': sdpMLineIndex,
      });
    } catch (e) {
      developer.log('addSquadCallIceCandidate error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSquadCallIceCandidates(String participantId) async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db
          .from('squad_call_ice_candidates')
          .select()
          .eq('participant_id', participantId)
          .order('created_at', ascending: true),
      );
    } catch (e) {
      developer.log('getSquadCallIceCandidates error: $e');
      return [];
    }
  }

  RealtimeChannel subscribeToSquadCallSdp(
    String participantId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('scsdp_$participantId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'squad_call_participants',
        callback: (payload) {
          if (payload.newRecord['id'] == participantId &&
              (payload.newRecord['offer_sdp'] != null || payload.newRecord['answer_sdp'] != null)) {
            onChange(payload.newRecord);
          }
        },
      )
      .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToSquadCallStatus(
    String callId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('scstatus_$callId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'squad_calls',
        callback: (payload) {
          if (payload.newRecord['id'] == callId) onChange(payload.newRecord);
        },
      )
      .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToIncomingSquadCalls(
    String userId,
    void Function(Map<String, dynamic>) onCall,
  ) {
    final channel = _db.channel('incoming_sc_$userId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'squad_call_participants',
        callback: (payload) {
          if (payload.newRecord['user_id'] == userId &&
              payload.newRecord['status'] == 'ringing') {
            getSquadCall(payload.newRecord['call_id'] as String).then((call) {
              if (call != null) onCall(call);
            });
          }
        },
      )
      .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToSquadCallIceCandidates(
    String participantId,
    String userId,
    void Function(Map<String, dynamic>) onCandidate,
  ) {
    final channel = _db.channel('scice_$participantId');
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'squad_call_ice_candidates',
        callback: (payload) {
          if (payload.newRecord['sender_id'] != userId) {
            onCandidate(payload.newRecord);
          }
        },
      )
      .subscribe();
    return channel;
  }

  // ─── Helpers ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _getTeamMembers(String teamId) async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db.from('team_members').select('user_id').eq('team_id', teamId),
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getSquadMembers(String squadId) async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db.from('squad_members').select('user_id').eq('squad_id', squadId),
      );
    } catch (_) {
      return [];
    }
  }
}
