# 🚀 PRODIX — Prompt Replit Complet

## Projet de Fin d'Études — Application Sociale Gaming + Android Performance Enhancer

> **Auteur** : Staili Saad
> **Technologies** : Flutter 3.41 / Dart 3.11 / Kotlin 2.0 / Supabase / Firebase / WebRTC
> **Dépôt GitHub** : https://github.com/StailiSaad/PRODIX

---

## 📑 Table des Matières

1. [Introduction & Vision](#1-introduction--vision)
2. [Stack Technologique](#2-stack-technologique)
3. [Architecture du Projet](#3-architecture-du-projet)
4. [Structure des Répertoires](#4-structure-des-répertoires)
5. [Schéma de la Base de Données Supabase](#5-schéma-de-la-base-de-données-supabase)
6. [Intégration Firebase Cloud Messaging](#6-intégration-firebase-cloud-messaging)
7. [Modules Android Enhancer (Kotlin/Compose)](#7-modules-android-enhancer-kotlincompose)
8. [Système de Communication WebRTC](#8-système-de-communication-webrtc)
9. [Gamification & XP](#9-gamification--xp)
10. [Intelligence Artificielle & Modération](#10-intelligence-artificielle--modération)
11. [Notifications Push](#11-notifications-push)
12. [Captures d'Écran](#12-captures-décran)
13. [Fonctionnalités Détaillées](#13-fonctionnalités-détaillées)
14. [API & Endpoints](#14-api--endpoints)
15. [Configuration & Déploiement](#15-configuration--déploiement)
16. [Diagrammes & Flux](#16-diagrammes--flux)
17. [Tests & Qualité](#17-tests--qualité)

---

## 1. Introduction & Vision

### 1.1 Contexte

**PRODIX** est une application mobile de **compagnon de jeu social** nouvelle génération qui combine :

1. **Matchmaking intelligent** pour trouver des coéquipiers par jeu, région, disponibilité et niveau
2. **Communication temps réel** via chat textuel, appels vocaux et vidéo (WebRTC)
3. **Réseau social du gaming** avec posts, likes, commentaires et réputation
4. **Optimisation système Android** via un module natif de performance tuning (root, ADB, Shizuku)
5. **IA modératrice** pour la détection de toxicité et recommandations de coéquipiers
6. **Gamification** avec quêtes, XP, badges et niveaux

### 1.2 Problématique

Les joueurs mobiles font face à plusieurs défauts :

- **Isolement social** : Difficulté à trouver des coéquipiers fiables et compétents
- **Latence & perfs** : Appareils non optimisés pour le gaming (thermal throttling, latence réseau)
- **Toxicité** : Absence de modération dans les interactions entre joueurs
- **Fragmentation** : Multiplicité des applications pour différentes fonctionnalités (discord, optimiseur, matchmaking)

### 1.3 Solution Proposée

PRODIX résout ces problèmes en une application unique :

| Problème | Solution PRODIX |
|----------|----------------|
| Trouver des coéquipiers | Algorithme de matchmaking avec scoring heuristique |
| Communiquer | Chat temps réel + Appels WebRTC (P2P, équipe, escouade) |
| Optimiser les perfs | Android Enhancer avec 8 modules de tuning + mode par application |
| Modérer | API Hugging Face pour détection de toxicité |
| Progresser | Système de gamification (XP, niveaux, badges, quêtes) |
| Rester connecté | Notifications push FCM, Realtime Supabase |

---

## 2. Stack Technologique

### 2.1 Frontend Flutter

```yaml
# pubspec.yaml — Dépendances principales
name: prodix
version: 1.0.0+1
environment:
  sdk: ^3.6.0

dependencies:
  flutter: sdk
  flutter_bloc: ^8.1.6        # State management BLoC/Cubit
  equatable: ^2.0.7            # Value equality
  supabase_flutter: ^2.8.0     # Backend (Auth, DB, Realtime, Storage)
  flutter_webrtc: ^1.4.1       # WebRTC audio/video
  firebase_core: ^3.12.0       # Firebase init
  firebase_messaging: ^15.2.0  # Push notifications FCM
  get_it: ^9.2.1               # DI injection
  http: ^1.2.2                 # HTTP requests
  intl: ^0.20.1                # Internationalization
  image_picker: ^1.2.0         # Image picker
  geolocator: 13.0.1           # Location
  google_fonts: ^8.1.0         # Google Fonts
  share_plus: ^10.1.4          # Share
  url_launcher: ^6.3.2         # URL launcher
  file_picker: ^11.0.2         # File picker
  record: ^6.2.1               # Audio recording
  permission_handler: ^12.0.1  # Permissions
  audioplayers: ^6.1.0         # Audio playback
  workmanager: ^0.9.0          # Background tasks
  flutter_local_notifications: ^18.0.1  # Local notifications
  quest_gamification: ^0.1.0   # Quest system
  shared_preferences: ^2.5.3   # Local storage
  cupertino_icons: ^1.0.8      # iOS icons
```

### 2.2 Android Native Enhancer

```kotlin
// build.gradle.kts (androidenhancer Module)
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.androidtweaker.com"
    compileSdk = 35
    defaultConfig {
        minSdk = 24
        targetSdk = 35
    }
}

dependencies {
    // Jetpack Compose BOM
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    
    // Navigation Compose
    implementation("androidx.navigation:navigation-compose:2.8.5")
    
    // Hilt DI
    implementation("com.google.dagger:hilt-android:2.57")
    ksp("com.google.dagger:hilt-compiler:2.57")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")
    
    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    
    // Lifecycle
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    
    // Shizuku
    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    
    // Tests
    testImplementation("junit:junit:4.13.2")
    testImplementation("com.google.truth:truth:1.4.4")
    testImplementation("io.mockk:mockk:1.13.14")
    testImplementation("app.cash.turbine:turbine:1.2.0")
}
```

### 2.3 Backend Supabase

| Service | Utilisation |
|---------|-------------|
| **Supabase Auth** | Authentification par email/password avec JWT |
| **Supabase PostgreSQL** | Base de données relationnelle avec Row Level Security |
| **Supabase Realtime** | WebSocket pour chat, appels, notifications live |
| **Supabase Storage** | Upload d'avatars et médias de posts |
| **Supabase Edge Functions** | Fonctions Deno (send-push-notification) |

### 2.4 Services Externes

| Service | Utilisation |
|---------|-------------|
| **Firebase Cloud Messaging** | Notifications push |
| **Hugging Face Inference API** | Détection de toxicité IA |
| **Google STUN/TURN** | WebRTC NAT traversal |

---

## 3. Architecture du Projet

### 3.1 Architecture en Couches

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRODIX                                       │
├──────────────────────────┬──────────────────────────────────────────┤
│   Flutter (Dart 3.11)    │     Android Native (Kotlin 2.0)         │
│                          │                                          │
│  ┌────────────────────┐  │  ┌──────────────────────────────────┐   │
│  │  UI Layer          │  │  │  Android Enhancer Module         │   │
│  │  ├─ Screens        │  │  │  ├─ UI (Compose)                 │   │
│  │  ├─ Widgets        │  │  │  │  ├─ HomeScreen               │   │
│  │  ├─ Themes (M3)    │  │  │  │  ├─ OptimizationScreen       │   │
│  │  └─ Navigation     │  │  │  │  ├─ PerAppModeScreen         │   │
│  │                    │  │  │  │  ├─ SettingsScreen           │   │
│  │  ┌──────────────┐  │  │  │  │  └─ AboutScreen             │   │
│  │  │ State Mgmt   │  │  │  │  ├────────────────────────────┤   │
│  │  │ Blocs/Cubits │  │  │  │  │ System Layer               │   │
│  │  │ AuthCubit    │  │  │  │  │  ├─ OptimizationExecutor   │   │
│  │  │ ProfileCubit │  │  │  │  │  ├─ JniBridge              │   │
│  │  │ ThemeCubit   │  │  │  │  │  ├─ RootIpc / RootService  │   │
│  │  │ ProgressCubit│  │  │  │  │  ├─ ShizukuManager         │   │
│  │  └──────────────┘  │  │  │  │  ├─ AccessibilityService   │   │
│  │                    │  │  │  │  └─ BootService            │   │
│  │  ┌──────────────┐  │  │  │  ├────────────────────────────┤   │
│  │  │ Services     │  │  │  │  │ Data Layer                 │   │
│  │  │ Supabase     │  │  │  │  │  ├─ AppRepository           │   │
│  │  │ AI Gateway   │  │  │  │  │  └─ AppPreferences(DS)     │   │
│  │  │ GamesService │  │  │  │  └────────────────────────────┘   │
│  │  │ Progress     │  │  │  └──────────────────────────────────┘   │
│  │  └──────────────┘  │                    ▲                       │
│  │                    │                    │ MethodChannel         │
│  │  ┌──────────────┐  │  ┌──────────────────────────────────┐   │
│  │  │ Data Layer   │  │  │  MainActivity.kt                 │   │
│  │  │ Domain Srvcs │  │  │  EnhancerBridge singleton        │   │
│  │  │ Repositories │  │  └──────────────────────────────────┘   │
│  │  └──────────────┘  │                                          │
│  └────────────────────┘  └──────────────────────────────────────────┘
│                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Backend (Supabase + Firebase + HuggingFace)                  │  │
│  │  ┌───────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐  │  │
│  │  │ PostgreSQL│ │ Realtime │ │ Storage  │ │ Auth (JWT)     │  │  │
│  │  │ + RLS     │ │ WebSocket│ │ Avatars  │ │ Email/Password │  │  │
│  │  └───────────┘ └──────────┘ └──────────┘ └───────────────┘  │  │
│  │  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────┐ │  │
│  │  │ Firebase Cloud   │ │ Hugging Face     │ │ Google STUN  │ │  │
│  │  │ Messaging (FCM)  │ │ Inference API    │ │ /TURN        │ │  │
│  │  └──────────────────┘ └──────────────────┘ └──────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Data Flow Principal

```
┌──────────┐     ┌──────────┐     ┌──────────────┐     ┌──────────┐
│   User   │────▶│  Cubit/  │────▶│   Service    │────▶│ Supabase │
│  Action  │     │  Bloc    │     │   Layer      │     │  Backend │
└──────────┘     └──────────┘     └──────┬───────┘     └──────────┘
                                          │
                                    ┌─────┴─────┐
                                    │           │
                                    ▼           ▼
                              AI Gateway   MethodChannel
                           (Hugging Face)      │
                                          ┌─────┴─────┐
                                          │    │      │
                                          ▼    ▼      ▼
                                      Root  Shizuku  ADB
```

### 3.3 Architecture Flutter — Arborescence Complète

```
lib/
│
├── main.dart                          # Point d'entrée de l'application
│   └── bootstrapProdix()              # Initialisation Supabase, Firebase, Workmanager
│
├── app_root.dart                      # Widget racine avec providers BLoC
│   ├── ProdixApp                      # MaterialApp avec thèmes et navigation
│   ├── _RootView                      # Switch Splash / Login / Setup / Main
│   └── bootstrapProdix()              # Initialisation asynchrone
│
├── firebase_options.dart              # Configuration Firebase (Android, iOS, Web)
│
├── core/
│   ├── config/
│   │   ├── app_config.dart            # Variables d'environnement (dart-define)
│   │   │   ├── supabaseUrl
│   │   │   ├── supabaseAnonKey
│   │   │   ├── backendApiUrl
│   │   │   ├── aiGatewayUrl
│   │   │   └── huggingFaceToken
│   │   └── profile_defaults.dart      # Valeurs par défaut du profil
│   │       ├── language = 'fr'
│   │       ├── availability = 'evening'
│   │       ├── gameType = 'FPS'
│   │       ├── role = 'support'
│   │       ├── region = 'EU'
│   │       └── xp = 0
│   │
│   ├── services/
│   │   ├── supabase_backend_service.dart     # Facade principale
│   │   ├── games_service.dart                # Base de données jeux (68K+)
│   │   ├── ai_gateway_service.dart           # API Hugging Face
│   │   ├── supabase_progress_repository.dart # Gamification Supabase
│   │   ├── non_root_service.dart             # Shizuku/ADB bridge
│   │   ├── foreground_call_service.dart       # Service appel foreground
│   │   └── push_notification_service.dart    # FCM notifications
│   │
│   ├── services/domain/
│   │   ├── profile_service.dart              # CRUD profil, avatar, XP
│   │   ├── chat_service.dart                 # Messages, canaux, DMs
│   │   ├── social_service.dart               # Équipes, escouades, amis
│   │   ├── post_service.dart                 # Posts, likes, commentaires
│   │   ├── call_service.dart                 # WebRTC calls (P2P, team, squad)
│   │   ├── matching_service.dart             # Matchmaking + réputation
│   │   └── app_notification_service.dart     # Notifications CRUD
│   │
│   └── theme/
│       └── app_theme.dart                    # Thèmes Material 3
│           ├── futuristicDark()              # Thème sombre
│           ├── futuristicLight()             # Thème clair
│           └── glassmorphism()               # Effet verre
│
├── features/
│   ├── auth/
│   │   ├── auth_cubit.dart                   # État auth (loading/auth/unauth)
│   │   ├── auth_state.dart                   # AuthState avec user profile
│   │   ├── login_screen.dart                 # Écran connexion/inscription
│   │   └── splash_screen.dart                # Écran de chargement initial
│   │
│   ├── profile/
│   │   ├── profile_cubit.dart                # État du profil
│   │   ├── profile_state.dart
│   │   ├── profile_setup_screens.dart        # Onboarding configuration
│   │   └── presentation/screens/
│   │       └── detailed_stats_screen.dart    # Profil détaillé + stats
│   │
│   ├── dashboard/
│   │   └── presentation/screens/
│   │       ├── main_screen.dart              # Navigation tabs principale
│   │       ├── home_dashboard_screen.dart    # Dashboard accueil
│   │       ├── matchmaking_search_screen.dart # Recherche coéquipiers
│   │       ├── team_list_screen.dart         # Liste équipes
│   │       ├── dm_chat_screen.dart           # Chat message direct
│   │       └── _TeammatesTab                 # Tab coéquipiers
│   │
│   ├── call/
│   │   └── presentation/screens/
│   │       ├── call_screen.dart              # Appel P2P audio/vidéo
│   │       └── team_call_screen.dart         # Appel d'équipe
│   │
│   ├── posts/
│   │   └── presentation/screens/
│   │       └── post_screen.dart              # Fil d'actualités
│   │
│   ├── gamification/
│   │   └── gamification_cubit.dart           # XP, quêtes, badges
│   │
│   └── theme/
│       └── theme_cubit.dart                  # Changement thème
│
└── shared/
    └── widgets/                              # Widgets réutilisables
        ├── player_search_delegate.dart
        ├── squad_dialog.dart
        ├── game_filter_bottom_sheet.dart
        └── ...
```

### 3.4 Architecture Android Enhancer — Arborescence Complète

```
android/androidenhancer/
└── src/main/java/com/androidtweaker/com/
    │
    ├── MainActivity.kt                       # Point d'entrée avec Hilt
    │   ├── @AndroidEntryPoint
    │   ├── isRootAvailable()                 # Vérification root/ADB/Shizuku
    │   ├── notificationPermission            # Permission Android 13+
    │   └── EnhancerBridge (MethodChannel)    # Pont avec Flutter
    │
    ├── di/
    │   └── AppModule.kt                      # Module Hilt DI
    │       └── providesCoroutineScope()      # Scope coroutine
    │
    ├── data/
    │   ├── local/
    │   │   └── AppPreferences.kt             # DataStore preferences
    │   │       ├── serviceEnabled
    │   │       ├── performanceMode
    │   │       ├── startOnBoot
    │   │       ├── touchBoostEnabled
    │   │       ├── pureBlackMode
    │   │       ├── dynamicColorsEnabled
    │   │       ├── languageMode
    │   │       ├── themeMode
    │   │       ├── appModeOverrides          # Map<package, mode>
    │   │       ├── adbWriteSecureGranted
    │   │       └── updateXXX() methods
    │   │
    │   └── repository/
    │       └── AppRepository.kt              # Repository central
    │           ├── ServiceLifecycle           # Service ON/OFF
    │           ├── JniBridge.sync()           # Sync JNI
    │           ├── LogWatcher                 # Log monitoring
    │           ├── AccessibilityService       # Foreground detection
    │           └── AutoModeManager            # Auto mode switching
    │
    ├── system/
    │   ├── jni/
    │   │   ├── JniBridge.kt                  # Pont natif C++ (external)
    │   │   │   ├── setCpuGovernor()
    │   │   │   ├── setGpuMaxFreq()
    │   │   │   ├── setIoBoost()
    │   │   │   ├── setNetworkOptimizations()
    │   │   │   ├── setMemoryManagement()
    │   │   │   ├── setThermalMitigation()
    │   │   │   ├── setAudioTuning()
    │   │   │   ├── applyAll()
    │   │   │   └── resetAll()
    │   │   └── AndroidEnhancerMode.kt        # Enum des modes
    │   │       ├── AUTO (0)
    │   │       ├── POWERSAVER (1)
    │   │       ├── BALANCED (2)
    │   │       ├── PERFORMANCE (3)
    │   │       └── GAMING (4)
    │   │
    │   ├── optimization/
    │   │   └── OptimizationExecutor.kt       # Exécuteur scripts shell
    │   │       ├── OptimizationModule enum   # 8 modules
    │   │       ├── executeModule()           # Exécution par module
    │   │       ├── executeAll()              # Exécution tous modules
    │   │       ├── ShizukuExecution          # Via Shizuku stdin
    │   │       ├── RootExecution             # Via RootIpc
    │   │       ├── AdbExecution              # Via ProcessBuilder
    │   │       └── getScriptForModule()      # Scripts shell par module
    │   │
    │   ├── root/
    │   │   ├── RootIpc.kt                    # Service root AIDL
    │   │   │   └── executeCommand(cmd)       # Exécution commande root
    │   │   └── RootService.kt                # Implémentation service
    │   │       └── onStartCommand()          # Delegue à JniBridge
    │   │
    │   ├── service/
    │   │   ├── AccessibilityService.kt       # Détection app foreground
    │   │   │   ├── onAccessibilityEvent()    # Changement app
    │   │   │   ├── getCurrentApp()           # Package courant
    │   │   │   ├── isScreenOn()              # État écran
    │   │   │   └── getBatteryLevel()         # Niveau batterie
    │   │   └── BootService.kt                # Service foreground démarrage
    │   │
    │   ├── receiver/
    │   │   └── BootReceiver.kt               # BroadcastReceiver BOOT_COMPLETED
    │   │
    │   └── util/
    │       ├── BatteryUtil.kt                # Capacité batterie (PowerProfile)
    │       ├── Constants.kt                  # TAG, channel IDs, notification IDs
    │       └── AppUtil.kt                    # InstalledApp data class
    │
    ├── ui/
    │   ├── navigation/
    │   │   ├── AppNavHost.kt                 # NavHost avec bottom bar
    │   │   │   ├── Home / Tweaks / Apps / Settings
    │   │   │   └── PRODIX launch button
    │   │   └── AppDestination.kt             # Sealed class destinations
    │   │
    │   ├── theme/
    │   │   ├── Theme.kt                      # Material 3 themes
    │   │   ├── Color.kt                      # Neon blue, accent, glass
    │   │   ├── Shape.kt                      # Card shapes
    │   │   └── Type.kt                       # Typography
    │   │
    │   ├── components/
    │   │   └── LoadingIndicatorDialogComponent.kt
    │   │
    │   └── screens/
    │       ├── home/
    │       │   ├── HomeScreen.kt             # Hero card, modes, per-app
    │       │   ├── HomeViewModel.kt          # État home + auto-enable
    │       │   └── HomeState.kt              # Data class
    │       │
    │       ├── optimization/
    │       │   ├── OptimizationScreen.kt     # Module toggles + status
    │       │   ├── OptimizationViewModel.kt  # État optimisations
    │       │   └── OptimizationState.kt      # Data class
    │       │
    │       ├── per_app_mode/
    │       │   ├── PerAppModeScreen.kt       # Liste apps + modes
    │       │   ├── PerAppModeViewModel.kt    # État per-app
    │       │   └── PerAppModeState.kt        # Data class
    │       │
    │       ├── settings/
    │       │   ├── SettingsScreen.kt         # Boot, touch, thème, langue
    │       │   ├── SettingsViewModel.kt      # État settings
    │       │   └── SettingsState.kt          # ThemeMode, LanguageMode
    │       │
    │       └── about/
    │           ├── AboutScreen.kt            # À propos + PRODIX branding
    │           ├── AboutViewModel.kt         # État about
    │           └── AboutState.kt             # Data class
    │
    └── test/
        ├── OptimizationExecutorTest.kt
        ├── PreferencesSnapshotTest.kt
        ├── RootIpcTest.kt
        ├── SettingsStateTest.kt
        ├── OptimizationStateTest.kt
        └── AndroidEnhancerModeTest.kt
```

---

## 4. Structure des Répertoires

### 4.1 Arborescence Racine

```
PRODIX/
│
├── lib/                                    # Code source Flutter/Dart
├── android/                                # Code source Android
│   ├── app/                                # Hôte Flutter + MethodChannel
│   └── androidenhancer/                    # Module enhancer natif
├── supabase/                               # Scripts Supabase
│   ├── migrations/                         # Migrations formelles
│   ├── functions/                          # Edge Functions Deno
│   │   └── send-push-notification/index.ts
│   └── *.sql                               # Scripts SQL
├── supabase_migrations/                    # Migrations informelles
├── assets/
│   ├── data/
│   │   ├── games_db.json                  # 68 000+ jeux
│   │   └── countries.json                 # Liste pays
│   └── prodix_logo.png                    # Logo
├── screenshots/                            # Captures d'écran
│   ├── social/                            # Screens sociaux
│   └── android_tweaker/                   # Screens enhancer
├── pictures/                              # Source screenshots
├── firebase.json                           # Config Firebase
├── pubspec.yaml                            # Dépendances Flutter
├── supabase_setup.sql                      # Schéma complet
└── prodix-v1.0.0.apk                       # APK release
```

---

## 5. Schéma de la Base de Données Supabase

### 5.1 Tables et Relations Complètes

#### 5.1.1 profiles — Profils Utilisateurs

```sql
CREATE TABLE profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        TEXT UNIQUE NOT NULL,
    pseudo          TEXT,
    avatar_url      TEXT,
    bio             TEXT,
    country         TEXT,
    language        TEXT DEFAULT 'fr',
    rank_mmr        INTEGER DEFAULT 1000,
    xp              INTEGER DEFAULT 0,
    level           INTEGER DEFAULT 1,
    game_type       TEXT DEFAULT 'FPS',
    role            TEXT DEFAULT 'support',
    region          TEXT DEFAULT 'EU',
    availability    TEXT DEFAULT 'evening',
    birth_date      DATE,
    social_instagram TEXT,
    social_facebook  TEXT,
    social_github    TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_profiles_username ON profiles(username);
CREATE INDEX idx_profiles_game_type ON profiles(game_type);
CREATE INDEX idx_profiles_region ON profiles(region);
CREATE INDEX idx_profiles_rank_mmr ON profiles(rank_mmr DESC);

-- RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- SELECT: tous les utilisateurs authentifiés
-- UPDATE: propriétaire seulement
```

#### 5.1.2 games — Catalogue de Jeux

```sql
CREATE TABLE games (
    id          BIGINT PRIMARY KEY,
    name        TEXT NOT NULL,
    slug        TEXT,
    genre       TEXT[],
    platforms   TEXT[],
    cover_url   TEXT,
    summary     TEXT,
    rating      REAL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- RLS: SELECT pour tous
```

#### 5.1.3 profile_favorite_games — Jeux Favoris

```sql
CREATE TABLE profile_favorite_games (
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    game_id     BIGINT REFERENCES games(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (profile_id, game_id)
);

-- RLS: SELECT/INSERT/DELETE pour le propriétaire
```

#### 5.1.4 teams — Équipes

```sql
CREATE TABLE teams (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT,
    avatar_url  TEXT,
    created_by  UUID REFERENCES profiles(id),
    max_members INTEGER DEFAULT 50,
    squad_id    UUID REFERENCES squads(id),
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_teams_created_by ON teams(created_by);

-- RLS: SELECT pour membres, INSERT pour auth
```

#### 5.1.5 team_members — Membres d'Équipe

```sql
CREATE TABLE team_members (
    team_id     UUID REFERENCES teams(id) ON DELETE CASCADE,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    role        TEXT DEFAULT 'member',
    joined_at   TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (team_id, profile_id)
);

CREATE INDEX idx_team_members_profile ON team_members(profile_id);

-- RLS: SELECT pour membres de l'équipe
```

#### 5.1.6 squads — Escouades

```sql
CREATE TABLE squads (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT,
    created_by  UUID REFERENCES profiles(id),
    max_members INTEGER DEFAULT 5,
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

#### 5.1.7 squad_members — Membres d'Escouade

```sql
CREATE TABLE squad_members (
    squad_id    UUID REFERENCES squads(id) ON DELETE CASCADE,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    role        TEXT DEFAULT 'member',
    joined_at   TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (squad_id, profile_id)
);

CREATE INDEX idx_squad_members_profile ON squad_members(profile_id);
```

#### 5.1.8 channels — Canaux de Discussion

```sql
CREATE TABLE channels (
    id          UUID PRIMARY KEY,
    team_id     UUID REFERENCES teams(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    type        TEXT DEFAULT 'text',
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

#### 5.1.9 messages — Messages

```sql
CREATE TABLE messages (
    id          BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    channel_id  UUID REFERENCES channels(id) ON DELETE CASCADE,
    sender_id   UUID REFERENCES profiles(id) NOT NULL,
    receiver_id UUID REFERENCES profiles(id),
    content     TEXT,
    media_url   TEXT,
    media_type  TEXT,
    media_name  TEXT,
    duration    INTEGER,
    status      TEXT DEFAULT 'sent',
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_messages_channel ON messages(channel_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);

ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

#### 5.1.10 calls — Appels P2P

```sql
CREATE TABLE calls (
    id          UUID PRIMARY KEY,
    caller_id   UUID REFERENCES profiles(id) NOT NULL,
    callee_id   UUID REFERENCES profiles(id) NOT NULL,
    status      TEXT DEFAULT 'ringing',
    call_type   TEXT DEFAULT 'audio',
    offer_sdp   TEXT,
    answer_sdp  TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_calls_caller ON calls(caller_id);
CREATE INDEX idx_calls_callee ON calls(callee_id);
CREATE INDEX idx_calls_status ON calls(status);

ALTER PUBLICATION supabase_realtime ADD TABLE calls;
```

#### 5.1.11 call_ice_candidates — Candidats ICE

```sql
CREATE TABLE call_ice_candidates (
    id          BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    call_id     UUID REFERENCES calls(id) ON DELETE CASCADE,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    candidate   TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ice_call ON call_ice_candidates(call_id);

ALTER PUBLICATION supabase_realtime ADD TABLE call_ice_candidates;
```

#### 5.1.12 team_calls — Appels d'Équipe

```sql
CREATE TABLE team_calls (
    id          UUID PRIMARY KEY,
    team_id     UUID REFERENCES teams(id) ON DELETE CASCADE,
    caller_id   UUID REFERENCES profiles(id) NOT NULL,
    status      TEXT DEFAULT 'ringing',
    call_type   TEXT DEFAULT 'audio',
    offer_sdp   TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_team_calls_team ON team_calls(team_id);
CREATE INDEX idx_team_calls_status ON team_calls(status);

ALTER PUBLICATION supabase_realtime ADD TABLE team_calls;
```

#### 5.1.13 team_call_participants — Participants Appel Équipe

```sql
CREATE TABLE team_call_participants (
    id          BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    call_id     UUID REFERENCES team_calls(id) ON DELETE CASCADE,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    joined_at   TIMESTAMPTZ,
    left_at     TIMESTAMPTZ
);

CREATE INDEX idx_tcp_call ON team_call_participants(call_id);
CREATE INDEX idx_tcp_profile ON team_call_participants(profile_id);

ALTER PUBLICATION supabase_realtime ADD TABLE team_call_participants;
```

#### 5.1.14 posts — Publications

```sql
CREATE TABLE posts (
    id          UUID PRIMARY KEY,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    media_url   TEXT,
    visibility  TEXT DEFAULT 'public',
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_posts_profile ON posts(profile_id);
CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_posts_visibility ON posts(visibility);

ALTER PUBLICATION supabase_realtime ADD TABLE posts;
```

#### 5.1.15 post_likes — Likes sur Publications

```sql
CREATE TABLE post_likes (
    id          BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    post_id     UUID REFERENCES posts(id) ON DELETE CASCADE,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE (post_id, profile_id)
);

ALTER PUBLICATION supabase_realtime ADD TABLE post_likes;
```

#### 5.1.16 post_comments — Commentaires

```sql
CREATE TABLE post_comments (
    id          BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    post_id     UUID REFERENCES posts(id) ON DELETE CASCADE,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_post_comments_post ON post_comments(post_id);

ALTER PUBLICATION supabase_realtime ADD TABLE post_comments;
```

#### 5.1.17 friends — Amis

```sql
CREATE TABLE friends (
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    friend_id   UUID REFERENCES profiles(id) ON DELETE CASCADE,
    status      TEXT DEFAULT 'pending',
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (profile_id, friend_id)
);
```

#### 5.1.18 invitations — Invitations

```sql
CREATE TABLE invitations (
    id          UUID PRIMARY KEY,
    sender_id   UUID REFERENCES profiles(id) NOT NULL,
    receiver_id UUID REFERENCES profiles(id) NOT NULL,
    team_id     UUID REFERENCES teams(id),
    status      TEXT DEFAULT 'pending',
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

#### 5.1.19 notifications — Notifications

```sql
CREATE TABLE notifications (
    id          UUID PRIMARY KEY,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    type        TEXT NOT NULL,
    title       TEXT,
    body        TEXT,
    data        JSONB,
    is_read     BOOLEAN DEFAULT false,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_notif_profile ON notifications(profile_id);
CREATE INDEX idx_notif_read ON notifications(profile_id, is_read);

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
```

#### 5.1.20 devices — Appareils (FCM Tokens)

```sql
CREATE TABLE devices (
    id          UUID PRIMARY KEY,
    profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    token       TEXT NOT NULL,
    platform    TEXT DEFAULT 'android',
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

#### 5.1.21 reputation_reviews — Évaluations

```sql
CREATE TABLE reputation_reviews (
    id          UUID PRIMARY KEY,
    reviewer_id  UUID REFERENCES profiles(id) NOT NULL,
    target_id    UUID REFERENCES profiles(id) NOT NULL,
    skill       INTEGER CHECK (skill >= 1 AND skill <= 5),
    communication INTEGER CHECK (communication >= 1 AND communication <= 5),
    conduct     INTEGER CHECK (conduct >= 1 AND conduct <= 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE (reviewer_id, target_id)
);
```

#### 5.1.22 user_progress — Progression Gamification

```sql
CREATE TABLE user_progress (
    profile_id  UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    total_xp    INTEGER DEFAULT 0,
    level       INTEGER DEFAULT 1,
    badges      JSONB DEFAULT '[]',
    quests      JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_progress_modtime
    BEFORE UPDATE ON user_progress
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();
```

### 5.2 Diagramme Relationnel Complet

```
                    ┌─────────────────────┐
                    │      profiles       │
                    ├─────────────────────┤
                    │ id (PK)             │──┐
                    │ pseudo              │  │
                    │ username            │  │
                    │ avatar_url          │  │
                    │ xp / level          │  │
                    │ game_type / role    │  │
                    │ region / language   │  │
                    │ rank_mmr            │  │
                    └─────────────────────┘  │
                          │  │  │  │  │  │   │
         ┌───────────────┘  │  │  │  │  │   │
         ▼                  ▼  ▼  ▼  ▼  ▼   ▼
┌────────────────┐  ┌────────────────┐  ┌──────────────┐
│  teams         │  │  squads       │  │  games       │
├────────────────┤  ├────────────────┤  ├──────────────┤
│ id (PK)        │  │ id (PK)       │  │ id (PK)      │
│ name           │  │ name          │  │ name         │
│ created_by(FK)─┤  │ created_by(FK)│  │ genre        │
│ squad_id (FK)──┤  └────────────────┘  └──────┬───────┘
└────────┬───────┘         │                    │
         │                 │                    │
         ▼                 ▼                    ▼
┌────────────────┐  ┌────────────────┐  ┌──────────────────┐
│  team_members  │  │  squad_members │  │ profile_fav_     │
├────────────────┤  ├────────────────┤  │ games            │
│ team_id (FK)   │  │ squad_id (FK)  │  ├──────────────────┤
│ profile_id(FK) │  │ profile_id(FK) │  │ profile_id (FK)  │
└────────────────┘  └────────────────┘  │ game_id (FK)     │
         │                              └──────────────────┘
         ▼
┌────────────────┐
│  channels      │
├────────────────┤
│ id (PK)        │
│ team_id (FK)   │
│ name           │
└────────┬───────┘
         │
         ▼
┌────────────────┐
│  messages      │
├────────────────┤
│ id (PK)        │
│ channel_id(FK) │
│ sender_id (FK) │
│ receiver_id(FK)│
│ content        │
│ media_url      │
└────────────────┘

┌────────────────┐  ┌──────────────────────┐  ┌────────────────┐
│  calls (P2P)   │  │  team_calls          │  │  squad_calls   │
├────────────────┤  ├──────────────────────┤  ├────────────────┤
│ id (PK)        │  │ id (PK)              │  │ id (PK)        │
│ caller_id (FK) │  │ team_id (FK)         │  │ squad_id (FK)  │
│ callee_id (FK) │  │ caller_id (FK)       │  │ caller_id (FK) │
│ status         │  │ status               │  │ status         │
│ offer_sdp      │  │ offer_sdp            │  │ offer_sdp      │
│ answer_sdp     │  └──────────┬───────────┘  └────────────────┘
└────────┬───────┘             │
         │                     ▼
         ▼         ┌──────────────────────┐
┌────────────────┐ │  t_call_participants │
│ ice_candidates │ ├──────────────────────┤
├────────────────┤ │ call_id (FK)         │
│ call_id (FK)   │ │ profile_id (FK)      │
│ profile_id (FK)│ │ joined_at / left_at  │
│ candidate      │ └──────────────────────┘
└────────────────┘

┌────────────────┐  ┌────────────────┐  ┌───────────────────┐
│  posts         │  │  post_likes    │  │  post_comments    │
├────────────────┤  ├────────────────┤  ├───────────────────┤
│ id (PK)        │  │ post_id (FK)   │  │ post_id (FK)      │
│ profile_id (FK)│  │ profile_id (FK)│  │ profile_id (FK)   │
│ content        │  │ created_at     │  │ content           │
│ media_url      │  └────────────────┘  └───────────────────┘
│ visibility     │
└────────────────┘

┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  invitations   │  │  friends         │  │  notifications   │
├────────────────┤  ├──────────────────┤  ├──────────────────┤
│ sender_id (FK) │  │ profile_id (FK)  │  │ profile_id (FK)  │
│ receiver_id(FK)│  │ friend_id (FK)   │  │ type / title     │
│ team_id (FK)   │  │ status           │  │ body / data      │
│ status         │  └──────────────────┘  │ is_read          │
└────────────────┘                       └──────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐
│  devices (FCM)   │  │ reputation_revs  │  │ user_progress   │
├──────────────────┤  ├──────────────────┤  ├─────────────────┤
│ profile_id (FK)  │  │ reviewer_id (FK) │  │ profile_id (FK) │
│ token            │  │ target_id (FK)   │  │ total_xp        │
│ platform         │  │ skill(1-5)       │  │ level           │
└──────────────────┘  │ communication(5) │  │ badges (JSONB)  │
                      │ conduct (5)      │  │ quests (JSONB)  │
                      └──────────────────┘  └─────────────────┘
```

### 5.3 Realtime Subscriptions

| Table | Événements | Utilisation |
|-------|-----------|-------------|
| `messages` | INSERT | Chat en direct |
| `calls` | INSERT, UPDATE | Appels P2P |
| `team_calls` | INSERT, UPDATE | Appels équipe |
| `team_call_participants` | INSERT | Participants appels équipe |
| `squad_calls` | INSERT, UPDATE | Appels escouade |
| `squad_call_participants` | INSERT | Participants appels escouade |
| `call_ice_candidates` | INSERT | ICE candidates WebRTC |
| `posts` | INSERT, UPDATE, DELETE | Fil d'actualités |
| `post_likes` | INSERT, DELETE | Likes temps réel |
| `post_comments` | INSERT | Commentaires temps réel |
| `notifications` | INSERT | Notifications temps réel |

### 5.4 Edge Function — send-push-notification

```typescript
// supabase/functions/send-push-notification/index.ts
// Deno Edge Function pour notifications push FCM v1

// Types supportés :
// - message: Nouveau message chat
// - call: Appel entrant
// - missed_call: Appel manqué
// - invitation: Invitation équipe
// - post_like: Like sur publication
// - post_comment: Commentaire sur publication
// - comment_like: Like sur commentaire
// - comment_reply: Réponse à commentaire

// Payload enrichi :
interface PushPayload {
  type: string;
  title: string;
  body: string;
  actor_id: string;
  actor_avatar_url: string;
  post_id?: string;
  comment_id?: string;
  call_id?: string;
  team_id?: string;
  channel_id?: string;
}

// Flux : Supabase Trigger → Edge Function → FCM v1 → Appareil
```

---

## 6. Intégration Firebase Cloud Messaging

### 6.1 Configuration Firebase

```dart
// lib/firebase_options.dart
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRhTHnOEVXISjNMOPrXSfc1TrJetzwmCQ',
    appId: '1:1057439091548:android:7b2ebc54fbd56989b58f99',
    messagingSenderId: '1057439091548',
    projectId: 'prodix-6889a',
    storageBucket: 'prodix-6889a.firebasestorage.app',
  );
  // + iOS, Web, macOS configurations
}
```

### 6.2 Notifications Push — Fonctions Base de Données

Les notifications push sont déclenchées par des fonctions PostgreSQL via Supabase Database Webhooks :

1. **notify_push_on_message** — Nouveau message dans un canal
2. **notify_push_on_call** — Appel entrant
3. **notify_push_on_invitation** — Invitation reçue
4. **notify_push_on_team_call_participant** — Appel d'équipe
5. **notify_push_on_squad_call_participant** — Appel d'escouade
6. **notify_missed_call_on_update** — Appel manqué
7. **notify_push_on_post_like** — Like sur publication
8. **notify_push_on_post_comment** — Commentaire
9. **notify_push_on_comment_like** — Like sur commentaire

### 6.3 Workmanager — Tâches Background

```dart
// Tâches périodiques (toutes les 15 min)
await Workmanager().registerPeriodicTask(
  'notification-polling',
  'pollNotifications',
  frequency: Duration(minutes: 15),
  existingWorkPolicy: ExistingWorkPolicy.keep,
);
```

---

## 7. Modules Android Enhancer (Kotlin/Compose)

### 7.1 Architecture MVVM avec Clean Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      MVVM Clean Architecture                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  UI Layer (Compose)                                 │    │
│  │  ├─ Screen (Composable functions)                   │    │
│  │  ├─ ViewModel (StateFlow<State>)                    │    │
│  │  └─ State (Data class immuable)                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                        │                                     │
│                        ▼                                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Domain Layer                                       │    │
│  │  ├─ AppRepository (façade)                         │    │
│  │  └─ OptimizationExecutor (scripts shell)           │    │
│  └─────────────────────────────────────────────────────┘    │
│                        │                                     │
│                        ▼                                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Data Layer                                         │    │
│  │  ├─ AppPreferences (DataStore)                     │    │
│  │  ├─ JniBridge (C++ natif)                         │    │
│  │  ├─ RootIpc (LibSu)                               │    │
│  │  └─ ShizukuManager (Shizuku v13)                  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Diagramme de Navigation (AppNavHost)

```
[M Hollow]    ──▶  HomeScreen
[Gaming]      ──▶  HomeScreen (mode gaming)
[Flash]       ──▶  HomeScreen (mode performance)

Bottom Navigation :
┌─────────┬──────────┬─────────┬──────────┐
│  Home   │  Tweaks  │  Apps   │ Settings │
├─────────┼──────────┼─────────┼──────────┤
│ Home    │ Optimiz. │ Per-app │ Settings │
│ Screen  │  Screen  │  Mode   │  Screen  │
│         │          │ Screen  │          │
└─────────┴──────────┴─────────┴──────────┘

Bouton PRODIX (FAB) :
└── AboutScreen
```

### 7.3 États et ViewModels

Chaque écran suit le pattern **Screen → ViewModel → State** :

```kotlin
// Exemple : HomeState.kt
data class HomeState(
    val isServiceEnabled: Boolean = false,
    val currentMode: AndroidEnhancerMode = AndroidEnhancerMode.AUTO,
    val isStartOnBoot: Boolean = false,
    val isTouchBoostEnabled: Boolean = false,
    val installedApps: List<InstalledApp> = emptyList(),
    val appModeOverrides: Map<String, AndroidEnhancerMode> = emptyMap(),
    val currentAppPackage: String? = null,
    val currentAppName: String? = null,
    val batteryLevel: Int = 0,
)

// Exemple : OptimizationState.kt
data class OptimizationState(
    val isServiceEnabled: Boolean = false,
    val isExecuting: Boolean = false,
    val moduleStates: Map<OptimizationModule, Boolean> = emptyMap(),
    val executionResult: OptimizationResult? = null,
)

// Exemple : PerAppModeState.kt
data class PerAppModeState(
    val apps: List<InstalledApp> = emptyList(),
    val overrides: Map<String, AndroidEnhancerMode> = emptyMap(),
    val searchQuery: String = "",
    val selectedGenre: String? = null,
)

// Exemple : SettingsState.kt
data class SettingsState(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val languageMode: LanguageMode = LanguageMode.SYSTEM,
    val isStartOnBoot: Boolean = false,
    val isTouchBoostEnabled: Boolean = false,
    val isPureBlackMode: Boolean = false,
    val areDynamicColorsEnabled: Boolean = true,
)

enum class ThemeMode { SYSTEM, LIGHT, DARK }
enum class LanguageMode { SYSTEM, FRENCH, ENGLISH }
```

### 7.4 Les 8 Modules d'Optimisation

#### Module 1 : Frame Pacing
```
Objectif : Lisser le rafraîchissement et réduire les micro-stutters
Script :
  setprop debug.sf.showupdates 0
  setprop debug.egl.hw 1
  setprop debug.sf.hw 1
  setprop debug.composition.type gpu
  setprop video.accelerate.hw 1
  service call SurfaceFlinger 1008 i32 1
  settings put global window_animation_scale 0.5
  settings put global transition_animation_scale 0.5
  settings put global animator_duration_scale 0.5
```

#### Module 2 : GoodPing
```
Objectif : Réduire la latence réseau et optimiser DNS/TCP
Script :
  setprop net.dns1 8.8.8.8
  setprop net.dns2 8.8.4.4
  setprop net.tcp.buffers.default 4096,87380,256960,4096,16384,256960
  setprop net.tcp.buffers.wifi 4096,87380,256960,4096,16384,256960
  setprop net.tcp.buffers.lte 4096,87380,256960,4096,16384,256960
  setprop net.tcp.delayed_ack 0
  setprop net.tcp.disable_compression 1
  setprop net.tcp.rfc1337 1
```

#### Module 3 : PerfExt
```
Objectif : Améliorer le rendu GPU et la réactivité système
Script :
  setprop debug.performance.tuning 1
  setprop debug.gralloc.gfx_ubwc 1
  setprop debug.renderengine.backend opengles
  setprop persist.sys.composition.type gpu
  setprop debug.sf.enable_hwc_vds 0
  setprop debug.sf.disable_backpressure 1
  setprop debug.sf.enable_gl_backpressure 0
```

#### Module 4 : Runtime Control
```
Objectif : Désactiver les mécanismes d'économie d'énergie intrusifs
Script :
  settings put global app_standby_enabled 0
  settings put global doze_enabled 0
  settings put global device_idle_constants 0
  settings put global adaptive_battery_management_enabled 0
  settings put global cached_apps_freezer enabled=0
  settings put global wifi_sleep_policy 2
```

#### Module 5 : GamePulse
```
Objectif : Activer le mode jeu et l'optimisation GPU driver
Script :
  settings put global game_driver_opt_in 1
  settings put global game_driver_all_apps 1
  settings put global game_driver_blacklist ""
  setprop debug.game.driver 1
  setprop debug.game.renderer opengles
  setprop debug.game.workaround 1
```

#### Module 6 : GPU Boost
```
Objectif : Optimiser le rendu graphique via Skia/Vulkan
Script :
  setprop debug.renderengine.backend skiavk
  setprop debug.hwui.renderer skiavk
  setprop debug.hwui.use_hw_vulkan 1
  setprop debug.composition.type mdp
  setprop persist.sys.composition.type mdp
  setprop debug.sf.enable_gl_backpressure 0
```

#### Module 7 : Audio Tuning
```
Objectif : Optimiser le pipeline audio pour la basse latence
Script :
  setprop persist.audio.fluence.voicecall true
  setprop persist.audio.fluence.speaker true
  setprop persist.audio.fluence.voicerec true
  setprop persist.vendor.audio.voicecall.speaker.stereo true
  setprop persist.vendor.audio.speaker.stereo true
  setprop persist.audio.handset_mic.type digital
  setprop persist.audio.voice.clarity on
```

#### Module 8 : Hyper Performance
```
Objectif : Optimisation complète système (CPU/GPU/mémoire/E/S)
Script :
  # Arrêt services thermiques
  stop thermal-engine
  stop thermald
  stop thermorelay
  
  # Gouverneurs CPU - Performance
  echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
  echo performance > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
  echo performance > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
  echo performance > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
  echo performance > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
  echo performance > /sys/devices/system/cpu/cpu5/cpufreq/scaling_governor
  echo performance > /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
  echo performance > /sys/devices/system/cpu/cpu7/cpufreq/scaling_governor
  
  # Activation de tous les cœurs CPU
  for cpu in /sys/devices/system/cpu/cpu*/online; do echo 1 > $cpu; done
  
  # Fréquences GPU max
  echo 1 > /sys/class/kgsl/kgsl-3d0/force_clk_on
  echo 1 > /sys/class/kgsl/kgsl-3d0/force_bus_on
  echo 1 > /sys/class/kgsl/kgsl-3d0/force_rail_on
  echo 100 > /sys/class/kgsl/kgsl-3d0/devfreq/governor
  
  # Optimisation mémoire
  echo 0 > /proc/sys/vm/swappiness
  echo 0 > /proc/sys/vm/dirty_ratio
  echo 100 > /proc/sys/vm/vfs_cache_pressure
  echo 0 > /proc/sys/vm/oom_kill_allocating_task
  
  # Optimisation I/O
  echo cfq > /sys/block/mmcblk0/queue/scheduler
  echo 1024 > /sys/block/mmcblk0/queue/read_ahead_kb
  echo 0 > /sys/block/mmcblk0/queue/iostats
  echo 2 > /sys/block/mmcblk0/queue/nomerges
```

### 7.5 Modes de Performance (AndroidEnhancerMode)

```kotlin
enum class AndroidEnhancerMode(val value: Int, val label: String) {
    AUTO(0, "Auto"),         // Ajustement dynamique selon l'utilisation
    POWERSAVER(1, "Éco"),    // Économie d'énergie maximale
    BALANCED(2, "Équilibré"),// Compromis perf/autonomie
    PERFORMANCE(3, "Perf"),  // Haute performance soutenue
    GAMING(4, "Gaming");     // Performance maximale pour le jeu
}
```

### 7.6 Modes d'Exécution

| Mode | Mécanisme | Détection |
|------|-----------|-----------|
| **Root** | `su -c commande` via LibSu | `which su` |
| **ADB** | `ProcessBuilder("sh", "-c", commande)` | `WRITE_SECURE_SETTINGS` grant |
| **Shizuku** | `Shizuku.newProcess()` via réflexion | `Shizuku.pingBinder()` |

### 7.7 Pont Flutter ↔ Android Natif (MethodChannel)

```kotlin
// EnhancerBridge.kt — Singleton accessible depuis Flutter
object EnhancerBridge {
    // 13 méthodes exposées :
    fun getStatus(): Map         // isRootAvailable, service, mode, etc.
    fun setEnabled(boolean)      // ON / OFF service
    fun setMode(mode: Int)       // Changer mode performance
    fun setTouchBoost(boolean)
    fun setStartOnBoot(boolean)
    fun getInstalledApps(): List // Apps installées
    fun getAppModes(): Map       // Overrides per-app
    fun setAppMode(pkg, mode)
    fun removeAppMode(pkg)
    fun getShizukuStatus(): Map  // Installé, running, permission
    fun requestShizukuPermission()
    fun applyShizukuGrant()
    fun restartService()
}
```

---

## 8. Système de Communication WebRTC

### 8.1 Architecture WebRTC

```
┌──────────┐          ┌──────────┐          ┌──────────┐          ┌──────────┐
│  Caller  │          │ Supabase │          │  Callee  │          │  STUN/   │
│  Device  │          │ Realtime │          │  Device  │          │  TURN    │
└────┬─────┘          └────┬─────┘          └────┬─────┘          └────┬─────┘
     │                     │                     │                     │
     │─── create_call ────▶│                     │                     │
     │                     │─── notify ────────▶│                     │
     │◀── call data ───────┤                     │                     │
     │                     │                     │─── join_call ─────▶│
     │─── offer SDP ──────▶│                     │                     │
     │                     │─── offer SDP ─────▶│                     │
     │                     │                     │─── answer SDP ────▶│
     │◀── answer SDP ──────┤◀── answer SDP ──────┤                     │
     │                     │                     │                     │
     │─── ICE cand. ──────▶│                     │                     │
     │◀── ICE cand. ───────┤◀── ICE cand. ───────┤                     │
     │                     │                     │                     │
     │══════════════════════════════════════════════════════════════════▶
     │                  WebRTC P2P (SRTP/SCTP)                       │
     │◀══════════════════════════════════════════════════════════════════
     │                     │                     │                     │
     │─── update_call ────▶│                     │                     │
     │                     │─── notify ────────▶│                     │
```

### 8.2 Types d'Appels

| Type | Table | Max Participants | Cas d'Usage |
|------|-------|-----------------|-------------|
| **P2P Call** | `calls` | 2 | Discussion privée entre deux joueurs |
| **Team Call** | `team_calls` + `team_call_participants` | 50 | Communication d'équipe |
| **Squad Call** | `squad_calls` + `squad_call_participants` | 5 | Communication d'escouade |

### 8.3 Flux WebRTC Détaillé

```
1. Caller initie l'appel
   ├── Crée RTCPeerConnection
   ├── Crée offer (SDP)
   ├── Insert dans Supabase (calls table avec offer_sdp)
   └── Realtime notifie callee

2. Callee reçoit la notification
   ├── Crée RTCPeerConnection
   ├── setRemoteDescription(offer)
   ├── Crée answer (SDP)
   ├── Update Supabase (answer_sdp)
   └── Crée appel entrant (ringing)

3. Caller reçoit l'answer
   └── setRemoteDescription(answer)

4. Échange ICE
   ├── Les deux parties collectent ICE candidates
   ├── Insèrent dans call_ice_candidates (Realtime)
   └── addIceCandidate() à la réception

5. Connexion P2P établie
   ├── MediaStream audio/video
   └── Call status → 'ongoing'

6. Fin d'appel
   ├── Fermeture RTCPeerConnection
   ├── Update status → 'ended' / 'missed'
   └── Nettoyage ICE candidates
```

### 8.4 Service d'Appel Flutter (call_service.dart — 786 lignes)

```dart
// Méthodes principales :
class CallService {
  // P2P Calls
  Future<Map<String, dynamic>> createCall(String calleeId, String callType);
  Future<void> acceptCall(String callId, String answerSdp);
  Future<void> endCall(String callId);
  
  // Team Calls
  Future<Map<String, dynamic>> createTeamCall(String teamId, String callType);
  Stream<List<Map<String, dynamic>>> subscribeToTeamCallParticipants(String callId);
  Future<void> joinTeamCall(String callId);
  Future<void> leaveTeamCall(String callId);
  
  // Squad Calls
  Future<Map<String, dynamic>> createSquadCall(String squadId, String callType);
  Future<void> joinSquadCall(String callId);
  Future<void> leaveSquadCall(String callId);
  
  // ICE Candidates
  Future<void> sendIceCandidate(String callId, Map<String, dynamic> candidate);
  Stream<Map<String, dynamic>> subscribeToIceCandidates(String callId);
  
  // Realtime Subscriptions
  Stream<Map<String, dynamic>> subscribeToCallUpdates(String callId);
  RealtimeChannel subscribeToIncomingCalls(String userId);
}
```

---

## 9. Gamification & XP

### 9.1 Système de Progression

```
user_progress
├── profile_id  UUID PK → profiles(id) ON DELETE CASCADE
├── total_xp    INTEGER DEFAULT 0
├── level       INTEGER DEFAULT 1
├── badges      JSONB DEFAULT '[]'
├── quests      JSONB DEFAULT '{}'
├── created_at  TIMESTAMPTZ DEFAULT now()
└── updated_at  TIMESTAMPTZ DEFAULT now()
```

### 9.2 Types de Quêtes

| Type | Fréquence | Exemples |
|------|-----------|----------|
| **Daily** | Quotidienne | "Joue 3 matchs", "Envoie 5 messages" |
| **Weekly** | Hebdomadaire | "Gagne 10 matchs", "Fais 3 appels" |
| **Special** | Ponctuelle | "Crée ton équipe", "Atteins niveau 10" |
| **Achievement** | Permanent | "100 matchs joués", "50 amis" |

### 9.3 Récompenses

- **XP** → Points d'expérience cumulables
- **Niveaux** → Débloqués tous les X points d'XP
- **Badges** → Badges spéciaux dans le profil

---

## 10. Intelligence Artificielle & Modération

### 10.1 Détection de Toxicité

```dart
// ai_gateway_service.dart
class AiGatewayService {
  Future<double?> analyzeToxicity(String text) async {
    // Appel à Hugging Face Inference API
    // Modèle: toxic-bert ou équivalent
    // Retourne score de toxicité (0.0 - 1.0)
  }
  
  Future<List<Map<String, dynamic>>> recommendTeammates({
    required String gameType,
    required String region,
    String? role,
  }) async {
    // Recommandation IA de coéquipiers
    // Basée sur scoring heuristique + ML
  }
}
```

### 10.2 Scoring Matchmaking

```dart
// matching_service.dart
class MatchingService {
  Future<List<Map<String, dynamic>>> findMatches({
    required String gameType,
    required String region,
    String? role,
    String? availability,
    int? minLevel,
  }) async {
    // Algorithme de scoring :
    // - Même jeu : +30 points
    // - Même région : +20 points
    // - Rôle complémentaire : +15 points
    // - Disponibilité compatible : +10 points
    // - Niveau similaire (±200 MMR) : +15 points
    // - Réputation positive : +10 points
    // Score max : 100 points
  }
}
```

---

## 11. Notifications Push

### 11.1 Architecture Notifications

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐
│ Supabase DB │────▶│ PostgreSQL   │────▶│ Edge Function│────▶│ Firebase    │
│ Trigger     │     │ NOTIFY       │     │ (Deno)       │     │ FCM v1      │
└─────────────┘     └──────────────┘     └──────────────┘     └─────────────┘
                                                                    │
                                                                    ▼
                                                              ┌─────────────┐
                                                              │  Appareil   │
                                                              │  Utilisateur│
                                                              └─────────────┘
```

### 11.2 Types de Notifications

| Type | Déclencheur | Contenu |
|------|------------|---------|
| `message` | Nouveau message dans un canal | "Nouveau message de [pseudo]" |
| `call` | Appel entrant | "Appel de [pseudo]" |
| `missed_call` | Appel non répondu | "Appel manqué de [pseudo]" |
| `invitation` | Invitation équipe | "[pseudo] t'invite dans [équipe]" |
| `post_like` | Like publication | "[pseudo] a aimé ta publication" |
| `post_comment` | Commentaire | "[pseudo] a commenté ta publication" |
| `comment_like` | Like commentaire | "[pseudo] a aimé ton commentaire" |
| `team_call` | Appel d'équipe | "Appel d'équipe dans [équipe]" |

### 11.3 Fonction Deno (Edge Function)

```typescript
// Fonction : send-push-notification
// Reçoit : type, title, body, actor_id, target_id, metadata
// Comportement :
// 1. Récupère le FCM token depuis devices table
// 2. Construit le payload FCM v1
// 3. Envoie via Firebase Cloud Messaging
// 4. Gère les tokens expirés
// 5. Logs dans notifications table
```

---

## 12. Captures d'Écran

### 12.1 Interface Sociale

**Écran d'Accueil :**
![Home Screen](screenshots/social/hompe%20screen.jpeg)
*Dashboard principal avec accès rapide au matchmaking, aux équipes et aux appels*

**Matchmaking :**
![Matchmaking](screenshots/social/matchmaking%20screen%20.jpeg)
*Recherche de coéquipiers avec filtres et score*

**Mode Sombre :**
![Dark Mode](screenshots/social/mode%20sombre.jpeg)
*Thème sombre Material 3*

**Mode Clair :**
![Light Mode](screenshots/social/mode%20clair.jpeg)
*Thème clair Material 3*

### 12.2 Profil Utilisateur

**Vue Principale :**
![Profile 1](screenshots/social/profile%20screen%201.jpeg)
*Carte de profil avec avatar, pseudo, XP, niveau*

**Statistiques :**
![Profile 2](screenshots/social/profile%20screen%202.jpeg)
*Statistiques détaillées et jeux favoris*

**Amis :**
![Profile 3](screenshots/social/profile%20screen%203.jpeg)
*Liste d'amis et réputation*

**Paramètres :**
![Profile 4](screenshots/social/profile%20screen%204.jpeg)
*Configuration du compte*

### 12.3 Communication

**Chat d'Équipe :**
![Team Chat](screenshots/social/teammates%20chat.jpeg)
*Messagerie temps réel avec médias*

**Notification Barre :**
![Bar Notification](screenshots/social/bar%20phone%20notification.jpeg)
*Notification système pour appel entrant*

**Notification In-App :**
![In-App Notification](screenshots/social/in%20app%20notification.jpeg)
*Notification dans l'application*

### 12.4 Fil d'Actualités

**Fil Public :**
![Feed Public](screenshots/android_tweaker/fyp_prodix_public.jpeg)
*Publications publiques avec likes et commentaires*

**Fil Amis :**
![Feed Amis](screenshots/android_tweaker/fyp_prodix_amis.jpeg)
*Publications visible par les amis uniquement*

### 12.5 Android Performance Enhancer

**Interface Principale — Éteint :**
![Tweaker Off](screenshots/android_tweaker/interface_android_tweaker_togllebuttoonoff1.jpeg)
*Enhancer désactivé*

**Interface — Mode Gaming :**
![Tweaker Gaming](screenshots/android_tweaker/interface_android_tweaker_togllebuttoonOn_et_gaming_mode_on.jpeg)
*Mode Gaming activé avec tous les modules*

**Interface — Éteint (vue alternative) :**
![Tweaker Off 2](screenshots/android_tweaker/interface_android_tweaker_togllebuttoonoff2.jpeg)
*Vue alternative de l'enhancer éteint*

**Mode Clair :**
![Tweaker Light](screenshots/android_tweaker/interfacce_android_tweaker_4_(mode_clair)_apres_application_mode_clair.jpeg)
*Enhancer en thème clair*

### 12.6 Modules d'Optimisation

**Optimisation Éteinte 1 :**
![Optimization Off 1](screenshots/android_tweaker/optimization_screen_tweaks_off1.jpeg)
*Écran d'optimisation — tous les modules désactivés*

**Optimisation Éteinte 2 :**
![Optimization Off 2](screenshots/android_tweaker/optimization_screen_tweaks_off2.jpeg)
*Vue alternative des modules désactivés*

**État des Modules :**
![Optimization Status](screenshots/android_tweaker/optimization_screen_tweaks_off3_etat_des_modules.jpeg)
*Résumé de l'état des modules d'optimisation*

**Optimisation Active :**
![Optimization On](screenshots/android_tweaker/optimization_screen_tweaks_on1_et_etat_des_modules.jpeg)
*Modules activés avec résumé d'exécution*

### 12.7 Mode par Application

**Liste des Applications :**
![Per App 1](screenshots/android_tweaker/mode_par_application1.jpeg)
*Liste des applications installées avec recherche et filtres*

**Sélection de Mode :**
![Per App 2](screenshots/android_tweaker/mode_par_application_2.jpeg)
*Dialog de sélection de mode pour une application*

### 12.8 Paramètres

**Paramètres — Mode Sombre :**
![Settings Dark](screenshots/android_tweaker/parametre_android_tweaker_1(mode_sombre).jpeg)
*Paramètres de l'enhancer en mode sombre*

**Paramètres — Sombre (suite) :**
![Settings Dark 2](screenshots/android_tweaker/parametre_android_tweaker_2(mode_sombre).jpeg)
*Suite des paramètres en mode sombre*

**Paramètres — Mode Clair :**
![Settings Light](screenshots/android_tweaker/parametre_android_tweaker_2(mode_clair).jpeg)
*Paramètres de l'enhancer en mode clair*

### 12.9 Permissions

**Autorisation Shizuku :**
![Shizuku Grant](screenshots/android_tweaker/accorder_authorisation_shizuku_pou_utiliser_android_tweaker.jpeg)
*Demande d'autorisation Shizuku pour exécution non-root*

**Accès Root — Étape 1 :**
![Root 1](screenshots/android_tweaker/accees_root_after_first_click_on_android_tweaker1.jpeg)
*Premier clic sur l'enhancer → demande root*

**Accès Root — Étape 2 :**
![Root 2](screenshots/android_tweaker/accees_root_after_first_click_on_android_tweaker2.jpeg)
*Confirmation de l'accès root via Superuser*

---

## 13. Fonctionnalités Détaillées

### 13.1 Authentification

- **Mécanisme** : Supabase Auth (email/password)
- **Gestion de session** : JWT avec refresh automatique
- **Flux** : Splash → Vérification session → Login ou Main
- **Stockage** : Token dans SharedPreferences

### 13.2 Profil et Configuration

- **Création** : Écran d'onboarding après première connexion
- **Champs** : Pseudo, avatar, bio, date naissance, pays, langue
- **Gaming** : Type de jeu préféré, rôle, région, disponibilité
- **Social** : Liens Instagram, Facebook, GitHub
- **Métriques** : XP, niveau, MMR, réputation

### 13.3 Matchmaking

- **Algorithme** : Scoring heuristique (jeu, région, rôle, niveau, réputation)
- **Filtres** : Par jeu, type, région, disponibilité
- **Résultats** : Profils des joueurs compatibles avec score
- **Actions** : Inviter, voir profil, envoyer message

### 13.4 Équipes et Escouades

- **Création** : Équipe (jusqu'à 50 membres) ou escouade (jusqu'à 5)
- **Hiérarchie** : Rôles (admin, modérateur, membre)
- **Canaux** : Canaux de discussion textuels
- **Appels** : Appels d'équipe/escouade via WebRTC

### 13.5 Messagerie

- **Types** : Messages directs et par canal
- **Médias** : Images, audio, vidéo, fichiers
- **Temps réel** : Via Supabase Realtime
- **Notifications** : Push FCM pour nouveaux messages

### 13.6 Appels Audio/Vidéo

- **P2P** : Appel direct entre deux utilisateurs
- **Équipe** : Appel multiparticipant (jusqu'à 50)
- **WebRTC** : SDP, ICE, STUN/TURN
- **UI** : Interface d'appel avec mute, haut-parleur, vidéo

### 13.7 Fil d'Actualités

- **Posts** : Texte + média (image)
- **Visibilité** : Public ou amis uniquement
- **Interactions** : Likes, commentaires
- **Notifications** : Push pour likes et commentaires

### 13.8 Réputation

- **Critères** : Skill (1-5), Communication (1-5), Conduite (1-5)
- **Moyenne** : Score global affiché sur le profil
- **Unicité** : Un seul review par paire d'utilisateurs

### 13.9 Android Enhancer

- **Service** : ON/OFF toggle avec auto-enable
- **Modes** : Auto, Éco, Équilibré, Perf, Gaming
- **Modules** : 8 modules d'optimisation indépendants
- **Par App** : Mode personnalisé par application
- **Root** : Auto-détection et exécution native
- **Non-Root** : ADB WRITE_SECURE_SETTINGS ou Shizuku
- **Démarrage** : Au boot (optionnel)
- **Touch Boost** : Accélération tactile

### 13.10 Thèmes

- **Système** : Suit le thème système
- **Clair** : Thème clair Material 3
- **Sombre** : Thème sombre Material 3
- **Pure Black** : Mode noir AMOLED
- **Couleurs dynamiques** : Material You (Android 12+)

### 13.11 Gamification

- **XP** : Points d'expérience cumulables
- **Niveaux** : Débloqués tous les X points
- **Badges** : Badges spéciaux
- **Quêtes** : Quotodiennes, hebdomadaires, spéciales

---

## 14. API & Endpoints

### 14.1 Méthodes MethodChannel (Flutter ↔ Android)

| Méthode | Paramètres | Retour | Description |
|---------|-----------|--------|-------------|
| `getStatus` | — | `Map` | État root, service, mode, ADB |
| `setEnabled` | `bool` | — | Activer/désactiver le service |
| `setMode` | `int` | — | Changer le mode de performance |
| `setTouchBoost` | `bool` | — | Activer touch boost |
| `setStartOnBoot` | `bool` | — | Démarrage au boot |
| `getInstalledApps` | — | `List` | Apps installées |
| `getAppModes` | — | `Map` | Overrides per-app |
| `setAppMode` | `String, int` | — | Définir mode pour une app |
| `removeAppMode` | `String` | — | Supprimer override |
| `getShizukuStatus` | — | `Map` | État Shizuku |
| `requestShizukuPermission` | — | — | Demander permission |
| `applyShizukuGrant` | — | — | Appliquer grant ADB |
| `restartService` | — | — | Redémarrer le service |

### 14.2 Services Supabase (Domain Layer)

```dart
// ProfileService
Future<Map<String, dynamic>?> getProfile(String id);
Future<Map<String, dynamic>> updateProfile(String id, Map<String, dynamic> data);
Future<String?> uploadAvatar(String profileId, XFile file);
Future<void> addFavoriteGame(String profileId, int gameId);
Future<void> removeFavoriteGame(String profileId, int gameId);
Future<List<Map<String, dynamic>>> getFavoriteGames(String profileId);

// ChatService
Future<List<Map<String, dynamic>>> getMessages(String channelId, {int limit});
Future<Map<String, dynamic>> sendMessage(String channelId, String content, {String? receiverId});
Future<Map<String, dynamic>> sendMediaMessage(String channelId, XFile file, {String? receiverId});
Future<int> getUnreadCount(String channelId, String profileId);
Stream<Map<String, dynamic>> subscribeToChannel(String channelId);

// SocialService
Future<List<Map<String, dynamic>>> searchPlayers(String query);
Future<List<Map<String, dynamic>>> getFriends(String profileId);
Future<Map<String, dynamic>> sendFriendRequest(String fromId, String toId);
Future<Map<String, dynamic>> createTeam(String name, String createdBy);
Future<List<Map<String, dynamic>>> getTeamMembers(String teamId);
Future<Map<String, dynamic>> createSquad(String name, String createdBy);

// PostService
Future<Map<String, dynamic>> createPost(String profileId, String content, {XFile? media, String visibility});
Future<List<Map<String, dynamic>>> getFeed({String? visibility, int limit});
Future<void> likePost(String postId, String profileId);
Future<void> addComment(String postId, String profileId, String content);
Future<void> deletePost(String postId);

// CallService
Future<Map<String, dynamic>> createCall(String callerId, String calleeId, String callType);
Future<void> updateCallSdp(String callId, String sdp, String type);
Future<void> sendIceCandidate(String callId, String profileId, Map<String, dynamic> candidate);
Stream<Map<String, dynamic>> subscribeToIncomingCalls(String userId);

// MatchingService
Future<List<Map<String, dynamic>>> findMatches(Map<String, dynamic> filters);
Future<List<Map<String, dynamic>>> getRecommendedTeammates(String profileId);
Future<Map<String, dynamic>> submitReview(String reviewerId, String targetId, Map<String, int> ratings);
```

---

## 15. Configuration & Déploiement

### 15.1 Variables d'Environnement

```bash
# Définies via --dart-define dans la commande de build
SUPABASE_URL=https://edlxuaoldmdabteiqjfa.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
BACKEND_API_URL=          # Optionnel
AI_GATEWAY_URL=           # Optionnel
HUGGING_FACE_TOKEN=       # Optionnel
```

### 15.2 Build Release

```bash
# Build APK Release
flutter build apk --release

# Avec variables d'environnement personnalisées
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# Output
build/app/outputs/flutter-apk/app-release.apk
```

### 15.3 Installation

```bash
# ADB install
adb install prodix-v1.0.0.apk

# Grant permissions non-root
adb shell pm grant com.example.prodix android.permission.WRITE_SECURE_SETTINGS
```

---

## 16. Diagrammes & Flux

### 16.1 Flux d'Authentification

```
┌──────────┐     ┌──────────┐     ┌──────────────┐     ┌──────────┐     ┌──────────┐
│  App     │     │  Splash  │     │ Auth Cubit   │     │ Supabase │     │  Main    │
│  Launch  │     │  Screen  │     │              │     │  Auth    │     │  Screen  │
└────┬─────┘     └────┬─────┘     └──────┬───────┘     └────┬─────┘     └────┬─────┘
     │                 │                  │                  │                │
     │── launch ──────▶│                  │                  │                │
     │                 │── init ────────▶│                  │                │
     │                 │                  │── session ─────▶│                │
     │                 │                  │◀─ token/null ────┤                │
     │                 │                  │                  │                │
     │                 │◀── has session ──┤                  │                │
     │                 │                  │                  │                │
     │                 │─── Main ────────────────────────────────────────────▶│
     │                 │                  │                  │                │
     │◀── OR ──────────┤                  │                  │                │
     │                 │                  │                  │                │
     │                 │◀── no session ───┤                  │                │
     │                 │                  │                  │                │
     │                 │─── Login ───────▶│                  │                │
     │                 │                  │── signIn ──────▶│                │
     │                 │                  │◀─ session ──────┤                │
     │                 │◀── success ──────┤                  │                │
     │                 │                  │                  │                │
     │                 │─── Profile? ──────────────────────▶│                │
     │                 │◀── Setup/Main ──────────────────────┤                │
```

### 16.2 Flux de Matchmaking

```
┌───────────┐     ┌─────────────┐     ┌────────────┐     ┌──────────────┐
│   User    │     │  Matching   │     │  Supabase  │     │  Teammate    │
│           │     │  Service    │     │   Query    │     │  Profile     │
└─────┬─────┘     └──────┬──────┘     └─────┬──────┘     └──────┬───────┘
      │                  │                   │                   │
      │── filtres ──────▶│                   │                   │
      │                  │── query DB ──────▶│                   │
      │                  │◀── results ───────┤                   │
      │                  │                   │                   │
      │                  │── scoring ───────▶│                   │
      │                  │   heuristique     │                   │
      │                  │◀── ranked ────────┤                   │
      │                  │                   │                   │
      │◀── results ──────┤                   │                   │
      │                  │                   │                   │
      │── select ───────▶│                   │                   │
      │                  │── get profile ───▶│                   │
      │                  │◀── profile ───────┤                   │
      │                  │                   │                   │
      │── invite ───────▶│── create invite ─▶│── notify ──────▶│
      │                  │                   │                   │
      │◀── pending ──────┤                   │                   │
```

### 16.3 Flux d'Appel WebRTC

```
┌──────────┐     ┌──────────────┐     ┌──────────┐     ┌────────────┐
│  Caller  │     │ CallService  │     │  Callee  │     │  STUN/TURN │
│  Device  │     │  (Flutter)   │     │  Device  │     │   Server   │
└────┬─────┘     └──────┬───────┘     └────┬─────┘     └─────┬──────┘
     │                  │                  │                  │
     │── tap call ─────▶│                  │                  │
     │                  │── create RTCPC ──▶                  │
     │                  │── create offer ────────────────────▶│
     │                  │◀── offer SDP ───────────────────────┤
     │                  │                  │                  │
     │                  │── insert DB ────▶│                  │
     │                  │   (calls table)  │                  │
     │                  │                  │                  │
     │                  │◀── notify ───────┤                  │
     │                  │   (Realtime)     │                  │
     │                  │                  │                  │
     │                  │                  │── join call ────▶│
     │                  │                  │── set remote ───▶│
     │                  │                  │── create answer ─▶
     │                  │                  │◀── answer SDP ───┤
     │                  │                  │                  │
     │                  │◀── answer SDP ───┤                  │
     │                  │                  │                  │
     │                  │── set remote ───▶│                  │
     │                  │                  │                  │
     │══ ICE exchange ══╪══════════════════╪══════════════════╡
     │                  │                  │                  │
     │══════ WebRTC P2P (SRTP/SCTP) ══════════════════════════▶
     │                  │                  │                  │
     │                  │── end call ─────▶│                  │
     │                  │   (update DB)    │                  │
```

### 16.4 Architecture des États BLoC/Cubit

```
                    ┌──────────────────────┐
                    │    AuthCubit         │
                    ├──────────────────────┤
                    │ States: loading,     │
                    │ authenticated,       │
                    │ unauthenticated,     │
                    │ error                │
                    └──────────┬───────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
    ┌───────────────┐  ┌──────────────┐  ┌──────────────┐
    │ ProfileCubit  │  │ ThemeCubit   │  │ ProgressCubit│
    ├───────────────┤  ├──────────────┤  ├──────────────┤
    │ - Profile     │  │ - ThemeMode  │  │ - XP         │
    │ - Settings    │  │ - Dark/Light │  │ - Level      │
    │ - Fav Games   │  │ - Pure Black │  │ - Badges     │
    └───────────────┘  └──────────────┘  └──────────────┘
```

### 16.5 Flux de Données Android Enhancer

```
┌──────────────┐     ┌──────────────┐     ┌───────────────┐
│  Flutter UI  │     │ MethodChannel│     │ EnhancerBridge│
│  (Dart)      │     │              │     │  (Kotlin)     │
└──────┬───────┘     └──────┬───────┘     └───────┬───────┘
       │                    │                      │
       │── toggle ON ──────▶│                      │
       │                    │── setEnabled(true) ──▶│
       │                    │                      │
       │                    │                      ├──▶ AppPreferences
       │                    │                      │   (save state)
       │                    │                      │
       │                    │                      ├──▶ Root check
       │                    │                      │   ├── Root? → RootIpc
       │                    │                      │   ├── ADB? → ProcessBuilder
       │                    │                      │   └── Shizuku? → Shizuku
       │                    │                      │
       │                    │                      ├──▶ JniBridge.sync()
       │                    │                      │   (native lib)
       │                    │                      │
       │                    │                      ├──▶ OptimizationExecutor
       │                    │                      │   ├── FramePacing
       │                    │                      │   ├── GoodPing
       │                    │                      │   ├── PerfExt
       │                    │                      │   ├── RuntimeControl
       │                    │                      │   ├── GamePulse
       │                    │                      │   ├── GpuBoost
       │                    │                      │   ├── AudioTuning
       │                    │                      │   └── HyperPerformance
       │                    │                      │
       │                    │◀── result ───────────┤
       │◀── result ────────┤                      │
       │                    │                      │
       │── UI update ──────▶                      │
```

---

## 17. Tests & Qualité

### 17.1 Tests Unitaires Android

```kotlin
// OptimizationExecutorTest.kt
class OptimizationExecutorTest {
    @Test fun `executeModule returns success`() { ... }
    @Test fun `executeAll runs all modules`() { ... }
    @Test fun `script for module not null`() { ... }
}

// PreferencesSnapshotTest.kt
class PreferencesSnapshotTest {
    @Test fun `serialization roundtrip`() { ... }
    @Test fun `default values correct`() { ... }
}

// AndroidEnhancerModeTest.kt
class AndroidEnhancerModeTest {
    @Test fun `fromValue maps correctly`() { ... }
    @Test fun `values contain all modes`() { ... }
}

// SettingsStateTest.kt
class SettingsStateTest {
    @Test fun `default state`() { ... }
}

// OptimizationStateTest.kt
class OptimizationStateTest {
    @Test fun `default state`() { ... }
}

// RootIpcTest.kt
class RootIpcTest {
    @Test fun `command execution`() { ... }
}
```

### 17.2 Bonnes Pratiques

- **State Management** : BLoC/Cubit avec `equatable` pour éviter les rebuilds inutiles
- **Clean Architecture** : Séparation UI/Domain/Data
- **Injection de dépendances** : `get_it` (Flutter) + Hilt (Android)
- **Gestion d'erreurs** : Try/catch avec retours null-safe
- **Performance** :
  - `compute()` pour les opérations lourdes (JSON parsing)
  - Lazy loading des tabs
  - Pas de `BackdropFilter` (coûteux en GPU)
  - Pas de `runBlocking` sur le thread principal
- **Sécurité** : RLS Supabase, JWT tokens, permissions Android

---

## Annexes

### Annexe A : Dépendances Complètes

```yaml
# Flutter (pubspec.yaml)
flutter_bloc: ^8.1.6
equatable: ^2.0.7
supabase_flutter: ^2.8.0
http: ^1.2.2
intl: ^0.20.1
image_picker: ^1.2.0
get_it: ^9.2.1
shared_preferences: ^2.5.3
geolocator: 13.0.1
google_fonts: ^8.1.0
share_plus: ^10.1.4
url_launcher: ^6.3.2
flutter_webrtc: ^1.4.1
file_picker: ^11.0.2
record: ^6.2.1
permission_handler: ^12.0.1
audioplayers: ^6.1.0
quest_gamification: ^0.1.0
workmanager: ^0.9.0
flutter_local_notifications: ^18.0.1
firebase_core: ^3.12.0
firebase_messaging: ^15.2.0
cupertino_icons: ^1.0.8

# Android Enhancer (build.gradle.kts)
androidx.compose:compose-bom:2024.12.01
androidx.navigation:navigation-compose:2.8.5
com.google.dagger:hilt-android:2.57
androidx.datastore:datastore-preferences:1.1.1
androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7
dev.rikka.shizuku:api:13.1.5
dev.rikka.shizuku:provider:13.1.5
org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0
```

### Annexe B : Configuration Android

```kotlin
// app/build.gradle
android {
    compileSdk = 35
    defaultConfig {
        minSdk = 24
        targetSdk = 35
    }
    signingConfigs {
        release {
            keyAlias = "upload"
            keyPassword = "..."
            storeFile = file("upload-keystore.jks")
            storePassword = "..."
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.release
        }
    }
}
```

### Annexe C : Permissions Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WRITE_SECURE_SETTINGS" />
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
```

---

<p align="center">
  <strong>PRODIX</strong> — Projet de Fin d'Études 2025/2026
  <br/>
  <em>Social Gaming Companion + Android Performance Enhancer</em>
  <br/>
  <br/>
  <img src="assets/prodix_logo.png" alt="Prodix Logo" width="120"/>
  <br/>
  <br/>
  Développé par <strong>Staili Saad</strong>
  <br/>
  <a href="https://github.com/StailiSaad/PRODIX">GitHub Repository</a>
</p>
