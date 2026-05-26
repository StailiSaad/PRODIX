import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/profile_defaults.dart';

class SupabaseBackendService {
  SupabaseBackendService({required this.isEnabled, required this.baseUrl});

  final bool isEnabled;
  final String baseUrl;

  SupabaseClient get _db => Supabase.instance.client;

  void _requireEnabled() {
    if (!isEnabled) throw Exception('Supabase backend is not enabled. Check your configuration.');
  }

  String? get userId => _db.auth.currentUser?.id;
  User? get currentUser => _db.auth.currentUser;
  Session? get currentSession => _db.auth.currentSession;

  // ─── Auth ────────────────────────────────────────────────────────────────────
  Future<void> signUp(String email, String password, String pseudo) async {
    _requireEnabled();
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'pseudo': pseudo},
    );
    if (res.user == null) throw Exception('Inscription échouée.');

    // Insert into public.users (required by FK constraints)
    await _db.from('users').insert({
      'id': res.user!.id,
      'email': email,
      'password_hash': 'managed_by_supabase_auth',
    });

    // Create profile
    await _db.from('profiles').upsert({
      'id': res.user!.id,
      'pseudo': pseudo,
      'experience_points': ProfileDefaults.xp,
      'language': ProfileDefaults.language,
      'availability': ProfileDefaults.availability,
      'game_type': ProfileDefaults.gameType,
      'role': ProfileDefaults.role,
      'region': ProfileDefaults.region,
      'bio': ProfileDefaults.bio,
    });
  }

  Future<void> signIn(String email, String password) async {
    _requireEnabled();
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    _requireEnabled();
    await _db.auth.signOut();
  }

  // ─── Profile ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getProfile() async {
    if (userId == null) return null;
    try {
      return await _db
          .from('profiles')
          .select()
          .eq('id', userId!)
          .maybeSingle();
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return null;
    }
  }

  Future<void> updateProfile({
    required String pseudo,
    int? xp,
    required String language,
    required String availability,
    required String gameType,
    required String role,
    required String region,
    required String bio,
    String? avatarUrl,
    String? birthDate,
    List<String>? favoriteGames,
    String? phone,
    String? location,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    String? socialInstagram,
    String? socialFacebook,
    String? socialGithub,
    String? country,
  }) async {
    if (userId == null) return;
    await _db.from('profiles').upsert({
      'id': userId,
      'pseudo': pseudo,
      'language': language,
      'availability': availability,
      'game_type': gameType,
      'role': role,
      'region': region,
      if (country != null && country.isNotEmpty) 'country': country,
      if (xp != null) 'experience_points': xp,
      'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (phone != null) 'phone': phone,
      if (location != null) 'location': location,
      if (showEmail != null) 'show_email': showEmail,
      if (showPhone != null) 'show_phone': showPhone,
      if (showLocation != null) 'show_location': showLocation,
      if (socialInstagram != null) 'social_instagram': socialInstagram,
      if (socialFacebook != null) 'social_facebook': socialFacebook,
      if (socialGithub != null) 'social_github': socialGithub,
    });

    if (favoriteGames != null) {
      await saveFavoriteGames(favoriteGames);
    }
  }

  // ─── Favorite Games (profile_favorite_games junction table) ──────────────────
  Future<List<String>> getFavoriteGames() async {
    if (userId == null) return [];
    try {
      final rows = await _db
          .from('profile_favorite_games')
          .select('game')
          .eq('profile_id', userId!);
      return rows.map((r) => r['game'] as String).toList();
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
  }

  Future<void> saveFavoriteGames(List<String> games) async {
    if (userId == null) return;
    // Delete existing, then insert new
    await _db.from('profile_favorite_games').delete().eq('profile_id', userId!);
    if (games.isNotEmpty) {
      await _db.from('profile_favorite_games').insert(
        games.map((g) => {'profile_id': userId, 'game': g}).toList(),
      );
    }
  }

  /// Fetch another user's favorite games
  Future<List<String>> getOtherFavoriteGames(String targetUserId) async {
    try {
      final rows = await _db
          .from('profile_favorite_games')
          .select('game')
          .eq('profile_id', targetUserId);
      return rows.map((r) => r['game'] as String).toList();
    } catch (e) {
      developer.log('getOtherFavoriteGames error: $e');
      return [];
    }
  }

  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _db.storage.from('avatars').uploadBinary(fileName, bytes);
    final url = _db.storage.from('avatars').getPublicUrl(fileName);
    await _db.from('profiles').update({'avatar_url': url}).eq('id', userId!);
    return url;
  }

  Future<void> updateAvatarOnly(String avatarUrl) async {
    if (userId == null) return;
    await _db
        .from('profiles')
        .update({'avatar_url': avatarUrl}).eq('id', userId!);
  }

  /// Fetch another user's profile by id (for profile viewing)
  Future<Map<String, dynamic>?> getOtherProfile(String targetUserId) async {
    try {
      return await _db
          .from('profiles')
          .select()
          .eq('id', targetUserId)
          .maybeSingle();
    } catch (e) {
      developer.log('getOtherProfile error: $e');
      return null;
    }
  }

  /// Upload chat media to storage
  Future<String> uploadChatMedia(Uint8List bytes, String fileName) async {
    final path = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _db.storage.from('chat_media').uploadBinary(path, bytes);
    return _db.storage.from('chat_media').getPublicUrl(path);
  }

  /// Update team avatar (owner only — enforced client-side)
  Future<String?> updateTeamAvatar(String teamId, Uint8List bytes) async {
    if (userId == null) return null;
    try {
      final ext = 'png';
      final fileName =
          'team_${teamId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from('team_avatars').uploadBinary(fileName, bytes);
      final url = _db.storage.from('team_avatars').getPublicUrl(fileName);
      await _db.from('teams').update({'avatar_url': url}).eq('id', teamId);
      return url;
    } catch (e) {
      developer.log('updateTeamAvatar error: $e');
      return null;
    }
  }

  /// Update XP on the current user's profile (writes to both columns
  /// for backward compatibility with existing schema).
  Future<void> updateXp(int xp) async {
    if (userId == null) return;
    await _db.from('profiles').update({
      'experience_points': xp,
    }).eq('id', userId!);
  }

  // ─── Matching ────────────────────────────────────────────────────────────────
  /// Returns profiles with compatibility_score from match_events if available,
  /// otherwise falls back to raw profile query. Excludes friends.
  Future<List<Map<String, dynamic>>> findMatches({
    String? gameType,
    String? region,
    String? availability,
  }) async {
    if (userId == null) return [];
    _requireEnabled();

    try {
      final friendIds = await _getFriendIds();

      // Get past match events for this user to attach real compatibility scores
      final events = await _db
          .from('match_events')
          .select('matched_user_id, compatibility_score')
          .eq('user_id', userId!)
          .order('compatibility_score', ascending: false)
          .limit(50);

      final scoreMap = <String, double>{};
      for (final e in events) {
        scoreMap[e['matched_user_id'] as String] =
            (e['compatibility_score'] as num).toDouble();
      }

      // Query profiles with filters
      var query = _db.from('profiles').select().neq('id', userId!);
      if (friendIds.isNotEmpty) {
        query = query.not('id', 'in', '(${friendIds.join(",")})');
      }
      if (gameType != null && gameType.isNotEmpty) {
        query = query.eq('game_type', gameType);
      }
      if (region != null && region.isNotEmpty) {
        query = query.eq('region', region);
      }
      if (availability != null && availability.isNotEmpty) {
        query = query.eq('availability', availability);
      }

      final profiles = List<Map<String, dynamic>>.from(await query.limit(30));

      // Attach compatibility score: use match_events score if available, else compute heuristic
      return profiles.map((p) {
        final pid = p['id'] as String;
        final score = scoreMap[pid] ?? _heuristicScore(p);
        return {'profile': p, 'compatibilityScore': score};
      }).toList()
        ..sort((a, b) => (b['compatibilityScore'] as double)
            .compareTo(a['compatibilityScore'] as double));
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
  }

  double _heuristicScore(Map<String, dynamic> profile) {
    final xp = (profile['experience_points'] as int? ?? profile['xp'] as int? ?? 0);
    return ((xp / 2000).clamp(0.0, 1.0) * 70 + 25).roundToDouble();
  }

  // ─── Games ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGames() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _db.from('games').select().order('name'));
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
  }

  // ─── Teams (public.teams + public.team_members) ───────────────────────────────
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
    // Create a squad for team chat
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
    await createChannel(squadRes['id'] as String, 'général');
    // Create the team with a reference to the squad
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
      // squad_id column may not exist on teams table
      res = await _db
          .from('teams')
          .insert({
            'name': name,
            'owner_id': userId,
            'status': 'active',
          })
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

  /// Get the squad ID associated with a team.
  /// Auto-creates squad+channel if missing.
  Future<String?> getTeamSquadId(String teamId) async {
    try {
      final team =
          await _db.from('teams').select('squad_id').eq('id', teamId).maybeSingle();
      final sid = team?['squad_id'] as String?;
      if (sid != null && sid.isNotEmpty) return sid;
    } catch (_) {}
    // Fallback: find squad by matching name and owner
    try {
      final team =
          await _db.from('teams').select('name, owner_id').eq('id', teamId).maybeSingle();
      if (team == null) return null;
      final squad = await _db
          .from('squads')
          .select('id')
          .eq('name', team['name'] as String)
          .eq('owner_id', team['owner_id'] as String)
          .maybeSingle();
      if (squad != null) {
        final sid = squad['id'] as String;
        // Link it back to the team
        try {
          await _db.from('teams').update({'squad_id': sid}).eq('id', teamId);
        } catch (_) {}
        return sid;
      }
    } catch (_) {}
    return null;
  }

  /// Get the first channel ID for a team's squad.
  /// Auto-creates squad+channel for the team if missing.
  Future<String?> getTeamChannelId(String teamId) async {
    var squadId = await getTeamSquadId(teamId);
    if (squadId == null) {
      // No squad exists — create one for this team
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
        // Add all active team members to the squad
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
    // Find or create the first channel
    try {
      final channels =
          await _db.from('channels').select('id').eq('squad_id', squadId).limit(1);
      if (channels.isNotEmpty) return channels.first['id'] as String;
    } catch (_) {}
    // No channel yet — create one
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

  /// Send a team invitation (stored in invitations with team_id).
  /// Throws if a pending invitation already exists.
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
      // Fallback if team_id column doesn't exist
      developer.log('inviteToTeam (team_id fallback): $e');
      await _db.from('invitations').insert({
        'sender_id': userId,
        'receiver_id': receiverProfileId,
        'status': 'pending',
      });
    }
  }

  /// Add an existing friend directly to the team (bypass invitation for friend list)
  Future<void> addMemberToTeam(String teamId, String friendId) async {
    if (userId == null) return;
    await _db.from('team_members').insert({
      'team_id': teamId,
      'user_id': friendId,
      'role': 'member',
    });
    // Also add to the team's squad for chat access
    final squadId = await getTeamSquadId(teamId);
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

  /// Leave a team
  Future<void> leaveTeam(String teamId) async {
    if (userId == null) return;
    await _db
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId!);
    // Remove from squad too
    final squadId = await getTeamSquadId(teamId);
    if (squadId != null) {
      await _db
          .from('squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', userId!);
    }
  }

  /// Kick a member from a team (owner only)
  Future<void> kickMember(String teamId, String targetUserId) async {
    await _db
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', targetUserId);
    // Remove from squad too
    final squadId = await getTeamSquadId(teamId);
    if (squadId != null) {
      await _db
          .from('squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', targetUserId);
    }
  }

  /// Approve pending team membership: activate status and add to squad
  Future<void> approveTeamMembership(String teamId) async {
    if (userId == null) return;
    await _db
        .from('team_members')
        .update({'status': 'active'})
        .eq('team_id', teamId)
        .eq('user_id', userId!);
    final squadId = await getTeamSquadId(teamId);
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

  /// Decline / leave a pending team membership (removes from team_members)
  Future<void> declineTeamMembership(String teamId) async {
    if (userId == null) return;
    await _db
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId!);
  }

  /// Check if current user has pending status in this team
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

  /// Get friends that are NOT already in this team
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

  /// Get a single team's data
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
      final profiles = await _db.from('profiles').select('id, pseudo, avatar_url');
      final profileMap = {for (final p in profiles) p['id'] as String: p};
      for (final r in rows) {
        r['profiles'] = profileMap[r['user_id'] as String] ?? {};
      }
      return rows;
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
  }

  // ─── Squads (public.squads + public.squad_members) ────────────────────────────
  Future<void> createSquad(String name) async {
    if (userId == null) return;
    final res = await _db
        .from('squads')
        .insert({
          'name': name,
          'owner_id': userId,
        })
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

  /// Get members of a squad with their profiles
  Future<List<Map<String, dynamic>>> getSquadMembers(String squadId) async {
    try {
      // Get member user IDs first
      final members = List<Map<String, dynamic>>.from(
        await _db.from('squad_members').select('user_id, role').eq('squad_id', squadId),
      );
      final ids = members.map((m) => m['user_id'] as String).toList();
      if (ids.isEmpty) return members;
      if (ids.isNotEmpty) {
        final profiles = await _db.from('profiles').select('id, pseudo, avatar_url').filter('id', 'in', '(${ids.join(",")})');
        final profileMap = {for (final p in profiles) p['id'] as String: p};
        for (final m in members) {
          m['profiles'] = profileMap[m['user_id'] as String] ?? {};
        }
      }
      return members;
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
  }

  /// Get channel messages (not streaming, one-shot)
  Future<List<Map<String, dynamic>>> getChannelMessages(String channelId) async {
    try {
      final msgs = List<Map<String, dynamic>>.from(
        await _db
            .from('messages')
            .select()
            .eq('channel_id', channelId)
            .order('created_at', ascending: true)
            .limit(100),
      );
      // Attach sender profiles
      final senderIds = msgs.map((m) => m['sender_id'] as String).toSet().toList();
      if (senderIds.isNotEmpty) {
        final profiles = await _db.from('profiles').select('id, pseudo, avatar_url, experience_points').filter('id', 'in', '(${senderIds.join(",")})');
        final profileMap = {for (final p in profiles) p['id'] as String: p};
        for (final msg in msgs) {
          msg['sender'] = profileMap[msg['sender_id'] as String] ?? {};
        }
      }
      return msgs;
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
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

  // ─── Messages (public.messages — supports both DM and channel) ───────────────
  /// Send a direct message (receiver_id set, channel_id null)
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

  /// Send a channel message (channel_id set, receiver_id null)
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

  /// Insert a system message for call events (started, ended, refused, missed, ringing)
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

  /// Delete a message by id
  Future<void> deleteMessage(String messageId) async {
    if (userId == null) return;
    try {
      await _db.from('messages').delete().eq('id', messageId);
    } catch (e) {
      developer.log('deleteMessage error: $e');
    }
  }

  /// Fetch DM history between current user and peer
  Future<List<Map<String, dynamic>>> getMessages(String peerId, {int retry = 0}) async {
    if (userId == null) return [];
    try {
      final sent = await _db
          .from('messages')
          .select()
          .eq('sender_id', userId!)
          .eq('receiver_id', peerId)
          .order('created_at', ascending: true);
      final received = await _db
          .from('messages')
          .select()
          .eq('sender_id', peerId)
          .eq('receiver_id', userId!)
          .order('created_at', ascending: true);
      final merged = [...sent, ...received];
      merged.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
      developer.log('getMessages: sent=${sent.length} received=${received.length} merged=${merged.length} userId=$userId peer=$peerId');
      return merged.reversed.take(100).toList().reversed.toList();
    } catch (e) {
      developer.log('getMessages error: $e');
      if (retry < 3) {
        await Future.delayed(const Duration(seconds: 1));
        return getMessages(peerId, retry: retry + 1);
      }
      return [];
    }
  }

  /// Mark all messages from [peerId] as seen
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

  /// Mark all channel messages as delivered except own
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

  /// Return unread count per peer (sender_id → count)
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

  /// Return unread message count per team (team_id → count)
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
          final channelId = await getTeamChannelId(teamId);
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

  /// Stream channel messages in real-time
  Stream<List<Map<String, dynamic>>> streamMessages(String channelId) {
    final raw = _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .order('created_at', ascending: true);
    // Attach sender profiles to each batch
    return raw.asyncMap((msgs) async {
      if (msgs.isEmpty) return msgs;
      final senderIds =
          msgs.map((m) => m['sender_id'] as String).toSet().toList();
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

  /// Subscribe to new DMs via Realtime
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

  // ─── Calls (public.calls — WebRTC signaling) ───────────────────────────────────
  /// Create a new call record
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

  /// Update call status
  Future<void> updateCallStatus(String callId, String status) async {
    try {
      await _db.from('calls').update({'status': status}).eq('id', callId);
    } catch (e) {
      developer.log('updateCallStatus error: $e');
    }
  }

  /// Subscribe to incoming calls
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

  /// Fetch a single call record by ID
  Future<Map<String, dynamic>?> getCall(String callId) async {
    try {
      return await _db.from('calls').select().eq('id', callId).maybeSingle();
    } catch (e) {
      developer.log('getCall error: $e');
      return null;
    }
  }

  /// Update SDP for a call (offer or answer)
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

  /// Add an ICE candidate for a call
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

  /// Fetch existing ICE candidates for a call (used to replay candidates that
  /// were generated before the remote peer subscribed).
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

  /// Subscribe to ICE candidates for a call (exclude own)
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

  /// Subscribe to SDP changes on a call (update events)
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
            if (newRecord['offer_sdp'] != null ||
                newRecord['answer_sdp'] != null) {
              onChange(newRecord);
            }
          },
        )
        .subscribe();
    return channel;
  }

  /// Subscribe to call status changes (e.g. when other party ends call)
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

  // ─── Team Calls (public.team_calls + public.team_call_participants) ────────────
  /// Create a team call and add all team members as participants.
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
      final members = await getTeamMembers(teamId);
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

  /// Fetch a single team call
  Future<Map<String, dynamic>?> getTeamCall(String callId) async {
    try {
      return await _db.from('team_calls').select().eq('id', callId).maybeSingle();
    } catch (e) {
      developer.log('getTeamCall error: $e');
      return null;
    }
  }

  /// Fetch participants of a team call
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

  /// Stream team call participants in real-time
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

  /// Join a team call (update participant status)
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

  /// Decline a team call
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

  /// End/leave a team call
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

  /// Leave as participant
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

  /// Update SDP for a team call participant (caller writes offer, participant writes answer)
  Future<void> updateTeamCallParticipantSdp(String participantId, String sdpJson, String type) async {
    try {
      final update = type == 'offer' ? {'offer_sdp': sdpJson} : {'answer_sdp': sdpJson};
      await _db.from('team_call_participants').update(update).eq('id', participantId);
    } catch (e) {
      developer.log('updateTeamCallParticipantSdp error: $e');
    }
  }

  /// Subscribe to team call participant changes (e.g. someone joined/left)
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

  /// Subscribe to SDP updates for a specific participant
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

  /// Subscribe to team call status changes (ended etc.)
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

  /// Subscribe to incoming team calls for a user
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
            // Fetch the team call details and pass them
            getTeamCall(payload.newRecord['call_id'] as String).then((call) {
              if (call != null) onCall(call);
            });
          }
        },
      )
      .subscribe();
    return channel;
  }

  /// Add ICE candidate for a team call participant pair
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

  /// Fetch existing ICE candidates for a team call participant pair
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

  /// Subscribe to ICE candidates for a team call participant pair
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

  /// Get a participant record for a user in a team call (for participant lookup)
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

  // ─── Squad Calls ─────────────────────────────────────────────────────────────

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
      final members = await getSquadMembers(squadId);
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

  // ─── Invitations (public.invitations) ────────────────────────────────────────
  /// Send a player-to-player invitation (no squad required).
  /// Throws if a pending invitation already exists.
  Future<void> sendInvitation(String receiverProfileId) async {
    if (userId == null) return;
    // Check for existing pending invitation to avoid unique constraint violation
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

  /// Get pending invitations received by current user
  Future<List<Map<String, dynamic>>> getInvitations() async {
    if (userId == null) return [];
    final response = await _db
        .from('invitations')
        .select(
            '*, sender:profiles!invitations_sender_id_fkey(id, pseudo, avatar_url)')
        .eq('receiver_id', userId!)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get IDs of all players the current user has sent pending invitations to
  Future<Set<String>> getSentInvitationIds() async {
    if (userId == null) return {};
    final response = await _db
        .from('invitations')
        .select('receiver_id')
        .eq('sender_id', userId!)
        .eq('status', 'pending');
    return response.map((r) => r['receiver_id'] as String).toSet();
  }

  /// Accept or reject an invitation; on accept, create a session + squad + add friend
  Future<void> respondInvitation(String invitationId, bool accept) async {
    String? senderId;
    String? teamId;
    try {
      final inv = await _db.from('invitations').select('sender_id, team_id').eq('id', invitationId).maybeSingle();
      senderId = inv?['sender_id'] as String?;
      teamId = inv?['team_id'] as String?;
    } catch (_) {
      // team_id column may not exist yet — treat as regular invitation
      final inv = await _db.from('invitations').select('sender_id').eq('id', invitationId).maybeSingle();
      senderId = inv?['sender_id'] as String?;
    }

    await _db.from('invitations').update({
      'status': accept ? 'accepted' : 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', invitationId);

    if (accept && userId != null) {
      if (teamId != null) {
        // Team invitation — add to team_members as pending (not in squad yet)
        await _db.from('team_members').insert({
          'team_id': teamId,
          'user_id': userId!,
          'role': 'member',
          'status': 'pending',
        });
      } else if (senderId != null) {
        // Regular player invitation
        await _db.from('sessions').insert({
          'invitation_id': invitationId,
          'status': 'active',
        });
        await _addFriend(userId!, senderId);
        await _createSharedSquad(userId!, senderId);
      }
    }
  }

  Future<void> _addFriend(String uid1, String uid2) async {
    await _db.from('friends').upsert({'user_id': uid1, 'friend_id': uid2});
    await _db.from('friends').upsert({'user_id': uid2, 'friend_id': uid1});
  }

  Future<void> _createSharedSquad(String uid1, String uid2) async {
    // Get pseudos for squad name
    final p1 = await _db.from('profiles').select('pseudo').eq('id', uid1).maybeSingle();
    final p2 = await _db.from('profiles').select('pseudo').eq('id', uid2).maybeSingle();
    final name = '${p1?['pseudo'] ?? 'Player'} & ${p2?['pseudo'] ?? 'Player'}';
    // Check if they already share a squad
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
      if (shared != null) return; // already share a squad
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

  /// Subscribe to invitation changes for the current user (insert + update).
  /// Returns a [RealtimeChannel] that fires [onChange] with each new/updated record.
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

  /// Get pending invitations count
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
      developer.log('SupabaseBackendService error: $e');
      return 0;
    }
  }

  /// Get friend IDs only (no profile data)
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

  /// Get friends list (profiles of friends)
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
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
  }

  // Keep old name as alias
  Future<void> respondToInvitation(String invitationId, bool accept) =>
      respondInvitation(invitationId, accept);

  Future<List<Map<String, dynamic>>> getMyInvitations() => getInvitations();

  // ─── Search ───────────────────────────────────────────────────────────────────
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

  // ─── Reputation (public.reputation_reviews) ───────────────────────────────────
  Future<Map<String, dynamic>?> getUserReputation(String targetUserId) async {
    try {
      final response = await _db
          .from('reputation_reviews')
          .select('skill_score, communication_score, toxicity_score')
          .eq('reviewed_id', targetUserId);
      if (response.isEmpty) return null;
      final reviews = List<Map<String, dynamic>>.from(response);

      double avg(String key) {
        final vals =
            reviews.map((r) => (r[key] as num?)?.toDouble() ?? 0.0).toList();
        return vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
      }

      final skillAvg = avg('skill_score');
      final commAvg = avg('communication_score');
      // toxicity_score: lower is better (1=toxic, 5=respectful)
      final respectAvg = avg('toxicity_score');
      final overall = (skillAvg + commAvg + respectAvg) / 3;

      return {
        'avg_score': overall,
        'skill': skillAvg,
        'communication': commAvg,
        'respect': respectAvg,
        'teamwork': (skillAvg + commAvg) / 2, // derived
        'total_reviews': reviews.length,
      };
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return null;
    }
  }

  Future<void> submitReview({
    required String reviewedId,
    required int skillScore,
    required int communicationScore,
    required int toxicityScore,
    String? comment,
  }) async {
    if (userId == null) return;
    await _db.from('reputation_reviews').insert({
      'reviewer_id': userId,
      'reviewed_id': reviewedId,
      'skill_score': skillScore,
      'communication_score': communicationScore,
      'toxicity_score': toxicityScore,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  // ─── Notifications (public.notifications) ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getNotifications() async {
    if (userId == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        await _db
            .from('notifications')
            .select()
            .eq('user_id', userId!)
            .order('created_at', ascending: false)
            .limit(30),
      );
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return [];
    }
  }

  Future<void> markNotificationRead(dynamic id) async {
    try {
      await _db.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
    }
  }

  // ─── Subscriptions ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getSubscription() async {
    if (userId == null) return null;
    try {
      return await _db
          .from('subscriptions')
          .select()
          .eq('user_id', userId!)
          .eq('status', 'active')
          .maybeSingle();
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
      return null;
    }
  }

  // ─── Dashboard ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final profile = await getProfile();
    final List<Map<String, dynamic>> recentActivity = [];

    try {
      final invites = await getInvitations();
      for (final inv in invites.take(3)) {
        final sender = inv['sender'] as Map?;
        recentActivity.add({
          'type': 'invite',
          'title': 'Invitation reçue',
          'subtitle': '${sender?['pseudo'] ?? 'Joueur'} vous a invité à jouer',
        });
      }
    } catch (e) {
      developer.log('SupabaseBackendService error: $e');
    }

    return {
      'profile': profile,
      'recent_activity': recentActivity,
    };
  }
}
