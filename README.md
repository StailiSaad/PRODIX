<p align="center">
  <img src="prodix2.png" alt="Prodix Logo" width="128" height="128"/>
</p>

<h1 align="center">Prodix</h1>

<p align="center">
  <strong>Game Together. Boost Performance. Stay Connected.</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#installation">Installation</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#license">License</a>
</p>

<hr/>

Prodix is a mobile application for gamers that combines **social matchmaking**, **real‑time chat and calls**, **AI‑powered moderation**, and an **Android performance enhancer** that optimises device settings for gaming.

---

## Features

### Social Gaming Platform

| Feature | Description |
|---------|-------------|
| **Matchmaking** | Find players by game, region, availability and skill level |
| **Real‑time Chat** | Direct and group messaging with media sharing |
| **Voice / Video Calls** | P2P and team calls powered by WebRTC |
| **Teams & Squads** | Create teams, channels and squad‑based communication |
| **Activity Feed** | Posts, comments, likes and social interactions |
| **Reputation System** | Rate teammates on skill, communication and conduct |
| **Push Notifications** | Firebase Cloud Messaging for calls and messages |
| **Gamification** | XP, badges and levelling system with quest progression |

### Android Performance Enhancer

| Module | Effect |
|--------|--------|
| **Frame Pacing** | Smooths display refresh and SurfaceFlinger phase offsets |
| **GoodPing** | DNS, TCP buffers and connectivity tuning for lower latency |
| **PerfExt** | GPU rendering, power mode and animation speed optimisation |
| **Runtime Control** | Disables doze, app standby and thermal throttling |
| **GamePulse** | Game mode overlay and GPU driver optimisation |
| **GPU Boost** | Skia / Vulkan rendering and hardware composition |
| **Audio Tuning** | Low‑latency audio flinger optimisation |
| **Hyper Performance** | Comprehensive CPU / GPU / memory / I / O tuning |

### AI Integration (Hugging Face)

- **Toxicity Detection** — automatic moderation of chat messages
- **Teammate Recommendations** — AI‑powered player suggestions

---

## Architecture

```
Prodix
├── Flutter (Dart)
│   ├── lib/main.dart                # Entry point
│   ├── lib/app_root.dart            # Bootstrap & Bloc providers
│   ├── lib/core/
│   │   ├── config/                  # AppConfig (Supabase, AI, env vars)
│   │   ├── services/                # Notifications, Push, Background, Calls
│   │   └── theme/                   # Futuristic light / dark themes
│   ├── lib/data/
│   │   └── services/                # SupabaseBackendService + domain services
│   ├── lib/features/
│   │   ├── auth/                    # AuthCubit, Login, Register, Splash
│   │   ├── profile/                 # ProfileCubit, Setup, Edit
│   │   ├── dashboard/               # MainScreen, Home, DM Chat, Feed
│   │   ├── call/                    # P2P & Team Calls (WebRTC)
│   │   ├── gamification/            # XP, Badges, Levels
│   │   ├── theme/                   # ThemeCubit (Light / Dark / System)
│   │   └── posts/                   # Social feed, comments, likes
│   └── lib/shared/widgets/          # Reusable UI components
│
├── Android Native (Kotlin)
│   ├── app/                         # Flutter host + MethodChannels
│   └── androidenhancer/             # Performance optimisation modules
│
├── Supabase
│   ├── supabase_setup.sql           # Full schema + RLS policies
│   └── supabase_migrations/         # Incremental migrations
│
└── Assets
    ├── assets/data/games_db.json    # Game catalogue
    └── assets/data/countries.json   # Country list
```

### Data Flow

```
User Action → Flutter UI → Bloc / Cubit → SupabaseBackendService
                                              ├── Supabase Client (Auth, DB, Realtime, Storage)
                                              └── AiGatewayService → Hugging Face API

Performance Toggle → MethodChannel → Android Enhancer
                                          ├── Shell scripts (root / ADB)
                                          └── Native JNI → libandroidenhancer.so
```

---

## Installation

### Download

Download the latest APK from [releases](releases/):

```
releases/prodix-v1.0.0.apk
```

**Requirements:** Android 7.0+ (API 24), 2 GB RAM minimum

### Install via ADB

```bash
adb install releases/prodix-v1.0.0.apk
```

### ADB Permissions

To use the Performance Enhancer modules on a **non‑rooted** device, grant the `WRITE_SECURE_SETTINGS` permission:

```bash
adb shell pm grant com.example.prodix android.permission.WRITE_SECURE_SETTINGS
```

After running the command, press **"J'ai appliqué la commande"** inside the app.

**Rooted users:** The app auto‑detects root and uses LibSu for shell execution.

### Build from Source

```bash
# Install dependencies
flutter pub get

# Build release APK
flutter build apk --release

# The APK will be at build/app/outputs/flutter-apk/app-release.apk
```

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter 3.41 • Dart 3.11 |
| **State Management** | flutter_bloc 8.1 • equatable |
| **Backend** | Supabase (PostgreSQL, Auth, Realtime, Storage) |
| **AI** | Hugging Face Inference API |
| **Push** | Firebase Cloud Messaging |
| **Calls** | flutter_webrtc • WebRTC |
| **DI (Android)** | Dagger Hilt 2.57 |
| **Root Shell** | LibSu 6.0 • HiddenApiBypass |
| **Background** | Workmanager • AlarmManager |
| **Local Storage** | SharedPreferences • DataStore |

---

## License

```
© 2026 Prodix. All rights reserved.
```

---

<p align="center">
  Made by <a href="https://github.com/StailiSaad">StailiSaad</a>
</p>
