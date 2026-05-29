import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchingService {
  MatchingService({required this.supabaseUrl});

  final String supabaseUrl;

  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> findMatches({
    String? gameType,
    String? region,
    String? availability,
  }) async {
    if (userId == null) return [];
    try {
      final friendIds = await _getFriendIds();
      final events = await _db
          .from('match_events')
          .select('matched_user_id, compatibility_score')
          .eq('user_id', userId!)
          .order('compatibility_score', ascending: false)
          .limit(50);
      final scoreMap = <String, double>{};
      for (final e in events) {
        scoreMap[e['matched_user_id'] as String] = (e['compatibility_score'] as num).toDouble();
      }
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
      return profiles.map((p) {
        final pid = p['id'] as String;
        final score = scoreMap[pid] ?? _heuristicScore(p);
        return {'profile': p, 'compatibilityScore': score};
      }).toList()
        ..sort((a, b) => (b['compatibilityScore'] as double)
            .compareTo(a['compatibilityScore'] as double));
    } catch (e) {
      developer.log('MatchingService error: $e');
      return [];
    }
  }

  double _heuristicScore(Map<String, dynamic> profile) {
    final xp = (profile['experience_points'] as int? ?? profile['xp'] as int? ?? 0);
    return ((xp / 2000).clamp(0.0, 1.0) * 70 + 25).roundToDouble();
  }

  Future<Map<String, dynamic>?> getUserReputation(String targetUserId) async {
    try {
      final response = await _db
          .from('reputation_reviews')
          .select('skill_score, communication_score, toxicity_score')
          .eq('reviewed_id', targetUserId);
      if (response.isEmpty) return null;
      final reviews = List<Map<String, dynamic>>.from(response);
      double avg(String key) {
        final vals = reviews.map((r) => (r[key] as num?)?.toDouble() ?? 0.0).toList();
        return vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
      }
      final skillAvg = avg('skill_score');
      final commAvg = avg('communication_score');
      final respectAvg = avg('toxicity_score');
      final overall = (skillAvg + commAvg + respectAvg) / 3;
      return {
        'avg_score': overall,
        'skill': skillAvg,
        'communication': commAvg,
        'respect': respectAvg,
        'teamwork': (skillAvg + commAvg) / 2,
        'total_reviews': reviews.length,
      };
    } catch (e) {
      developer.log('MatchingService error: $e');
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

  Future<List<String>> _getFriendIds() async {
    if (userId == null) return [];
    try {
      final rows = await _db.from('friends').select('friend_id').eq('user_id', userId!);
      return rows.map((r) => r['friend_id'] as String).toList();
    } catch (e) {
      developer.log('_getFriendIds error: $e');
      return [];
    }
  }
}
