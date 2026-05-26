import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/config/profile_defaults.dart';
import '../../data/services/supabase_backend_service.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.isLoading = true,
    this.isSaving = false,
    this.pseudo = '',
    this.xp = 0,
    this.language = ProfileDefaults.language,
    this.availability = ProfileDefaults.availability,
    this.gameType = ProfileDefaults.gameType,
    this.role = ProfileDefaults.role,
    this.region = ProfileDefaults.region,
    this.country = ProfileDefaults.country,
    this.bio = '',
    this.avatarUrl,
    this.error,
    this.savedSuccess = false,
    this.completionPercentOverride,
    this.birthDate,
    this.favoriteGames = const [],
    this.email = '',
    this.phone,
    this.location,
    this.showEmail = false,
    this.showPhone = false,
    this.showLocation = true,
    this.friendsCount = 0,
    this.gamificationLevel = 1,
    this.socialInstagram = '',
    this.socialFacebook = '',
    this.socialGithub = '',
  });

  final bool isLoading;
  final bool isSaving;
  final String pseudo;
  final int xp;
  final String language;
  final String availability;
  final String gameType;
  final String role;
  final String region;
  final String country;
  final String bio;
  final String? avatarUrl;
  final String? error;
  final bool savedSuccess;
  final double? completionPercentOverride;
  final String? birthDate;
  final List<String> favoriteGames;
  final String email;
  final String? phone;
  final String? location;
  final bool showEmail;
  final bool showPhone;
  final bool showLocation;
  final int friendsCount;
  final int gamificationLevel;
  final String socialInstagram;
  final String socialFacebook;
  final String socialGithub;

  int get numericLevel => gamificationLevel;

  double get completionPercent {
    if (completionPercentOverride != null) return completionPercentOverride!;
    final fields = <bool>[
      pseudo.isNotEmpty && pseudo != 'Joueur',
      avatarUrl?.isNotEmpty == true,
      gameType.isNotEmpty,
      role.isNotEmpty,
      region.isNotEmpty,
      availability.isNotEmpty,
      language.isNotEmpty,
      bio.isNotEmpty,
      birthDate != null && birthDate!.isNotEmpty,
      favoriteGames.isNotEmpty,
      phone != null && phone!.isNotEmpty,
      location != null && location!.isNotEmpty,
      socialInstagram.isNotEmpty,
      socialFacebook.isNotEmpty,
      socialGithub.isNotEmpty,
    ];
    final filled = fields.where((f) => f).length;
    return (filled / fields.length).clamp(0.0, 1.0);
  }

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? pseudo,
    int? xp,
    String? language,
    String? availability,
    String? gameType,
    String? role,
    String? region,
    String? country,
    String? bio,
    String? avatarUrl,
    String? error,
    bool? savedSuccess,
    double? completionPercentOverride,
    String? birthDate,
    List<String>? favoriteGames,
    String? email,
    String? phone,
    String? location,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    int? friendsCount,
    int? gamificationLevel,
    String? socialInstagram,
    String? socialFacebook,
    String? socialGithub,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      pseudo: pseudo ?? this.pseudo,
      xp: xp ?? this.xp,
      language: language ?? this.language,
      availability: availability ?? this.availability,
      gameType: gameType ?? this.gameType,
      role: role ?? this.role,
      region: region ?? this.region,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error,
      savedSuccess: savedSuccess ?? false,
      completionPercentOverride:
          completionPercentOverride ?? this.completionPercentOverride,
      birthDate: birthDate ?? this.birthDate,
      favoriteGames: favoriteGames ?? this.favoriteGames,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showLocation: showLocation ?? this.showLocation,
      friendsCount: friendsCount ?? this.friendsCount,
      gamificationLevel: gamificationLevel ?? this.gamificationLevel,
      socialInstagram: socialInstagram ?? this.socialInstagram,
      socialFacebook: socialFacebook ?? this.socialFacebook,
      socialGithub: socialGithub ?? this.socialGithub,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        pseudo,
        xp,
        language,
        availability,
        gameType,
        role,
        region,
        country,
        bio,
        avatarUrl,
        error,
        savedSuccess,
        completionPercentOverride,
        birthDate,
        favoriteGames,
        email,
        phone,
        location,
        showEmail,
        showPhone,
        showLocation,
        friendsCount,
        gamificationLevel,
        socialInstagram,
        socialFacebook,
        socialGithub,
      ];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._svc) : super(const ProfileState(isLoading: false));

  final SupabaseBackendService _svc;

  void updateGamificationLevel(int level) {
    emit(state.copyWith(gamificationLevel: level));
  }

  Future<void> loadProfile() async {
    try {
      if (_svc.userId == null) {
        emit(state.copyWith(isLoading: false));
        return;
      }
      final data = await _svc.getProfile();
      if (data != null) {
        final favGames = await _svc.getFavoriteGames();
        final friends = await _svc.getFriends();
        emit(state.copyWith(
          isLoading: false,
          pseudo: data['pseudo'] ?? '',
          xp: data['experience_points'] ?? data['xp'] ?? 0,
          language: data['language'] ?? ProfileDefaults.language,
          availability: data['availability'] ?? ProfileDefaults.availability,
          gameType: data['game_type'] ?? ProfileDefaults.gameType,
          role: data['role'] ?? ProfileDefaults.role,
          region: data['region'] ?? ProfileDefaults.region,
          country: data['country'] ?? ProfileDefaults.country,
          bio: data['bio'] ?? '',
          avatarUrl: data['avatar_url'],
          email: _svc.currentUser?.email ?? '',
          favoriteGames: favGames,
          phone: data['phone'],
          location: data['location'],
          showEmail: data['show_email'] ?? false,
          showPhone: data['show_phone'] ?? false,
          showLocation: data['show_location'] ?? true,
          friendsCount: friends.length,
          socialInstagram: data['social_instagram'] ?? '',
          socialFacebook: data['social_facebook'] ?? '',
          socialGithub: data['social_github'] ?? '',
        ));
      } else {
        // Auto-create profile
        final fallback = _svc.currentUser?.email?.split('@').first ?? 'Joueur';
        await _svc.updateProfile(
          pseudo: fallback,
          xp: ProfileDefaults.xp,
          language: ProfileDefaults.language,
          availability: ProfileDefaults.availability,
          gameType: ProfileDefaults.gameType,
          role: ProfileDefaults.role,
          region: ProfileDefaults.region,
          country: ProfileDefaults.country,
          bio: ProfileDefaults.bio,
        );
        await loadProfile();
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> saveProfile({
    required String pseudo,
    required String language,
    required String availability,
    required String gameType,
    required String role,
    required String region,
    String? country,
    required String bio,
    String? birthDate,
    List<String>? favoriteGames,
    Uint8List? avatarBytes,
    String? avatarExtension,
    String? phone,
    String? location,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    String? socialInstagram,
    String? socialFacebook,
    String? socialGithub,
  }) async {
    emit(state.copyWith(isSaving: true, error: null, savedSuccess: false));
    try {
      if (pseudo.trim().length < 3) {
        throw Exception('Pseudo trop court (min 3 caractères)');
      }

      String? newAvatarUrl = state.avatarUrl;
      if (avatarBytes != null && avatarExtension != null) {
        newAvatarUrl = await _svc.uploadAvatar(avatarBytes, avatarExtension);
      }

      await _svc.updateProfile(
        pseudo: pseudo,
        language: language,
        availability: availability,
        gameType: gameType,
        role: role,
        region: region,
        country: country,
        xp: state.xp,
        bio: bio,
        avatarUrl: newAvatarUrl,
        birthDate: birthDate,
        favoriteGames: favoriteGames,
        phone: phone,
        location: location,
        showEmail: showEmail,
        showPhone: showPhone,
        showLocation: showLocation,
        socialInstagram: socialInstagram,
        socialFacebook: socialFacebook,
        socialGithub: socialGithub,
      );

      emit(state.copyWith(
        isSaving: false,
        pseudo: pseudo,
        language: language,
        availability: availability,
        gameType: gameType,
        role: role,
        region: region,
        country: country ?? state.country,
        bio: bio,
        birthDate: birthDate,
        favoriteGames: favoriteGames ?? state.favoriteGames,
        avatarUrl: (newAvatarUrl != null && newAvatarUrl.isNotEmpty)
            ? newAvatarUrl
            : state.avatarUrl,
        savedSuccess: true,
        phone: phone ?? state.phone,
        location: location ?? state.location,
        showEmail: showEmail ?? state.showEmail,
        showPhone: showPhone ?? state.showPhone,
        showLocation: showLocation ?? state.showLocation,
        socialInstagram: socialInstagram ?? state.socialInstagram,
        socialFacebook: socialFacebook ?? state.socialFacebook,
        socialGithub: socialGithub ?? state.socialGithub,
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: e.toString()));
    }
  }

  Future<void> updateAvatar(Uint8List avatarBytes, String extension) async {
    emit(state.copyWith(isSaving: true, error: null));
    try {
      final url = await _svc.uploadAvatar(avatarBytes, extension);
      emit(state.copyWith(isSaving: false, avatarUrl: url, savedSuccess: true));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: e.toString()));
    }
  }

  void resetSavedSuccess() {
    emit(state.copyWith(savedSuccess: false));
  }

  void reset() {
    emit(const ProfileState(isLoading: false));
  }

  Future<void> detectRegion() async {
    emit(state.copyWith(isSaving: true, error: null));
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Services de localisation désactivés.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Accès position refusé.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Accès position définitivement refusé.');
      }
      final position = await Geolocator.getCurrentPosition();
      String detectedRegion = 'EU';
      if (position.longitude < -30) {
        detectedRegion = 'NA';
      } else if (position.longitude > 60) {
        detectedRegion = 'ASIA';
      } else if (position.latitude < -10) {
        detectedRegion = 'OCE';
      }
      emit(state.copyWith(region: detectedRegion, isSaving: false));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: e.toString()));
    }
  }
}
