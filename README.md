# Prodix - Mobile Matchmaking App

Application Flutter de matchmaking pour joueurs, connectee a Supabase avec option IA Hugging Face.

## Modules inclus (12 activites)

1. Authentification (signup/login/logout)
2. Gestion de profil
3. Matching de joueurs
4. Invitations
5. Chat realtime
6. Notifications
7. Analyse toxicite (IA Hugging Face)
8. Systeme de reputation
9. Catalogue de jeux
10. Sessions de jeu
11. Disponibilites
12. Dashboard KPI

## Prerequis

- Flutter SDK installe
- Projet Supabase
- (Optionnel) Token Hugging Face

## Configuration

1. Creer les tables et policies:
   - Ouvrir SQL Editor Supabase
   - Executer `supabase/schema.sql`

2. Lancer l'application avec variables d'environnement:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY --dart-define=HUGGING_FACE_TOKEN=hf_xxx
```

Sans variables, l'app fonctionne en mode demo local.

## Tester sur telephone Android

1. Activer `Developer options` + `USB debugging` sur le telephone
2. Connecter le telephone en USB
3. Verifier qu'il est detecte:
   - `flutter devices`
4. Lancer l'app:
   - `flutter run`

## Architecture

- `lib/main.dart`: app principale + etats Bloc + services backend/IA
- `supabase/schema.sql`: schema PostgreSQL + RLS

Une separation plus fine (clean architecture complete par dossier) est possible dans l'etape suivante.
# prodix

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
