import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SocialService {
  SocialService({required this.supabaseUrl});

  final String supabaseUrl;

  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

  // ─── Teams ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyTeams() async {
    if (userId == null) return [];
    final response = await _db
        .from('team_members')
        .select(
            'team_id, role, joined_at, teams(id, name, avatar_url, status, game_id, owner_id, team_members(role, profiles(id, pseudo, avatar_url)))')
        .eq('user_id', userId!);
    return response.map((e) => e['teams'] as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createTeam(String name) async {
    if (userId == null) throw Exception('Not authenticated');
    final squadRes = await _db
        .from('squads')
        .insert({'name': name, 'owner_id': userId})
        .select()
        .single();
    await _db.from('squad_members').insert({
      'squad_id': squadRes['id'],
      'user_id': userId,
      'role': 'owner',
    });
    await _db.from('channels').insert({
      'squad_id': squadRes['id'],
      'name': 'général',
      'type': 'text',
    });
    Map<String, dynamic> res;
    try {
      res = await _db
          .from('teams')
          .insert({
            'name': name,
            'owner_id': userId,
            'status': 'active',
            'squad_id': squadRes['id'],
          })
          .select()
          .single();
    } catch (_) {
      res = await _db
          .from('teams')
          .insert({'name': name, 'owner_id': userId, 'status': 'active'})
          .select()
          .single();
    }
    await _db.from('team_members').insert({
      'team_id': res['id'],
      'user_id': userId,
      'role': 'leader',
    });
    return res;
  }

  Future<Map<String, dynamic>?> getTeamData(String teamId) async {
    try {
      return await _db.from('teams').select().eq('id', teamId).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    if (userId == null) return [];
    try {
      final rows = List<Map<String, dynamic>>.from(
        await _db.from('team_members').select().eq('team_id', teamId),
      );
      final ids = rows.map((r) => r['user_id'] as String).toList();
      if (ids.isEmpty) return rows;
      final profiles = await _db.from('profiles').select('id, pseudo, avatar_url, experience_points');
      final profileMap = {for (final p in profiles) p['id'] as String: p};
      for (final r in rows) {
        r['profiles'] = profileMap[r['user_id'] as String] ?? {};
      }
      return rows;
    } catch (e) {
      developer.log('SocialService error: $e');
      return [];
    }
  }

  Future<void> inviteToTeam(String teamId, String receiverProfileId) async {
    if (userId == null) return;
    final existing = await _db
        .from('invitations')
        .select('id')
        .eq('sender_id', userId!)
        .eq('receiver_id', receiverProfileId)
        .eq('status', 'pending')
        .maybeSingle();
    if (existing != null) {
      throw Exception('Invitation déjà envoyée à ce joueur.');
    }
    try {
      await _db.from('invitations').insert({
        'sender_id': userId,
        'receiver_id': receiverProfileId,
        'team_id': teamId,
        'status': 'pending',
      });
    } catch (e) {
      developer.log('inviteToTeam (team_id fallback): $e');
      await _db.from('invitations').insert({
        'sender_id': userId,
        'receiver_id': receiverProfileId,
        'status': 'pending',
      });
    }
  }

  Future<void> addMemberToTeam(String teamId, String friendId) async {
    if (userId == null) return;
    await _db.from('team_members').insert({
      'team_id': teamId,
      'user_id': friendId,
      'role': 'member',
    });
    final squadId = await _getTeamSquadId(teamId);
    if (squadId != null) {
      try {
        await _db.from('squad_members').insert({
          'squad_id': squadId,
          'user_id': friendId,
          'role': 'member',
        });
      } catch (_) {}
    }
  }

  Future<void> leaveTeam(String teamId) async {
    if (userId == null) return;
    await _db
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId!);
    final squadId = await _getTeamSquadId(teamId);
    if (squadId != null) {
      await _db
          .from('squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', userId!);
    }
  }

  Future<void> kickMember(String teamId, String targetUserId) async {
    await _db
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', targetUserId);
    final squadId = await _getTeamSquadId(teamId);
    if (squadId != null) {
      await _db
          .from('squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', targetUserId);
    }
  }

  Future<void> approveTeamMembership(String teamId) async {
    if (userId == null) return;
    await _db
        .from('team_members')
        .update({'status': 'active'})
        .eq('team_id', teamId)
        .eq('user_id', userId!);
    final squadId = await _getTeamSquadId(teamId);
    if (squadId != null) {
      try {
        await _db.from('squad_members').insert({
          'squad_id': squadId,
          'user_id': userId!,
          'role': 'member',
        });
      } catch (_) {}
    }
  }

  Future<void> declineTeamMembership(String teamId) async {
    if (userId == null) return;
    await _db
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId!);
  }

  Future<bool> isPendingTeamMember(String teamId) async {
    if (userId == null) return false;
    try {
      final row = await _db
          .from('team_members')
          .select('status')
          .eq('team_id', teamId)
          .eq('user_id', userId!)
          .maybeSingle();
      return row?['status'] == 'pending';
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTeamInvitableFriends(String teamId) async {
    if (userId == null) return [];
    try {
      final friends = await getFriends();
      final memberIds = (await _db
              .from('team_members')
              .select('user_id')
              .eq('team_id', teamId))
          .map((r) => r['user_id'] as String)
          .toList();
      return friends
          .where((f) => !memberIds.contains(f['id'] as String))
          .toList();
    } catch (e) {
      developer.log('getTeamInvitableFriends error: $e');
      return [];
    }
  }

  Future<String?> _getTeamSquadId(String teamId) async {
    try {
      final team =
          await _db.from('teams').select('squad_id, name, owner_id').eq('id', teamId).maybeSingle();
      if (team == null) return null;
      var sid = team['squad_id'] as String?;
      if (sid != null && sid.isNotEmpty) return sid;
      final squad = await _db
          .from('squads')
          .select('id')
          .eq('name', team['name'] as String)
          .eq('owner_id', team['owner_id'] as String)
          .maybeSingle();
      if (squad != null) {
        sid = squad['id'] as String;
        try {
          await _db.from('teams').update({'squad_id': sid}).eq('id', teamId);
        } catch (_) {}
        return sid;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getTeamChannelId(String teamId) async {
    var squadId = await _getTeamSquadId(teamId);
    if (squadId == null) {
      try {
        final team = await _db
            .from('teams')
            .select('name, owner_id')
            .eq('id', teamId)
            .maybeSingle();
        if (team == null) return null;
        final name = team['name'] as String;
        final ownerId = team['owner_id'] as String;
        final squadRes = await _db
            .from('squads')
            .insert({'name': name, 'owner_id': ownerId})
            .select()
            .single();
        squadId = squadRes['id'] as String;
        await _db.from('squad_members').insert({
          'squad_id': squadId,
          'user_id': ownerId,
          'role': 'owner',
        });
        try {
          final members = await _db
              .from('team_members')
              .select('user_id')
              .eq('team_id', teamId)
              .eq('status', 'active');
          for (final m in members) {
            final uid = m['user_id'] as String;
            if (uid != ownerId) {
              await _db.from('squad_members').insert({
                'squad_id': squadId,
                'user_id': uid,
                'role': 'member',
              });
            }
          }
        } catch (_) {}
        try {
          await _db.from('teams').update({'squad_id': squadId}).eq('id', teamId);
        } catch (_) {}
      } catch (_) {
        return null;
      }
    }
    try {
      final channels =
          await _db.from('channels').select('id').eq('squad_id', squadId).limit(1);
      if (channels.isNotEmpty) return channels.first['id'] as String;
    } catch (_) {}
    try {
      final ch = await _db
          .from('channels')
          .insert({'squad_id': squadId, 'name': 'général'})
          .select()
          .single();
      return ch['id'] as String;
    } catch (_) {}
    return null;
  }

  Future<String?> getSquadChannelId(String squadId) async {
    try {
      final channels =
          await _db.from('channels').select('id').eq('squad_id', squadId).limit(1);
      if (channels.isNotEmpty) return channels.first['id'] as String;
    } catch (_) {}
    try {
      final ch = await _db
          .from('channels')
          .insert({'squad_id': squadId, 'name': 'général'})
          .select()
          .single();
      return ch['id'] as String;
    } catch (_) {}
    return null;
  }

  Future<void> createChannel(String squadId, String name) async {
    await _db.from('channels').insert({
      'squad_id': squadId,
      'name': name,
      'type': 'text',
    });
  }

  Future<List<Map<String, dynamic>>> getChannels(String squadId) async {
    return List<Map<String, dynamic>>.from(await _db
        .from('channels')
        .select()
        .eq('squad_id', squadId)
        .order('name'));
  }

  // ─── Squads ───────────────────────────────────────────────────

  Future<void> createSquad(String name) async {
    if (userId == null) return;
    final res = await _db
        .from('squads')
        .insert({'name': name, 'owner_id': userId})
        .select()
        .single();
    await _db.from('squad_members').insert({
      'squad_id': res['id'],
      'user_id': userId,
      'role': 'owner',
    });
    await createChannel(res['id'] as String, 'général');
  }

  Future<List<Map<String, dynamic>>> getSquads() async {
    if (userId == null) return [];
    final response = await _db
        .from('squad_members')
        .select('squad_id, role, squads(id, name, logo_url, owner_id)')
        .eq('user_id', userId!);
    return response.map((e) => e['squads'] as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getSquadMembers(String squadId) async {
    try {
      final members = List<Map<String, dynamic>>.from(
        await _db.from('squad_members').select('user_id, role').eq('squad_id', squadId),
      );
      final ids = members.map((m) => m['user_id'] as String).toList();
      if (ids.isEmpty) return members;
      final profiles = await _db.from('profiles').select('id, pseudo, avatar_url').filter('id', 'in', '(${ids.join(",")})');
      final profileMap = {for (final p in profiles) p['id'] as String: p};
      for (final m in members) {
        m['profiles'] = profileMap[m['user_id'] as String] ?? {};
      }
      return members;
    } catch (e) {
      developer.log('SocialService error: $e');
      return [];
    }
  }

  // ─── Friends ──────────────────────────────────────────────────

  Future<List<String>> _getFriendIds() async {
    if (userId == null) return [];
    try {
      final rows = await _db
          .from('friends')
          .select('friend_id')
          .eq('user_id', userId!);
      return rows.map((r) => r['friend_id'] as String).toList();
    } catch (e) {
      developer.log('_getFriendIds error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    if (userId == null) return [];
    try {
      final rows = await _db
          .from('friends')
          .select('friend_id')
          .eq('user_id', userId!);
      final ids = rows.map((r) => r['friend_id'] as String).toList();
      if (ids.isEmpty) return [];
      return List<Map<String, dynamic>>.from(
        await _db.from('profiles').select('id, pseudo, avatar_url, game_type, region, rank_mmr').filter('id', 'in', '(${ids.join(",")})'),
      );
    } catch (e) {
      developer.log('SocialService error: $e');
      return [];
    }
  }

  // ─── Invitations ──────────────────────────────────────────────

  Future<void> sendInvitation(String receiverProfileId) async {
    if (userId == null) return;
    final existing = await _db
        .from('invitations')
        .select('id')
        .eq('sender_id', userId!)
        .eq('receiver_id', receiverProfileId)
        .eq('status', 'pending')
        .maybeSingle();
    if (existing != null) {
      throw Exception('Invitation déjà envoyée à ce joueur.');
    }
    await _db.from('invitations').insert({
      'sender_id': userId,
      'receiver_id': receiverProfileId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getInvitations() async {
    if (userId == null) return [];
    final response = await _db
        .from('invitations')
        .select('*, sender:profiles!invitations_sender_id_fkey(id, pseudo, avatar_url)')
        .eq('receiver_id', userId!)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Set<String>> getSentInvitationIds() async {
    if (userId == null) return {};
    final response = await _db
        .from('invitations')
        .select('receiver_id')
        .eq('sender_id', userId!)
        .eq('status', 'pending');
    return response.map((r) => r['receiver_id'] as String).toSet();
  }

  Future<void> respondInvitation(String invitationId, bool accept) async {
    String? senderId;
    String? teamId;
    try {
      final inv = await _db.from('invitations').select('sender_id, team_id').eq('id', invitationId).maybeSingle();
      senderId = inv?['sender_id'] as String?;
      teamId = inv?['team_id'] as String?;
    } catch (_) {
      final inv = await _db.from('invitations').select('sender_id').eq('id', invitationId).maybeSingle();
      senderId = inv?['sender_id'] as String?;
    }
    await _db.from('invitations').update({
      'status': accept ? 'accepted' : 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', invitationId);

    if (accept && userId != null) {
      if (teamId != null) {
        await _db.from('team_members').insert({
          'team_id': teamId,
          'user_id': userId!,
          'role': 'member',
          'status': 'pending',
        });
      } else if (senderId != null) {
        await _db.from('sessions').insert({
          'invitation_id': invitationId,
          'status': 'active',
        });
        await _addFriend(userId!, senderId);
        await _createSharedSquad(userId!, senderId);
      }
    }
  }

  Future<void> respondToInvitation(String invitationId, bool accept) =>
      respondInvitation(invitationId, accept);

  Future<List<Map<String, dynamic>>> getMyInvitations() => getInvitations();

  Future<void> _addFriend(String uid1, String uid2) async {
    await _db.from('friends').upsert({'user_id': uid1, 'friend_id': uid2});
    await _db.from('friends').upsert({'user_id': uid2, 'friend_id': uid1});
  }

  Future<void> _createSharedSquad(String uid1, String uid2) async {
    final p1 = await _db.from('profiles').select('pseudo').eq('id', uid1).maybeSingle();
    final p2 = await _db.from('profiles').select('pseudo').eq('id', uid2).maybeSingle();
    final name = '${p1?['pseudo'] ?? 'Player'} & ${p2?['pseudo'] ?? 'Player'}';
    final existing = await _db
        .from('squad_members')
        .select('squad_id')
        .eq('user_id', uid1);
    final existingIds = existing.map((e) => e['squad_id'] as String).toList();
    if (existingIds.isNotEmpty) {
      final shared = await _db
          .from('squad_members')
          .select('squad_id')
          .filter('squad_id', 'in', '(${existingIds.join(",")})')
          .eq('user_id', uid2)
          .maybeSingle();
      if (shared != null) return;
    }
    final res = await _db.from('squads').insert({
      'name': name,
      'owner_id': uid1,
    }).select().single();
    await _db.from('squad_members').insert([
      {'squad_id': res['id'], 'user_id': uid1, 'role': 'owner'},
      {'squad_id': res['id'], 'user_id': uid2, 'role': 'member'},
    ]);
    await createChannel(res['id'] as String, 'général');
  }

  Future<int> getPendingInvitationsCount() async {
    if (userId == null) return 0;
    try {
      final rows = await _db
          .from('invitations')
          .select('id')
          .eq('receiver_id', userId!)
          .eq('status', 'pending');
      return rows.length;
    } catch (e) {
      developer.log('SocialService error: $e');
      return 0;
    }
  }

  RealtimeChannel subscribeToInvitations(
    String userId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    final channel = _db.channel('invitations_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'invitations',
          callback: (payload) {
            if (payload.newRecord['receiver_id'] == userId) {
              onChange(payload.newRecord);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'invitations',
          callback: (payload) {
            if (payload.newRecord['receiver_id'] == userId) {
              onChange(payload.newRecord);
            }
          },
        )
        .subscribe();
    return channel;
  }

  /// Update team avatar (owner only — enforced via RLS)
  Future<String?> updateTeamAvatar(String teamId, Uint8List bytes) async {
    if (userId == null) return null;
    try {
      final ext = 'png';
      final fileName = 'team_${teamId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from('team_avatars').uploadBinary(fileName, bytes);
      final url = _db.storage.from('team_avatars').getPublicUrl(fileName);
      await _db.from('teams').update({'avatar_url': url}).eq('id', teamId);
      return url;
    } catch (e) {
      developer.log('updateTeamAvatar error: $e');
      return null;
    }
  }

  // ─── Search ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchPlayers(String query) async {
    if (userId == null || query.trim().isEmpty) return [];
    final friendIds = await _getFriendIds();
    var q = _db
        .from('profiles')
        .select()
        .neq('id', userId!)
        .ilike('pseudo', '%${query.trim()}%');
    if (friendIds.isNotEmpty) {
      q = q.not('id', 'in', '(${friendIds.join(",")})');
    }
    final response = await q.limit(20);
    return List<Map<String, dynamic>>.from(response);
  }
}
