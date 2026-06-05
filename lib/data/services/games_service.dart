import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Game entry from the local database (sourced from EveryVideoGameEver repo).
class GameEntry {
  final String name;
  final String genre;
  final String platform;

  const GameEntry({required this.name, required this.genre, required this.platform});
}

List<GameEntry> _parseGamesJson(String raw) {
  final List<dynamic> data = jsonDecode(raw);
  return data
      .whereType<Map<String, dynamic>>()
      .where((e) => e['n'] is String)
      .map<GameEntry>((e) => GameEntry(
            name: e['n'] as String,
            genre: e['g'] is String ? e['g'] as String : '',
            platform: e['p'] is String ? e['p'] as String : '',
          ))
      .toList();
}

/// Service that loads 68,000+ games from the bundled asset (cloned from
/// https://github.com/Elbriga14/EveryVideoGameEver).
/// Data is loaded once from assets/data/games_db.json and cached in memory.
class GamesService {
  static List<GameEntry>? _cache;
  static bool _loading = false;

  /// Load the full games database from the bundled asset.
  static Future<void> loadGames() async {
    if (_cache != null || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle.loadString('assets/data/games_db.json');
      _cache = await compute(_parseGamesJson, raw);
    } catch (e) {
      _cache = [];
    }
    _loading = false;
  }

  /// Returns true when the database has been loaded.
  static bool get isLoaded => _cache != null;

  /// Total number of games in the database.
  static int get totalGames => _cache?.length ?? 0;

  /// Strip emoji and non-alphanumeric chars for fuzzy matching.
  static String _normalize(String s) {
    return s.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
  }

  /// Get a paginated batch of games for browsing.
  static List<GameEntry> getGamesBatch({int offset = 0, int limit = 200}) {
    if (_cache == null) return [];
    final end = (offset + limit).clamp(0, _cache!.length);
    return _cache!.sublist(offset, end);
  }

  /// Search games by name. Returns up to [limit] results.
  static List<GameEntry> searchGames(String query, {int limit = 50}) {
    if (_cache == null || query.trim().isEmpty) return [];
    final q = _normalize(query);
    if (q.isEmpty) return [];
    final results = <GameEntry>[];
    for (final game in _cache!) {
      final normalized = _normalize(game.name);
      if (normalized.contains(q)) {
        results.add(game);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  /// Get all unique genres from the database.
  static List<String> getGenres() {
    if (_cache == null) return [];
    final genres = <String>{};
    for (final g in _cache!) {
      if (g.genre.isNotEmpty) genres.add(g.genre);
    }
    final list = genres.toList()..sort();
    return list;
  }

  /// Get all unique platforms.
  static List<String> getPlatforms() {
    if (_cache == null) return [];
    final platforms = <String>{};
    for (final g in _cache!) {
      if (g.platform.isNotEmpty) platforms.add(g.platform);
    }
    return platforms.toList()..sort();
  }

  /// Get popular/well-known esports games for quick selection.
  static List<String> getPopularGames() {
    return const [
      'Valorant',
      'Counter-Strike: Global Offensive',
      'League of Legends',
      'Fortnite',
      'Apex Legends',
      'Overwatch 2',
      'Call of Duty: Modern Warfare',
      'Call of Duty: Warzone',
      'Rainbow Six: Siege',
      'Rocket League',
      'PUBG: Battlegrounds',
      'Dota 2',
      'FIFA 23',
      'Minecraft',
      'Grand Theft Auto V',
      'Elden Ring',
      'The Legend of Zelda: Tears of the Kingdom',
      'Super Smash Bros. Ultimate',
      'Halo Infinite',
      'Destiny 2',
      'Genshin Impact',
      'World of Warcraft',
      'Diablo IV',
      'Street Fighter 6',
      'Tekken 7',
      'Mortal Kombat 11',
      'Starcraft II: Wings of Liberty',
      'Dead by Daylight',
      'Among Us',
      'Fall Guys',
    ];
  }
}
