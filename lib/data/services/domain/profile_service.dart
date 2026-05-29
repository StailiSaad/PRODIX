import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/profile_defaults.dart';

class ProfileService {
  ProfileService({required this.supabaseUrl});

  final String supabaseUrl;

  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

  Future<Map<String, dynamic>?> getProfile() async {
    if (userId == null) return null;
    try {
      return await _db
          .from('profiles')
          .select()
          .eq('id', userId!)
          .maybeSingle();
    } catch (e) {
      developer.log('ProfileService error: $e');
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

  Future<void> updateXp(int xp) async {
    if (userId == null) return;
    await _db.from('profiles').update({
      'experience_points': xp,
    }).eq('id', userId!);
  }

  Future<List<String>> getFavoriteGames() async {
    if (userId == null) return [];
    try {
      final rows = await _db
          .from('profile_favorite_games')
          .select('game')
          .eq('profile_id', userId!);
      return rows.map((r) => r['game'] as String).toList();
    } catch (e) {
      developer.log('ProfileService error: $e');
      return [];
    }
  }

  Future<void> saveFavoriteGames(List<String> games) async {
    if (userId == null) return;
    await _db.from('profile_favorite_games').delete().eq('profile_id', userId!);
    if (games.isNotEmpty) {
      await _db.from('profile_favorite_games').insert(
        games.map((g) => {'profile_id': userId, 'game': g}).toList(),
      );
    }
  }

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
}
