import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:workmanager/workmanager.dart';

import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart' as bg;
import 'core/services/foreground_call_service.dart';
import 'core/theme/app_theme.dart';
import 'data/services/ai_gateway_service.dart';
import 'data/services/supabase_backend_service.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/gamification/gamification_cubit.dart';
import 'features/profile/profile_cubit.dart';
import 'features/profile/presentation/screens/profile_setup_screens.dart';
import 'features/dashboard/presentation/screens/main_screen.dart';
import 'features/call/presentation/screens/call_screen.dart';

SupabaseBackendService? globalBackendService;

Future<void> bootstrapProdix(AppConfig config) async {
  await NotificationService().init();
  await Workmanager().initialize(bg.callbackDispatcher, isInDebugMode: false);
  if (config.hasSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
    Workmanager().registerPeriodicTask(
      'periodicCallCheck',
      bg.periodicCheckTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {
        'supabaseUrl': config.supabaseUrl,
        'supabaseAnonKey': config.supabaseAnonKey,
      },
    );
  }

  final backenService = SupabaseBackendService(
    isEnabled: config.hasBackendApi,
    baseUrl: config.backendApiUrl,
  );
  globalBackendService = backenService;

  NotificationService().onNotificationAction = (actionId, payload) async {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final callId = data['callId'] as String? ?? '';
      final callerId = data['callerId'] as String? ?? '';
      final callType = data['callType'] as String? ?? 'audio';
      if (actionId == 'answer' && callId.isNotEmpty && callerId.isNotEmpty) {
        final profile = await backenService.getOtherProfile(callerId);
        final name = profile?['pseudo'] as String? ?? 'Inconnu';
        ProdixApp.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: callId,
              peerId: callerId,
              peerName: name,
              callType: callType,
              isCaller: false,
            ),
          ),
        );
      } else if ((actionId == 'decline' || actionId == 'end_call') && callId.isNotEmpty) {
        await backenService.updateCallStatus(callId, 'ended');
      }
    } catch (e) {
      debugPrint('NotificationService action error: $e');
    }
  };

  ForegroundCallService.setMethodCallHandler((call) async {
    if (call.method == 'onNotificationAction') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      final action = args?['action'] as String?;
      final callId = args?['callId'] as String? ?? '';
      final callType = args?['callType'] as String? ?? 'audio';
      if (action == 'answer' && callId.isNotEmpty) {
        try {
          final call = await backenService.getCall(callId);
          final callerId = call?['caller_id'] as String?;
          if (callerId != null) {
            final profile = await backenService.getOtherProfile(callerId);
            final name = profile?['pseudo'] as String? ?? 'Inconnu';
            ProdixApp.navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  callId: callId,
                  peerId: callerId,
                  peerName: name,
                  callType: callType,
                  isCaller: false,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('ForegroundService answer action error: $e');
        }
      } else if ((action == 'end_call' || action == 'decline') && callId.isNotEmpty) {
        await backenService.updateCallStatus(callId, 'ended');
        CallActionBus.add(CallAction.endCall);
      } else if ((action == 'mute' || action == 'unmute') && callId.isNotEmpty) {
        CallActionBus.add(CallAction.toggleMute);
      } else if ((action == 'speaker' || action == 'speaker_off') && callId.isNotEmpty) {
        CallActionBus.add(CallAction.toggleSpeaker);
      }
    }
  });

  runApp(ProdixApp(config: config));
}

class ProdixApp extends StatelessWidget {
  ProdixApp({super.key, required this.config});

  final AppConfig config;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => SupabaseBackendService(
            isEnabled: config.hasBackendApi,
            baseUrl: config.backendApiUrl,
          ),
        ),
        RepositoryProvider(
          create: (_) => AiGatewayService(
            gatewayUrl: config.aiGatewayUrl,
            huggingFaceToken: config.huggingFaceToken,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                ProfileCubit(context.read<SupabaseBackendService>()),
          ),
          BlocProvider(
            create: (context) => AuthCubit(
              context.read<SupabaseBackendService>(),
              context.read<ProfileCubit>(),
            ),
          ),
          BlocProvider(
            create: (context) => GamificationCubit(
              service: context.read<SupabaseBackendService>(),
              profileCubit: context.read<ProfileCubit>(),
            )..init(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Prodix - TeamUp',
          theme: AppTheme.futuristicDark(),
          home: const _RootView(),
        ),
      ),
    );
  }
}

class _RootView extends StatelessWidget {
  const _RootView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          context.read<ProfileCubit>().reset();
          context.read<GamificationCubit>().reset();
        } else if (state.status == AuthStatus.authenticated) {
          context.read<GamificationCubit>().init();
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            if (state.needsOnboarding) {
              return const ProfileSetupScreens();
            }
            return const MainScreen();
          }
          if (state.status == AuthStatus.unauthenticated) {
            return const LoginScreen();
          }
          return const SplashScreen();
        },
      ),
    );
  }
}
