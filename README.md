<p align="center">
  <img src="assets/prodix_logo.png" alt="Prodix Logo" width="128" height="128"/>
</p>

<h1 align="center">🚀 PRODIX</h1>

<p align="center">
  <b>Game Together. Boost Performance. Stay Connected.</b>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-screenshots">Screenshots</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-adb-setup">ADB Setup</a> •
  <a href="#-architecture">Architecture</a>
</p>

<hr/>

## 📱 Overview

**Prodix** is an all-in-one mobile application for gamers — combining **social matchmaking**, **real-time chat & calls**, **AI-powered moderation**, and a powerful **Android performance enhancer** that optimizes your device for gaming.

> Built with Flutter • Supabase • Hugging Face AI • Android Native (Hilt / LibSu)

---

## ✨ Features

### 🎮 Social Gaming Platform
| Feature | Description |
|---------|-------------|
| **Matchmaking** | Find players by game, region, availability & skill level |
| **Real-time Chat** | Direct & group messaging with media sharing |
| **Voice/Video Calls** | P2P & team calls powered by WebRTC |
| **Teams & Squads** | Create teams, channels, and squad-based communication |
| **Activity Feed** | Posts, comments, likes, and social interactions |
| **Reputation System** | Rate teammates on skill, communication & conduct |
| **Push Notifications** | Firebase Cloud Messaging for calls & messages |

### ⚡ Android Performance Enhancer
| Module | Effect |
|--------|--------|
| **Frame Pacing** | Smooths display refresh & SurfaceFlinger phase offsets |
| **GoodPing** | DNS, TCP buffers & connectivity tuning for lower latency |
| **PerfExt** | GPU rendering, power mode & animation speed optimization |
| **Runtime Control** | Disables doze, app standby, thermal throttling |
| **GamePulse** | Game mode overlay & GPU driver optimization |
| **GPU Boost** | Skia/Vulkan rendering & hardware composition |
| **Audio Tuning** | Low-latency audio flinger optimization |
| **Hyper Performance** | Comprehensive CPU/GPU/memory/I/O tuning |

### 🤖 AI Integration (Hugging Face)
- **Toxicity Detection** — automatic moderation of chat messages
- **Teammate Recommendations** — AI-powered player suggestions

---

## 📸 Screenshots

> *Insert your screenshots here — recommended: PNG, 1080×2340*

| | | |
|:---:|:---:|:---:|
| **Splash / Auth** | **Dashboard** | **Matchmaking** |
| ![Splash](screenshots/splash.png) | ![Dashboard](screenshots/dashboard.png) | ![Matchmaking](screenshots/matching.png) |
| **Chat** | **Calls** | **Profile** |
| ![Chat](screenshots/chat.png) | ![Calls](screenshots/calls.png) | ![Profile](screenshots/profile.png) |
| **Performance Enhancer** | **Modules** | **Notifications** |
| ![Enhancer](screenshots/enhancer.png) | ![Modules](screenshots/modules.png) | ![Notifications](screenshots/notifications.png) |

---

## ⬇️ Installation

### Download APK

Grab the latest release from [GitHub Releases](https://github.com/YOUR_USERNAME/prodix/releases):

```
📦 app-release.apk (101.7 MB)
```

> **Requirements:** Android 7.0+ (API 24), 2 GB RAM minimum

### Install on Device

```bash
# 1. Enable Developer Options & USB Debugging on your phone
# 2. Connect via USB
# 3. Install the APK
adb install app-release.apk
```

---

## 🛠 ADB Setup

To use the **Performance Enhancer** modules on a **non-rooted** device, grant the `WRITE_SECURE_SETTINGS` permission:

```bash
adb shell pm grant com.example.prodix android.permission.WRITE_SECURE_SETTINGS
```

After running the command, press **"J'ai appliqué la commande"** inside the app.

> **Rooted users:** The app auto-detects root and uses LibSu for shell execution.

---

## 🏗 Architecture

```
Prodix
├── Flutter (Dart)
│   ├── lib/
│   │   ├── main.dart              # Entry point
│   │   ├── app_root.dart          # Bootstrap & Bloc providers
│   │   ├── core/
│   │   │   ├── config/            # AppConfig (Supabase, AI, env vars)
│   │   │   ├── services/          # Notifications, Push, Background, Calls
│   │   │   └── theme/             # Futuristic light/dark themes
│   │   ├── data/
│   │   │   └── services/          # SupabaseBackendService + domain services
│   │   ├── features/
│   │   │   ├── auth/              # AuthCubit, Login, Register, Splash
│   │   │   ├── profile/           # ProfileCubit, Setup, Edit
│   │   │   ├── dashboard/         # MainScreen, Home, DM Chat, Feed
│   │   │   ├── call/              # P2P & Team Calls (WebRTC)
│   │   │   ├── gamification/      # XP, Badges, Levels
│   │   │   ├── theme/             # ThemeCubit (Light/Dark/System)
│   │   │   └── posts/             # Social feed, comments, likes
│   │   └── shared/widgets/        # Reusable UI components
│   └── pubspec.yaml
│
├── Android Native (Kotlin)
│   ├── app/
│   │   ├── ProdixApplication.kt   # @HiltAndroidApp, Shell init
│   │   ├── MainActivity.kt        # FlutterActivity + MethodChannels
│   │   ├── BackgroundService.kt    # Foreground polling (30s)
│   │   ├── CallForegroundService.kt
│   │   ├── CallMessagingService.kt # FCM handler
│   │   ├── OverlayService.kt      # Floating overlay during calls
│   │   └── DeclineService.kt
│   └── androidenhancer/
│       ├── MainActivity.kt        # @AndroidEntryPoint (Compose UI)
│       ├── AppRepository.kt       # @Singleton — DataStore, RootIpc
│       ├── OptimizationExecutor.kt # Shell script runner (8 modules)
│       ├── RootService.kt         # AIDL IPC for root commands
│       └── BootService.kt         # Auto-start on boot
│
├── Supabase
│   ├── supabase_setup.sql         # Full schema + RLS policies
│   └── supabase_migrations/       # Incremental migrations
│
└── Assets
    ├── assets/data/games_db.json  # Game catalog
    └── assets/data/countries.json # Country list
```

### Data Flow

```
User Action → Flutter UI → Bloc/Cubit → SupabaseBackendService
                                              ├── Supabase Client (Auth, DB, Realtime, Storage)
                                              └── AiGatewayService → Hugging Face API

Performance Toggle → MethodChannel → Android Enhancer
                                          ├── Shell scripts (root/ADB)
                                          └── Native JNI → libandroidenhancer.so
```

---

## 🧰 Tech Stack

| Layer | Technology |
|-------|-----------|
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

## 📄 License

```
© 2026 Prodix. All rights reserved.
```

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/StailiSaad">StailiSaad</a>
  <br/>
  <sub>Built with opencode — the AI CLI for software engineering</sub>
</p>
