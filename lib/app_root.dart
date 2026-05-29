import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, AuthChangeEvent;
import 'package:workmanager/workmanager.dart';

import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart' as bg;
import 'core/services/background_service_bridge.dart';
import 'core/services/foreground_call_service.dart';
import 'core/services/push_notification_service.dart';
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
import 'features/call/presentation/screens/team_call_screen.dart';
import 'features/dashboard/presentation/screens/dm_chat_screen.dart';

SupabaseBackendService? globalBackendService;
String _supabaseUrl = '';
String _supabaseAnonKey = '';

Future<void> bootstrapProdix(AppConfig config) async {
  final backenService = SupabaseBackendService(
    isEnabled: config.hasSupabase,
    baseUrl: config.backendApiUrl,
    supabaseUrl: config.supabaseUrl,
  );
  globalBackendService = backenService;

  // Set callback BEFORE initializing the plugin so pending
  // notification responses (e.g. app opened via action button)
  // are not lost.
  NotificationService().onNotificationAction = (actionId, payload) async {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final callId = data['callId'] as String? ?? '';
      final callerId = data['callerId'] as String? ?? '';
      final callType = data['callType'] as String? ?? 'audio';
      final teamId = data['teamId'] as String?;
      final squadId = data['squadId'] as String?;
      final groupName = data['groupName'] as String?;
      NotificationService().cancelNotification(1001);

      if (actionId == 'answer' && callId.isNotEmpty && callerId.isNotEmpty) {
        if (teamId != null || squadId != null) {
          final channelId = teamId != null
              ? (await backenService.getTeamChannelId(teamId))
              : (await backenService.getSquadChannelId(squadId!));
          ProdixApp.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => TeamCallScreen(
                callId: callId,
                groupId: teamId ?? squadId!,
                groupName: groupName ?? 'Groupe',
                callType: callType,
                channelId: channelId ?? '',
                isCaller: false,
                isTeamCall: teamId != null,
              ),
            ),
          );
        } else {
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
      } else if ((actionId == 'decline' || actionId == 'end_call') && callId.isNotEmpty) {
        if (teamId != null) {
          await backenService.declineTeamCall(callId);
        } else if (squadId != null) {
          await backenService.declineSquadCall(callId);
        } else {
          await backenService.updateCallStatus(callId, 'ended');
        }
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
      final peerId = args?['peerId'] as String? ?? '';
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
      } else if (action == 'open_dm' && peerId.isNotEmpty) {
        final profile = await backenService.getOtherProfile(peerId);
        final name = profile?['pseudo'] as String? ?? 'Inconnu';
        final avatar = profile?['avatar_url'] as String?;
        ProdixApp.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DmChatScreen(
              peerId: peerId,
              peerName: name,
              peerAvatar: avatar,
            ),
          ),
        );
      }
    }
  });

  await NotificationService().init();
  await PushNotificationService().init();
  await Workmanager().initialize(bg.callbackDispatcher, isInDebugMode: false);
  if (config.hasSupabase) {
    _supabaseUrl = config.supabaseUrl;
    _supabaseAnonKey = config.supabaseAnonKey;
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
            isEnabled: config.hasSupabase,
            baseUrl: config.backendApiUrl,
            supabaseUrl: config.supabaseUrl,
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

class _RootView extends StatefulWidget {
  const _RootView();

  @override
  State<_RootView> createState() => _RootViewState();
}

class _RootViewState extends State<_RootView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final authCubit = context.read<AuthCubit>();
      if (authCubit.state.status == AuthStatus.authenticated) {
        _doRegister();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  StreamSubscription? _authSub;

  void _doRegister() {
    context.read<GamificationCubit>().init();
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        PushNotificationService().register(session.user.id);
        if (_supabaseUrl.isNotEmpty) {
          BackgroundServiceBridge.start(
            supabaseUrl: _supabaseUrl,
            anonKey: _supabaseAnonKey,
            userId: session.user.id,
            authToken: session.accessToken,
          );
        }
      }
    } catch (_) {}

    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.tokenRefreshed) {
        final token = data.session?.accessToken;
        if (token != null) {
          BackgroundServiceBridge.updateToken(token);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          context.read<ProfileCubit>().reset();
          context.read<GamificationCubit>().reset();
          BackgroundServiceBridge.stop();
          PushNotificationService().unregister();
        } else if (state.status == AuthStatus.authenticated) {
          _doRegister();
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
