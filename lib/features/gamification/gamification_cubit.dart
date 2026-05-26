import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quest_gamification/quest_gamification.dart';
import '../../data/services/supabase_backend_service.dart';
import '../../data/services/supabase_progress_repository.dart';
import '../profile/profile_cubit.dart';

class GamificationState extends Equatable {
  final bool isLoading;
  final UserProgress? progress;
  final GamificationResult? lastResult;

  const GamificationState({
    this.isLoading = true,
    this.progress,
    this.lastResult,
  });

  GamificationState copyWith({
    bool? isLoading,
    UserProgress? progress,
    GamificationResult? lastResult,
  }) {
    return GamificationState(
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      lastResult: lastResult,
    );
  }

  @override
  List<Object?> get props => [isLoading, progress, lastResult];
}

class GamificationCubit extends Cubit<GamificationState> {
  final SupabaseBackendService _service;
  final ProfileCubit _profileCubit;
  GamificationEngine? _engine;

  static const _xpMap = {
    'profile_completed': 50,
    'invitation_sent': 10,
    'invitation_accepted': 25,
    'match_found': 5,
    'daily_login': 5,
    'chat_message_sent': 2,
    'profile_updated': 15,
    'friend_added': 20,
  };

  static final _badges = [
    BadgeDefinition(
      id: 'first_invite',
      name: 'Première invitation',
      emoji: '📨',
      description: 'Envoyez votre première invitation',
      condition: (ctx) =>
          ctx.eventId == 'invitation_sent' &&
          (ctx.eventCounts['invitation_sent'] ?? 0) == 1,
    ),
    BadgeDefinition(
      id: 'social_butterfly',
      name: 'Papillon social',
      emoji: '🦋',
      description: 'Envoyez 10 invitations',
      condition: (ctx) =>
          (ctx.eventCounts['invitation_sent'] ?? 0) >= 10,
    ),
    BadgeDefinition(
      id: 'chatty',
      name: 'Bavard',
      emoji: '💬',
      description: 'Envoyez 50 messages',
      condition: (ctx) =>
          (ctx.eventCounts['chat_message_sent'] ?? 0) >= 50,
    ),
    for (final lvl in List.generate(100, (i) => i + 1))
      BadgeDefinition(
        id: 'level_$lvl',
        name: 'Niveau $lvl',
        emoji: lvl <= 5 ? '⭐' : lvl <= 15 ? '🌟' : lvl <= 30 ? '💎' : lvl <= 50 ? '👑' : lvl <= 75 ? '🔥' : '🏆',
        description: 'Atteignez le niveau $lvl',
        condition: (ctx) => ctx.level >= lvl,
      ),
    BadgeDefinition(
      id: 'friend_collector',
      name: 'Collectionneur',
      emoji: '👥',
      description: 'Ajoutez 5 amis',
      condition: (ctx) =>
          (ctx.eventCounts['friend_added'] ?? 0) >= 5,
    ),
    BadgeDefinition(
      id: 'dedicated',
      name: 'Assidu',
      emoji: '🔥',
      description: 'Connectez-vous 7 jours d\'affilée',
      condition: (ctx) => ctx.streak >= 7,
    ),
  ];

  GamificationCubit({
    required SupabaseBackendService service,
    required ProfileCubit profileCubit,
  }) : _service = service,
       _profileCubit = profileCubit,
       super(const GamificationState());

  Future<void> init() async {
    try {
      final userId = _service.userId;
      if (userId == null) {
        emit(state.copyWith(isLoading: false));
        return;
      }

      final repository = SupabaseProgressRepository(userId);

      _engine = GamificationEngine(
        config: QuestConfig(
          xpMap: _xpMap,
          badges: _badges,
          xpPerLevel: 100,
          levelFormula: LevelFormula.fixed,
          shieldGrantInterval: 7,
          maxShields: 3,
        ),
        repository: repository,
      );

      var progress = await _engine!.getProgress();
      // Award any level-based badges the user qualifies for
      final newBadges = <EarnedBadge>[];
      for (final def in _badges) {
        if (!def.id.startsWith('level_')) continue;
        if (progress.hasBadge(def.id)) continue;
        final requiredLevel = int.parse(def.id.split('_')[1]);
        if (progress.level >= requiredLevel) {
          newBadges.add(EarnedBadge(
            badgeId: def.id,
            name: def.name,
            emoji: def.emoji,
            description: def.description,
            earnedAt: DateTime.now(),
          ));
        }
      }
      if (newBadges.isNotEmpty) {
        progress = progress.copyWith(
          earnedBadges: [...progress.earnedBadges, ...newBadges],
        );
        await repository.save(progress);
      }
      emit(GamificationState(isLoading: false, progress: progress));
      _profileCubit.updateGamificationLevel(progress.level);
      _profileCubit.loadProfile();
    } catch (e) {
      debugPrint('GamificationCubit.init error: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  void reset() {
    _engine = null;
    emit(const GamificationState(isLoading: true));
  }

  Future<GamificationResult?> recordEvent(
    String eventId, {
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_engine == null) {
      await init();
      if (_engine == null) return null;
    }
    final result = await _engine!.recordEvent(
      QuestEvent(eventId, metadata: metadata),
    );
    emit(state.copyWith(
      progress: result.progress,
      lastResult: result,
    ));
    _profileCubit.updateGamificationLevel(result.progress.level);
    await syncXpToProfile();
    _profileCubit.loadProfile();
    return result;
  }

  GamificationEngine? get engine => _engine;

  List<BadgeDefinition> get badges => _badges;

  static List<EarnedBadge> levelBadges(int level) {
    final result = <EarnedBadge>[];
    for (final def in _badges) {
      if (!def.id.startsWith('level_')) continue;
      final required = int.parse(def.id.split('_')[1]);
      if (required > level) break;
      if (result.any((b) => b.badgeId == def.id)) continue;
      result.add(EarnedBadge(
        badgeId: def.id,
        name: def.name,
        emoji: def.emoji,
        description: def.description,
        earnedAt: DateTime.now(),
      ));
    }
    return result;
  }

  Future<void> syncXpToProfile() async {
    final progress = state.progress;
    if (progress == null || _service.userId == null) return;
    await _service.updateXp(progress.totalXp);
  }
}
