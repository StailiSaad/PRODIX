import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/supabase_backend_service.dart';
import '../profile/profile_cubit.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.loading = false,
    this.error,
    this.successMessage,
    this.registeredSuccess = false,
    this.needsOnboarding = false,
  });

  final AuthStatus status;
  final bool loading;
  final String? error;
  final String? successMessage;
  final bool registeredSuccess;
  final bool needsOnboarding;

  AuthState copyWith({
    AuthStatus? status,
    bool? loading,
    String? error,
    String? successMessage,
    bool? registeredSuccess,
    bool? needsOnboarding,
  }) {
    return AuthState(
      status: status ?? this.status,
      loading: loading ?? this.loading,
      error: error,
      successMessage: successMessage,
      registeredSuccess: registeredSuccess ?? false,
      needsOnboarding: needsOnboarding ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [status, loading, error, successMessage, registeredSuccess, needsOnboarding];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._service, this._profileCubit) : super(const AuthState()) {
    _initAuthListener();
  }

  final SupabaseBackendService _service;
  final ProfileCubit _profileCubit;
  StreamSubscription<dynamic>? _supabaseAuthSubscription;

  void _initAuthListener() {
    // Check if Supabase client is available before accessing it
    final hasSupabase = _service.isEnabled;
    if (hasSupabase) {
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentSession != null) {
          emit(state.copyWith(status: AuthStatus.authenticated));
          _profileCubit.loadProfile();
        } else {
          Future.delayed(const Duration(seconds: 2), () {
            if (!isClosed) emit(state.copyWith(status: AuthStatus.unauthenticated));
          });
        }

        _supabaseAuthSubscription = client.auth.onAuthStateChange.listen((data) {
          final session = data.session;
          if (session != null) {
            emit(state.copyWith(status: AuthStatus.authenticated, loading: false));
            _profileCubit.loadProfile();
          } else {
            emit(state.copyWith(status: AuthStatus.unauthenticated, loading: false));
          }
        });
      } catch (_) {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) emit(state.copyWith(status: AuthStatus.unauthenticated));
      });
    }
  }

  Future<void> signUp(String email, String password, String pseudo) async {
    emit(state.copyWith(loading: true, error: null, successMessage: null));
    try {
      await _service.signUp(email, password, pseudo);
      await _service.signOut();
      emit(state.copyWith(
        loading: false,
        registeredSuccess: true,
        status: AuthStatus.unauthenticated,
        successMessage: 'Inscription réussie ! Connectez-vous avec vos identifiants.',
      ));
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('already registered') || msg.contains('already been registered')) {
        msg = 'Cet email est déjà utilisé. Connectez-vous plutôt.';
      }
      emit(state.copyWith(loading: false, error: msg));
    }
  }

  /// Called after profile setup is complete to enter the main app
  void completeOnboarding() {
    emit(state.copyWith(needsOnboarding: false));
  }

  void clearSuccessMessage() {
    emit(state.copyWith(successMessage: null));
  }

  Future<void> signIn(String email, String password) async {
    emit(state.copyWith(loading: true, error: null, successMessage: null, needsOnboarding: false));
    try {
      await _service.signIn(email, password);
      emit(state.copyWith(loading: false));
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('Invalid login credentials')) {
        msg = 'Wrong email or password. Please try again.';
      } else if (msg.contains('Email not confirmed')) {
        msg = 'Email not confirmed. Go to Supabase Dashboard → Auth → Settings → disable "Confirm email", then try again.';
      } else if (msg.contains('too many requests')) {
        msg = 'Too many attempts. Please wait a moment and try again.';
      }
      emit(state.copyWith(loading: false, error: msg));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(loading: true, error: null, successMessage: null));
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'teamup://login-callback',
      );
      // Loading is cleared by onAuthStateChange listener on redirect return
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(loading: true));
    try {
      await _service.signOut();
      emit(state.copyWith(status: AuthStatus.unauthenticated, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _supabaseAuthSubscription?.cancel();
    return super.close();
  }
}

