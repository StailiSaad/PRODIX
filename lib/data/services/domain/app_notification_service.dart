import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotificationService {
  AppNotificationService({required this.supabaseUrl});

  final String supabaseUrl;

  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

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
      developer.log('AppNotificationService error: $e');
      return [];
    }
  }

  Future<void> markNotificationRead(dynamic id) async {
    try {
      await _db.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      developer.log('AppNotificationService error: $e');
    }
  }

  Future<int> getUnreadNotificationCount() async {
    if (userId == null) return 0;
    try {
      final res = await _db
          .from('notifications')
          .select('id')
          .eq('user_id', userId!)
          .eq('is_read', false);
      return res.length;
    } catch (e) {
      developer.log('getUnreadNotificationCount error: $e');
      return 0;
    }
  }

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
      developer.log('getSubscription error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getGames() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _db.from('games').select().order('name'));
    } catch (e) {
      developer.log('getGames error: $e');
      return [];
    }
  }
}
