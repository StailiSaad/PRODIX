import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/profile_defaults.dart';
import 'domain/profile_service.dart';
import 'domain/chat_service.dart';
import 'domain/social_service.dart';
import 'domain/call_service.dart';
import 'domain/post_service.dart';
import 'domain/matching_service.dart';
import 'domain/app_notification_service.dart';

/// Facade that delegates to domain-specific services.
/// Existing code imports this class by name so it remains compatible.
class SupabaseBackendService {
  SupabaseBackendService({
    required this.isEnabled,
    required this.baseUrl,
    required this.supabaseUrl,
  })  : profile = ProfileService(supabaseUrl: supabaseUrl),
        chat = ChatService(supabaseUrl: supabaseUrl),
        social = SocialService(supabaseUrl: supabaseUrl),
        call = CallService(supabaseUrl: supabaseUrl),
        post = PostService(supabaseUrl: supabaseUrl),
        matching = MatchingService(supabaseUrl: supabaseUrl),
        appNotification = AppNotificationService(supabaseUrl: supabaseUrl);

  final bool isEnabled;
  final String baseUrl;
  final String supabaseUrl;

  // Domain services
  final ProfileService profile;
  final ChatService chat;
  final SocialService social;
  final CallService call;
  final PostService post;
  final MatchingService matching;
  final AppNotificationService appNotification;

  SupabaseClient get _db => Supabase.instance.client;

  void _requireEnabled() {
    if (!isEnabled) throw Exception('Supabase backend is not enabled. Check your configuration.');
  }

  String? get userId => _db.auth.currentUser?.id;
  User? get currentUser => _db.auth.currentUser;
  Session? get currentSession => _db.auth.currentSession;

  // ─── Auth ────────────────────────────────────────────────────────
  Future<void> signUp(String email, String password, String pseudo) async {
    _requireEnabled();
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'pseudo': pseudo},
    );
    if (res.user == null) throw Exception('Inscription échouée.');
    await _db.from('users').insert({
      'id': res.user!.id,
      'email': email,
      'password_hash': 'managed_by_supabase_auth',
    });
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

  // ─── Profile ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getProfile() => profile.getProfile();
  Future<void> updateProfile({
    required String pseudo, int? xp, required String language,
    required String availability, required String gameType,
    required String role, required String region, required String bio,
    String? avatarUrl, String? birthDate, List<String>? favoriteGames,
    String? phone, String? location, bool? showEmail, bool? showPhone,
    bool? showLocation, String? socialInstagram, String? socialFacebook,
    String? socialGithub, String? country,
  }) => profile.updateProfile(
    pseudo: pseudo, xp: xp, language: language, availability: availability,
    gameType: gameType, role: role, region: region, bio: bio,
    avatarUrl: avatarUrl, birthDate: birthDate, favoriteGames: favoriteGames,
    phone: phone, location: location, showEmail: showEmail, showPhone: showPhone,
    showLocation: showLocation, socialInstagram: socialInstagram,
    socialFacebook: socialFacebook, socialGithub: socialGithub, country: country,
  );
  Future<Map<String, dynamic>?> getOtherProfile(String targetUserId) => profile.getOtherProfile(targetUserId);
  Future<String> uploadAvatar(Uint8List bytes, String extension) => profile.uploadAvatar(bytes, extension);
  Future<void> updateAvatarOnly(String avatarUrl) => profile.updateAvatarOnly(avatarUrl);
  Future<void> updateXp(int xp) => profile.updateXp(xp);
  Future<List<String>> getFavoriteGames() => profile.getFavoriteGames();
  Future<void> saveFavoriteGames(List<String> games) => profile.saveFavoriteGames(games);
  Future<List<String>> getOtherFavoriteGames(String targetUserId) => profile.getOtherFavoriteGames(targetUserId);

  // ─── Messages / Chat ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getChannelMessages(String channelId, {int retry = 0, int limit = 100, int offset = 0}) => chat.getChannelMessages(channelId, retry: retry, limit: limit, offset: offset);
  Future<bool> sendDirectMessage(String receiverId, String content, {String? mediaUrl, String? mediaType, String? mediaName, int? duration}) => chat.sendDirectMessage(receiverId, content, mediaUrl: mediaUrl, mediaType: mediaType, mediaName: mediaName, duration: duration);
  Future<bool> sendMessage(String channelId, String content, {String? mediaUrl, String? mediaType, String? mediaName, int? duration}) => chat.sendMessage(channelId, content, mediaUrl: mediaUrl, mediaType: mediaType, mediaName: mediaName, duration: duration);
  Future<bool> sendCallEventMessage(String channelId, String callEventType, {String? callerName}) => chat.sendCallEventMessage(channelId, callEventType, callerName: callerName);
  Future<void> deleteMessage(String messageId) => chat.deleteMessage(messageId);
  Future<List<Map<String, dynamic>>> getMessages(String peerId, {int retry = 0, int limit = 100, int offset = 0}) => chat.getMessages(peerId, retry: retry, limit: limit, offset: offset);
  Future<void> markMessagesAsSeen(String peerId) => chat.markMessagesAsSeen(peerId);
  Future<void> markChannelMessagesAsDelivered(String channelId) => chat.markChannelMessagesAsDelivered(channelId);
  Future<Map<String, int>> getUnreadCounts() => chat.getUnreadCounts();
  Future<Map<String, int>> getTeamUnreadCounts() => chat.getTeamUnreadCounts();
  Stream<List<Map<String, dynamic>>> streamMessages(String channelId) => chat.streamMessages(channelId);
  RealtimeChannel subscribeToMessages(String channelName, void Function(Map<String, dynamic>) onMessage) => chat.subscribeToMessages(channelName, onMessage);

  // ─── Teams, Squads, Social ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyTeams() => social.getMyTeams();
  Future<Map<String, dynamic>> createTeam(String name) => social.createTeam(name);
  Future<String?> getTeamChannelId(String teamId) => social.getTeamChannelId(teamId);
  Future<String?> getSquadChannelId(String squadId) => social.getSquadChannelId(squadId);
  Future<String?> updateTeamAvatar(String teamId, Uint8List bytes) => social.updateTeamAvatar(teamId, bytes);
  Future<void> inviteToTeam(String teamId, String receiverProfileId) => social.inviteToTeam(teamId, receiverProfileId);
  Future<void> addMemberToTeam(String teamId, String friendId) => social.addMemberToTeam(teamId, friendId);
  Future<void> leaveTeam(String teamId) => social.leaveTeam(teamId);
  Future<void> kickMember(String teamId, String targetUserId) => social.kickMember(teamId, targetUserId);
  Future<void> approveTeamMembership(String teamId) => social.approveTeamMembership(teamId);
  Future<void> declineTeamMembership(String teamId) => social.declineTeamMembership(teamId);
  Future<bool> isPendingTeamMember(String teamId) => social.isPendingTeamMember(teamId);
  Future<List<Map<String, dynamic>>> getTeamInvitableFriends(String teamId) => social.getTeamInvitableFriends(teamId);
  Future<Map<String, dynamic>?> getTeamData(String teamId) => social.getTeamData(teamId);
  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) => social.getTeamMembers(teamId);
  Future<void> createSquad(String name) => social.createSquad(name);
  Future<List<Map<String, dynamic>>> getSquads() => social.getSquads();
  Future<List<Map<String, dynamic>>> getSquadMembers(String squadId) => social.getSquadMembers(squadId);
  Future<void> createChannel(String squadId, String name) => social.createChannel(squadId, name);
  Future<List<Map<String, dynamic>>> getChannels(String squadId) => social.getChannels(squadId);
  Future<void> sendInvitation(String receiverProfileId) => social.sendInvitation(receiverProfileId);
  Future<List<Map<String, dynamic>>> getInvitations() => social.getInvitations();
  Future<Set<String>> getSentInvitationIds() => social.getSentInvitationIds();
  Future<void> respondInvitation(String invitationId, bool accept) => social.respondInvitation(invitationId, accept);
  Future<void> respondToInvitation(String invitationId, bool accept) => social.respondToInvitation(invitationId, accept);
  Future<List<Map<String, dynamic>>> getMyInvitations() => social.getMyInvitations();
  Future<int> getPendingInvitationsCount() => social.getPendingInvitationsCount();
  RealtimeChannel subscribeToInvitations(String userId, void Function(Map<String, dynamic>) onChange) => social.subscribeToInvitations(userId, onChange);
  Future<List<Map<String, dynamic>>> getFriends() => social.getFriends();
  Future<List<Map<String, dynamic>>> searchPlayers(String query) => social.searchPlayers(query);
  Future<List<String>> _getFriendIds() => social.searchPlayers('').then((_) => <String>[]); // unused, kept for compat

  // ─── Calls (P2P + Team + Squad) ──────────────────────────────────
  Future<String?> initiateCall(String calleeId, {String callType = 'audio'}) => call.initiateCall(calleeId, callType: callType);
  Future<void> updateCallStatus(String callId, String status) => call.updateCallStatus(callId, status);
  Future<Map<String, dynamic>?> getCall(String callId) => call.getCall(callId);
  Future<void> updateCallSdp(String callId, String sdpJson, String type) => call.updateCallSdp(callId, sdpJson, type);
  Future<void> addIceCandidate(String callId, String candidate, String? sdpMid, int? sdpMLineIndex) => call.addIceCandidate(callId, candidate, sdpMid, sdpMLineIndex);
  Future<List<Map<String, dynamic>>> getIceCandidates(String callId) => call.getIceCandidates(callId);
  Future<void> cleanStaleCalls() => call.cleanStaleCalls();
  RealtimeChannel subscribeToCalls(String userId, void Function(Map<String, dynamic>) onCall) => call.subscribeToCalls(userId, onCall);
  RealtimeChannel subscribeToIceCandidates(String callId, void Function(Map<String, dynamic>) onCandidate) => call.subscribeToIceCandidates(callId, onCandidate);
  RealtimeChannel subscribeToCallSdp(String callId, void Function(Map<String, dynamic>) onChange) => call.subscribeToCallSdp(callId, onChange);
  RealtimeChannel subscribeToCallStatus(String callId, void Function(Map<String, dynamic>) onChange) => call.subscribeToCallStatus(callId, onChange);
  Future<String?> initiateTeamCall(String teamId, {String callType = 'audio'}) => call.initiateTeamCall(teamId, callType: callType);
  Future<Map<String, dynamic>?> getTeamCall(String callId) => call.getTeamCall(callId);
  Future<List<Map<String, dynamic>>> getTeamCallParticipants(String callId) => call.getTeamCallParticipants(callId);
  Stream<List<Map<String, dynamic>>> streamTeamCallParticipants(String callId) => call.streamTeamCallParticipants(callId);
  Future<void> joinTeamCall(String callId) => call.joinTeamCall(callId);
  Future<void> declineTeamCall(String callId) => call.declineTeamCall(callId);
  Future<void> endTeamCall(String callId) => call.endTeamCall(callId);
  Future<void> leaveTeamCall(String callId) => call.leaveTeamCall(callId);
  Future<void> updateTeamCallParticipantSdp(String participantId, String sdpJson, String type) => call.updateTeamCallParticipantSdp(participantId, sdpJson, type);
  Future<Map<String, dynamic>?> getTeamCallParticipant(String callId, String userId) => call.getTeamCallParticipant(callId, userId);
  Future<void> addTeamCallIceCandidate(String participantId, String candidate, String? sdpMid, int? sdpMLineIndex) => call.addTeamCallIceCandidate(participantId, candidate, sdpMid, sdpMLineIndex);
  Future<List<Map<String, dynamic>>> getTeamCallIceCandidates(String participantId) => call.getTeamCallIceCandidates(participantId);
  RealtimeChannel subscribeToTeamCallParticipants(String callId, void Function(Map<String, dynamic>) onChange) => call.subscribeToTeamCallParticipants(callId, onChange);
  RealtimeChannel subscribeToTeamCallSdp(String participantId, void Function(Map<String, dynamic>) onChange) => call.subscribeToTeamCallSdp(participantId, onChange);
  RealtimeChannel subscribeToTeamCallStatus(String callId, void Function(Map<String, dynamic>) onChange) => call.subscribeToTeamCallStatus(callId, onChange);
  RealtimeChannel subscribeToIncomingTeamCalls(String userId, void Function(Map<String, dynamic>) onCall) => call.subscribeToIncomingTeamCalls(userId, onCall);
  RealtimeChannel subscribeToTeamCallIceCandidates(String participantId, String userId, void Function(Map<String, dynamic>) onCandidate) => call.subscribeToTeamCallIceCandidates(participantId, userId, onCandidate);
  Future<String?> initiateSquadCall(String squadId, {String callType = 'audio'}) => call.initiateSquadCall(squadId, callType: callType);
  Future<Map<String, dynamic>?> getSquadCall(String callId) => call.getSquadCall(callId);
  Future<List<Map<String, dynamic>>> getSquadCallParticipants(String callId) => call.getSquadCallParticipants(callId);
  Stream<List<Map<String, dynamic>>> streamSquadCallParticipants(String callId) => call.streamSquadCallParticipants(callId);
  Future<void> joinSquadCall(String callId) => call.joinSquadCall(callId);
  Future<void> declineSquadCall(String callId) => call.declineSquadCall(callId);
  Future<void> endSquadCall(String callId) => call.endSquadCall(callId);
  Future<void> leaveSquadCall(String callId) => call.leaveSquadCall(callId);
  Future<void> updateSquadCallParticipantSdp(String participantId, String sdpJson, String type) => call.updateSquadCallParticipantSdp(participantId, sdpJson, type);
  Future<Map<String, dynamic>?> getSquadCallParticipant(String callId, String userId) => call.getSquadCallParticipant(callId, userId);
  Future<void> addSquadCallIceCandidate(String participantId, String candidate, String? sdpMid, int? sdpMLineIndex) => call.addSquadCallIceCandidate(participantId, candidate, sdpMid, sdpMLineIndex);
  Future<List<Map<String, dynamic>>> getSquadCallIceCandidates(String participantId) => call.getSquadCallIceCandidates(participantId);
  RealtimeChannel subscribeToSquadCallSdp(String participantId, void Function(Map<String, dynamic>) onChange) => call.subscribeToSquadCallSdp(participantId, onChange);
  RealtimeChannel subscribeToSquadCallStatus(String callId, void Function(Map<String, dynamic>) onChange) => call.subscribeToSquadCallStatus(callId, onChange);
  RealtimeChannel subscribeToIncomingSquadCalls(String userId, void Function(Map<String, dynamic>) onCall) => call.subscribeToIncomingSquadCalls(userId, onCall);
  RealtimeChannel subscribeToSquadCallIceCandidates(String participantId, String userId, void Function(Map<String, dynamic>) onCandidate) => call.subscribeToSquadCallIceCandidates(participantId, userId, onCandidate);

  // ─── Posts ───────────────────────────────────────────────────────
  Future<String> uploadPostMedia(Uint8List bytes, String fileName) => post.uploadPostMedia(bytes, fileName);
  Future<String> uploadChatMedia(Uint8List bytes, String fileName) => post.uploadChatMedia(bytes, fileName);
  Future<Map<String, dynamic>> createPost({required String caption, required List<Uint8List> mediaBytes, required List<String> mediaExtensions, String visibility = 'public'}) => post.createPost(caption: caption, mediaBytes: mediaBytes, mediaExtensions: mediaExtensions, visibility: visibility);
  Future<List<Map<String, dynamic>>> getFeedPosts({bool friendsOnly = false}) => post.getFeedPosts(friendsOnly: friendsOnly);
  Future<Map<String, dynamic>?> getPostById(String postId) => post.getPostById(postId);
  Future<List<Map<String, dynamic>>> getUserPosts(String targetUserId) => post.getUserPosts(targetUserId);
  Future<void> deletePost(String postId) => post.deletePost(postId);
  Future<void> likePost(String postId) => post.likePost(postId);
  Future<void> unlikePost(String postId) => post.unlikePost(postId);
  Future<Map<String, dynamic>> addComment({required String postId, required String content, String? parentId}) => post.addComment(postId: postId, content: content, parentId: parentId);
  Future<List<Map<String, dynamic>>> getComments(String postId) => post.getComments(postId);
  Future<void> deleteComment(String commentId) => post.deleteComment(commentId);
  Future<void> likeComment(String commentId) => post.likeComment(commentId);
  Future<void> unlikeComment(String commentId) => post.unlikeComment(commentId);

  // ─── Matching & Reputation ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> findMatches({String? gameType, String? region, String? availability}) => matching.findMatches(gameType: gameType, region: region, availability: availability);
  Future<Map<String, dynamic>?> getUserReputation(String targetUserId) => matching.getUserReputation(targetUserId);
  Future<void> submitReview({required String reviewedId, required int skillScore, required int communicationScore, required int toxicityScore, String? comment}) => matching.submitReview(reviewedId: reviewedId, skillScore: skillScore, communicationScore: communicationScore, toxicityScore: toxicityScore, comment: comment);

  // ─── Notifications & Misc ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getNotifications() => appNotification.getNotifications();
  Future<void> markNotificationRead(dynamic id) => appNotification.markNotificationRead(id);
  Future<int> getUnreadNotificationCount() => appNotification.getUnreadNotificationCount();
  Future<Map<String, dynamic>?> getSubscription() => appNotification.getSubscription();
  Future<List<Map<String, dynamic>>> getGames() => appNotification.getGames();

  // ─── Dashboard ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final profileData = await getProfile();
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
      developer.log('getDashboard error: $e');
    }
    return {'profile': profileData, 'recent_activity': recentActivity};
  }
}
