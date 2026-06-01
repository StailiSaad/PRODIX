# PROMPT DE PRÉSENTATION — 30 SLIDES

## PRODIX : Application Mobile de Mise en Relation pour Joueurs

---

### INFORMATIONS GÉNÉRALES

**Auteur du projet :** Staili Saad — Développeur full-stack (Flutter, Kotlin, Supabase, Hugging Face)
**Encadré par :** Mr El Mernissi Abderrazzak & Mr Edebich Ayoub
**Type de document :** Présentation exécutive et technique — 30 slides
**Support de génération :** Replit / Gamma / PowerPoint / Google Slides
**Langue :** Français
**Style visuel :** Minimaliste, moderne, gaming/Esports (noir profond #0F172A, bleu #2563EB, violet #7C3AED, vert #22C55E, blanc #F3FAFC)
**Typographie :** Titres → Poppins / Montserrat ; Texte → Inter / Roboto

---

### CONSIGNE GÉNÉRALE

Générer une présentation de **30 slides** structurée en **7 parties**. Chaque slide doit être visuellement claire, avec un titre en haut, un contenu concis (puces ou schémas), et une transition logique vers la slide suivante. Utiliser la charte graphique fournie. La présentation doit raconter une histoire : de la frustration du joueur solitaire à la solution technique complète.

---

## PARTIE 1 — INTRODUCTION & CONTEXTE (Slides 1–5)

### Slide 1 — Page de garde
- Titre : **PRODIX**
- Sous-titre : Le bon joueur, au bon moment
- Présenté par : **Staili Saad**
- Encadré par : Mr El Mernissi Abderrazzak & Mr Edebich Ayoub
- Logo : PRODIX – GAMING SOCIAL NETWORK
- Date : Année universitaire en cours

### Slide 2 — Problématique
- **Titre :** Pourquoi une application dédiée aux joueurs ?
- Constat : Jouer seul ou avec des inconnus non fiables = frustration quotidienne
- Problèmes identifiés (sondage) :
  - Manque de communication (45 %)
  - Niveau de jeu incompatible (35 %)
  - Toxicité dans les interactions (40 %)
  - Disponibilités non alignées (50 %)
  - Barrière linguistique (25 %)

### Slide 3 — Résultats du questionnaire
- **Titre :** Ce que les joueurs nous ont dit
- 70 % des répondants ont du mal à trouver des équipiers fiables
- 65 % utilisent déjà Discord/forums sans satisfaction
- 78 % sont intéressés par une application dédiée
- Budget mensuel acceptable : 3–5 € (majorité)

### Slide 4 — Solution proposée
- **Titre :** PRODIX — Le réseau social du gaming compétitif
- Une application unique qui connecte les joueurs compatibles
- Profil détaillé (jeux, niveau, région, langue, disponibilités)
- Matching automatique + invitations directes
- Chat, appels, équipes, squads, posts — tout-en-un

### Slide 5 — Cible et vision
- **Titre :** Pour qui ? Pour quoi ?
- Cible : Joueurs casual et compétitifs, teams Esports
- Vision : Devenir la référence de la mise en relation gaming
- Slogans :
  - « Le bon joueur, au bon moment »
  - « Élever votre game, jouer mieux »

---

## PARTIE 2 — ÉTUDE DE MARCHÉ & ANALYSE CONCURRENTIELLE (Slides 6–9)

### Slide 6 — Analyse des besoins (détaillée)
- **Titre :** Les vrais besoins des joueurs
- Critères de choix d'une équipe (classés par priorité) :
  1. Niveau/classement
  2. Disponibilité horaire
  3. Région géographique (latence/ping)
  4. Langue de communication
  5. Esprit d'équipe
- 82 % acceptent de remplir un profil détaillé pour un meilleur matching

### Slide 7 — Analyse concurrentielle
- **Titre :** Pourquoi pas Discord, Steam ou les forums ?
- Discord : matching inexistant, bruit permanent, pas de profils structurés
- Forums : obsolètes, lents, aucune modération
- Apps généralistes : pas adaptées au gaming
- **Notre avantage :** Solution 100 % dédiée, profil enrichi, matching algorithmique

### Slide 8 — Éléments différenciants
- **Titre :** Ce qui rend PRODIX unique
- Critères classés par importance (1 = prioritaire) :
  - **Simplicité d'utilisation** (1)
  - **Sécurité et modération IA** (2)
  - **Système de réputation** (2)
  - **Filtres avancés** (3)
- Proposition de valeur unique : tout est intégré, pas de multi-tasking entre apps

### Slide 9 — Opportunité de marché
- **Titre :** Un marché en pleine expansion
- Industrie Esports : croissance à +20 % par an
- 3 milliards de joueurs dans le monde
- Aucun leader clair sur le marché de la mise en relation gaming
- PRODIX positionné comme le « LinkedIn du gaming »

---

## PARTIE 3 — ARCHITECTURE TECHNIQUE & DATA FLOW (Slides 10–16)

### Slide 10 — Architecture générale
- **Titre :** Vue d'ensemble de l'application
- Schéma montrant :
  ```
  Flutter App (frontend mobile)
    ├── Supabase Cloud (auth, DB, realtime, storage)
    ├── Hugging Face API (modération IA — optionnel)
    ├── Firebase Cloud Messaging (notifications push)
    └── Android Native (Kotlin) — performance enhancer
  ```

### Slide 11 — Stack technologique
- **Titre :** Technologies utilisées
- **Frontend :** Flutter / Dart — multiplateforme, performances natives
- **Backend :** Supabase (PostgreSQL + Realtime + Auth + Storage)
- **IA :** Hugging Face Inference API (modération de toxicité)
- **Notifications :** Firebase Cloud Messaging
- **Android Natif :** Kotlin (service d'appels, fond d'écran, optimiseur)
- **Paiements :** Stripe / Google Play Billing

### Slide 12 — Les deux flux de données
- **Titre :** Comprendre l'indépendance des services
- Schéma de la slide 10 détaillé avec deux chemins distincts :
  - **Flux critique (Supabase) :** Auth → DB → Realtime → Messages → Appels → Posts
  - **Flux optionnel (Hugging Face) :** Vérification de toxicité avant envoi de message
- Message clé : **Les deux flux sont complètement indépendants**

### Slide 13 — Fonctionnement détaillé : Envoi d'un message
- **Titre :** Data Flow — Envoi d'un message chat
- Diagramme séquentiel :
  1. Utilisateur tape et envoie un message
  2. Appel optionnel à l'API Hugging Face (analyzeToxicity)
  2a. Si toxique → message bloqué, snackbar rouge
  2b. Si non toxique ou HF indisponible → on continue
  3. Appel Supabase → insertion dans la table `messages`
  4. Realtime Supabase → diffusion au destinataire
  5. Mise à jour XP (gamification)
  6. Notification push si destinataire hors ligne

### Slide 14 — Pourquoi l'app fonctionne sans Hugging Face
- **Titre :** Résilience et tolérance aux pannes
- Constat : Le backend Hugging Face peut être « endormi » (gratuit, mise en veille)
- **L'application continue de fonctionner parfaitement** car :
  - `AiGatewayService` a un `isEnabled` qui retourne `false` si vide
  - Tous les appels sont protégés par des `try/catch`
  - `recommendTeammates()` est défini mais jamais appelé
  - Aucune fonctionnalité critique ne dépend de l'IA
- **Le vrai backend, c'est Supabase**

### Slide 15 — Base de données Supabase
- **Titre :** Schéma relationnel
- Tables principales :
  - `users`, `profiles` — authentification et profils
  - `messages` — messages DMs, team, squad (avec Realtime)
  - `teams`, `team_members`, `squads`, `squad_members` — groupes
  - `calls`, `call_participants`, `ice_candidates` — appels VoIP
  - `posts`, `comments`, `likes` — fil d'actualité
  - `match_events`, `reputation_reviews` — matching et réputation
  - `notifications`, `devices` — notifications push
  - `user_progress` — gamification (XP, badges, niveaux)

### Slide 16 — Sécurité et modération IA
- **Titre :** Une modération intelligente et optionnelle
- Analyse de toxicité via Hugging Face (modèle NLP)
- Seuil configurable : score > 0.7 → message bloqué
- Timeout 3 secondes → fallback silencieux
- Désactivable via la configuration (variable d'environnement)
- **Ajout post-étude initiale :** La modération IA n'était pas dans le cahier des charges original. Elle a été ajoutée pour répondre au problème de toxicité identifié dans le questionnaire.

---

## PARTIE 4 — FONCTIONNALITÉS IMPLÉMENTÉES (Slides 17–22)

### Slide 17 — Fonctionnalités de base (MVP)
- **Titre :** Ce qui a été livré — Partie 1
- ✅ Authentification (email + Google OAuth)
- ✅ Profil utilisateur complet (pseudo, avatar, jeux, région, langue, bio, réseaux sociaux)
- ✅ Chat temps réel (DM + team + squad) avec Realtime Supabase
- ✅ Envoi de messages texte, images, fichiers, vocaux
- ✅ Recherche et ajout d'amis

### Slide 18 — Fonctionnalités sociales avancées
- **Titre :** Ce qui a été livré — Partie 2
- ✅ Création et gestion d'équipes (avec rôles : owner, members)
- ✅ Création de squads et canaux de discussion
- ✅ Système d'invitations (envoyer, recevoir, accepter, refuser)
- ✅ Fil d'actualité social (posts, commentaires, likes)
- ✅ Upload de médias (images, vidéos, fichiers)

### Slide 19 — Appels VoIP
- **Titre :** Communication vocale et vidéo intégrée
- ✅ Appels P2P (audio + vidéo)
- ✅ Appels d'équipe (multiparticipants)
- ✅ Appels de squad
- ✅ Signalisation WebRTC via Supabase Realtime
- ✅ Service Android foreground pour les appels entrants
- ✅ Notifications d'appel avec actions (répondre, refuser, muet, haut-parleur)

### Slide 20 — Matching et réputation
- **Titre :** Trouver les bons coéquipiers
- ✅ Matching automatique basé sur :
  - Type de jeu, région, disponibilité
  - Score de compatibilité stocké en `match_events`
- ✅ Système de réputation (skill, communication, respect)
- ✅ Profil public avec niveau, badges et jeux favoris
- **Ajout post-étude initiale :** Le système de réputation avec évaluation chiffrée (skill/communication/toxicité) a été ajouté après l'étude de marché. Les joueurs ont clairement exprimé le besoin d'identifier les partenaires toxiques ou peu fiables.

### Slide 21 — Gamification
- **Titre :** Engagement et progression
- ✅ Système d'XP et niveaux (1 level = 100 XP)
- ✅ Badges animés (AnimatedBadge)
- ✅ Événements trackés (chat_message_sent, etc.)
- ✅ Persistance dans Supabase (`user_progress`)
- **Ajout post-étude initiale :** Le système de gamification n'était pas prévu dans le périmètre initial. Il a été implémenté pour renforcer la fidélisation et l'engagement des utilisateurs, répondant au besoin d'usage régulier identifié dans l'enquête.

### Slide 22 — Optimiseur Android et background
- **Titre :** Au-delà du social — Performance device
- ✅ Module natif Kotlin : CPU/GPU tuning, frame pacing
- ✅ Service background : polling Supabase toutes les 15 minutes
- ✅ Notifications push via Firebase + fonction Edge Supabase
- ✅ Gestion des appels en arrière-plan
- **Ajout post-étude initiale :** L'optimiseur de performance Android a été ajouté pour différencier PRODIX des apps sociales classiques. Il transforme l'application en véritable outil pour gamer exigeant.

---

## PARTIE 5 — MODÈLE ÉCONOMIQUE & MONÉTISATION (Slides 23–26)

### Slide 23 — Modèle économique
- **Titre :** Comment PRODIX génère des revenus
- **Modèle retenu : Freemium**
  - Gratuit : profil, matching, chat, équipes
  - Premium (3–5 €/mois) :
    - Matching avancé (filtres illimités)
    - Badges exclusifs
    - Analyses de performance
    - Pas de publicité
- Justifié par l'étude : budget acceptable majoritaire = 3–5 €

### Slide 24 — Business Model Canvas
- **Titre :** Business Model Canvas
- Présentation sous forme de tableau 9 blocs :
  | Bloc | Contenu |
  |------|---------|
  | **Partenaires clés** | Fournisseurs cloud (Supabase, Firebase), Stores (Google, Apple), Paiements (Stripe, Google Play), Influenceurs gaming |
  | **Activités clés** | Développement backend & API, maintenance mobile, algorithme de matching, modération IA, support utilisateur, marketing |
  | **Ressources clés** | Infrastructure cloud, base de données, SDK Flutter/Supabase, données utilisateurs, marque PRODIX |
  | **Proposition de valeur** | Trouver le bon équipier au bon moment — tout-en-un gaming social |
  | **Relation client** | Communauté Discord, support in-app, réseaux sociaux |
  | **Canaux** | Google Play, App Store, site vitrine, TikTok, Instagram, YouTube |
  | **Segments clients** | Joueurs casual, compétitifs, teams Esports |
  | **Structure de coûts** | Hébergement/serveurs, développement, marketing, API externes |
  | **Flux de revenus** | Abonnements premium, publicité in-app (freemium), achats ponctuels |

### Slide 25 — Stratégie de pricing et projection
- **Titre :** Projections financières
- **Stratégie :** Freemium + pénétration
- **Coût de revient :** Charges fixes (développement, hébergement, maintenance) + charges variables (notifications, support, acquisition)
- **Prix de vente :** Coût de revient + marge adaptée au pouvoir d'achat des joueurs
- **Objectifs :**
  - Seuil critique : 100 000 utilisateurs
  - Abonnés premium estimés : 4 000 – 5 000
  - Budget de lancement : 50 000 DH

### Slide 26 — Publicité et acquisition
- **Titre :** Stratégie marketing
- **Canaux digitaux :** TikTok (contenu viral, défis), Instagram (visuels, stories, gameplay), YouTube (démos, tutoriels), Discord (communauté beta)
- **SEO :** Articles « Comment trouver de bons équipiers », Top apps gaming
- **SEA :** Google Ads, YouTube Ads, TikTok Ads, bannières display
- **Supports physiques :** Cartes de visite avec QR code de téléchargement
- **Vidéo publicitaire :** Structure narrative (frustration → solution → résultat)
- **Tutoriels :** YouTube, TikTok, Instagram + guide PDF intégré

---

## PARTIE 6 — FEUILLE DE ROUTE & PERSPECTIVES (Slides 27–28)

### Slide 27 — Prochaines étapes
- **Titre :** Roadmap
- ✅ Prototype fonctionnel (terminé)
- 🔄 Tests utilisateurs (en cours)
- 📅 Lancement beta fermé (Discord + TestFlight/Play Console)
- 📅 Campagne d'acquisition ciblée
- 📅 Version 1.0 publique
- 📅 Itérations basées sur les retours

### Slide 28 — Évolutions futures
- **Titre :** PRODIX 2.0 — Ce qui arrive
- Amélioration de l'algorithme de matching (machine learning)
- Analyse avancée des performances de jeu
- Intégration avec les APIs des jeux (Riot, Steam, Epic)
- Mode tournoi avec bracket automatique
- Marketplace de coaches et boosters
- Application iOS

---

## PARTIE 7 — CONCLUSION (Slides 29–30)

### Slide 29 — Résumé et message clé
- **Titre :** Gagner ne dépend plus seulement de votre skill, mais aussi de votre équipe
- PRODIX transforme la frustration en opportunité
- Une architecture robuste : Supabase au cœur, IA en renfort
- Des fonctionnalités qui dépassent le cadre initial de l'étude :
  - ✅ Modération IA (toxicité)
  - ✅ Système de réputation chiffrée
  - ✅ Gamification (XP, niveaux, badges)
  - ✅ Optimiseur Android natif
  - ✅ Appels VoIP multiparticipants
- Un modèle économique viable : Freemium à 3–5 €/mois

### Slide 30 — Remerciements et contact
- **Titre :** Merci
- Projet réalisé par **Staili Saad**
- Sous l'encadrement de **Mr El Mernissi Abderrazzak** & **Mr Edebich Ayoub**
- **Contact :**
  - GitHub : https://github.com/StailiSaad/PRODIXt
  - Site web : [à compléter]
  - Réseaux sociaux : PRODIX – GAMING SOCIAL NETWORK
- Questions ?

---

### NOTES COMPLÉMENTAIRES POUR LE GÉNÉRATEUR DE PRÉSENTATION

1. **Slides 3 et 12–14 :** Contenu original de l'analyse de code — ces slides sont uniques à cette présentation et ne se trouvent pas dans les documents Replit
2. **Slides 17–22 :** Mentionner clairement les « Ajouts post-étude initiale » pour montrer l'évolution du projet
3. **Charte graphique :** Appliquer systématiquement les couleurs et polices indiquées
4. **Style :** Chaque slide doit tenir sur un écran, utiliser des puces, éviter les paragraphes
5. **Schémas :** Pour les slides architecturales (10–14), utiliser des diagrammes, pas de texte brut
6. **Données chiffrées :** Slides 3, 6, 16, 23 — mettre les chiffres en valeur (gros caractères, couleurs contrastées)
7. **Ton :** Professionnel mais pas froid — le gaming est une passion, le style doit le refléter
