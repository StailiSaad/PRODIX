import 'package:flutter/foundation.dart';
import 'package:quest_gamification/quest_gamification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository(this._userId);

  final String _userId;
  UserProgress? _cached;

  @override
  Future<UserProgress?> load() async {
    if (_cached != null) return _cached;
    try {
      final response = await Supabase.instance.client
          .from('user_progress')
          .select('data')
          .eq('user_id', _userId)
          .maybeSingle();
      if (response == null) return null;
      final data = response['data'] as Map<String, dynamic>?;
      if (data == null || data.isEmpty) return null;
      _cached = UserProgress.fromMap(data);
      return _cached;
    } catch (e) {
      debugPrint('SupabaseProgressRepository.load error: $e');
      return _cached;
    }
  }

  @override
  Future<void> save(UserProgress progress) async {
    _cached = progress;
    try {
      await Supabase.instance.client.from('user_progress').upsert({
        'user_id': _userId,
        'data': progress.toMap(),
      });
    } catch (e) {
      debugPrint('SupabaseProgressRepository.save error: $e');
    }
  }

  @override
  Stream<UserProgress?> watch() {
    try {
      return Supabase.instance.client
          .from('user_progress')
          .stream(primaryKey: ['user_id'])
          .eq('user_id', _userId)
          .map((rows) {
        if (rows.isEmpty) return null;
        final data = rows.first['data'] as Map<String, dynamic>?;
        if (data == null) return null;
        return UserProgress.fromMap(data);
      });
    } catch (e) {
      debugPrint('SupabaseProgressRepository.watch error: $e');
      return const Stream.empty();
    }
  }
}
