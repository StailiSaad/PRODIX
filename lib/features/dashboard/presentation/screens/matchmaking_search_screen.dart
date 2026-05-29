import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_backend_service.dart';
import '../../../../data/services/games_service.dart';
import '../../../gamification/gamification_cubit.dart';
import '../../../../shared/widgets/animated_badge.dart';
class MatchmakingSearchScreen extends StatefulWidget {
  const MatchmakingSearchScreen({super.key});

  @override
  State<MatchmakingSearchScreen> createState() =>
      _MatchmakingSearchScreenState();
}

class _MatchmakingSearchScreenState extends State<MatchmakingSearchScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _recommendedPlayers = [];
  String? _error;
  final _searchController = TextEditingController();
  final Set<String> _sentInvites = {};

  // Filters
  String? _filterGameType;
  String? _filterRole;
  String? _filterCountry;
  String? _filterLanguage;
  String? _filterRegion;
  int? _filterMinLevel;
  List<String> _filterGames = [];
  List<String> _countries = [];

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _preloadGames();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSentInvites();
      _loadMatches();
    });
  }

  Future<void> _loadSentInvites() async {
    final svc = context.read<SupabaseBackendService>();
    try {
      final ids = await svc.getSentInvitationIds();
      if (mounted) setState(() => _sentInvites.addAll(ids));
    } catch (e) {
      debugPrint('_loadSentInvites error: $e');
    }
  }

  Future<void> _preloadGames() async {
    await GamesService.loadGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final data = await rootBundle.loadString('assets/data/countries.json');
      final list = List<String>.from(jsonDecode(data));
      if (mounted) setState(() => _countries = list);
    } catch (e) {
      debugPrint('_loadCountries error: $e');
    }
  }

  bool get _hasActiveFilters =>
      _filterGameType != null ||
      _filterRole != null ||
      _filterCountry != null ||
      _filterLanguage != null ||
      _filterRegion != null ||
      _filterMinLevel != null ||
      _filterGames.isNotEmpty;

  int get _activeFilterCount {
    int count = 0;
    if (_filterGameType != null) count++;
    if (_filterRole != null) count++;
    if (_filterCountry != null) count++;
    if (_filterLanguage != null) count++;
    if (_filterRegion != null) count++;
    if (_filterMinLevel != null) count++;
    count += _filterGames.length;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _filterGameType = null;
      _filterRole = null;
      _filterCountry = null;
      _filterLanguage = null;
      _filterRegion = null;
      _filterMinLevel = null;
      _filterGames = [];
    });
    _loadMatches();
  }

  void _showPlayerProfile(Map<String, dynamic> profile) async {
    final svc = context.read<SupabaseBackendService>();
    final profileId = profile['id'] as String;
    final pseudo = profile['pseudo'] ?? 'Joueur';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder(
          future: Future.wait([
            svc.getOtherProfile(profileId),
            svc.getOtherFavoriteGames(profileId),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final fullProfile =
                snapshot.data![0] as Map<String, dynamic>? ?? profile;
            final favGames =
                snapshot.data![1] as List<String>? ?? [];

            final xp = fullProfile['experience_points'] as int? ?? fullProfile['xp'] as int? ?? 0;
            final level = 1 + (xp ~/ 100);
            final role = (fullProfile['role'] ?? 'FLEX').toString().toUpperCase();
            final region = fullProfile['region'] ?? '??';
            final country = fullProfile['country'] as String? ?? '';
            final bio = fullProfile['bio'] as String? ?? '';
            final lang = (fullProfile['language'] as String? ?? 'fr').toUpperCase();
            final avatarUrl = fullProfile['avatar_url'] as String?;

            final alreadySent = _sentInvites.contains(profileId);

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollCtrl) => SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.textVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppTheme.cardHighColor,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?',
                              style: TextStyle(
                                  color: AppTheme.primaryColor, fontSize: 36))
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBadge(level: level, size: 28),
                        const SizedBox(width: 8),
                        Text(pseudo,
                            style: TextStyle(
                                color: AppTheme.textMain,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ProfileInfoRow('Rôle', role),
                    _ProfileInfoRow('Région', region),
                    _ProfileInfoRow('Pays', country.isNotEmpty ? country : 'Non défini'),
                    _ProfileInfoRow('Langue', lang),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardHighColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bio',
                                style: TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(bio,
                                style: TextStyle(
                                    color: AppTheme.textMain, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                    if (favGames.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardHighColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('JEUX FAVORIS',
                                style: TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: favGames.take(10).map((g) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(g,
                                    style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: Icon(alreadySent ? Icons.check : Icons.person_add),
                        label: Text(alreadySent ? 'Invitation envoyée' : 'Envoyer une invitation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alreadySent ? AppTheme.tertiaryColor : AppTheme.primaryColor,
                          foregroundColor: alreadySent ? Colors.black87 : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: alreadySent ? null : () async {
                          try {
                            await svc.sendInvitation(profileId);
                            if (ctx.mounted) {
                              setState(() => _sentInvites.add(profileId));
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('📩 Invitation envoyée à $pseudo'),
                                  backgroundColor: AppTheme.tertiaryColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _compatibilityScore(Map<String, dynamic> profile) {
    int matches = 0;
    int total = 0;

    if (_filterRole != null) {
      total++;
      if ((profile['role'] as String? ?? '').toLowerCase() == _filterRole!.toLowerCase()) {
        matches++;
      }
    }
    if (_filterCountry != null) {
      total++;
      if ((profile['country'] as String? ?? '') == _filterCountry) {
        matches++;
      }
    }
    if (_filterLanguage != null) {
      total++;
      if ((profile['language'] as String? ?? '').toLowerCase() == _filterLanguage!.toLowerCase()) {
        matches++;
      }
    }
    if (_filterRegion != null) {
      total++;
      if ((profile['region'] as String? ?? '').toLowerCase() == _filterRegion!.toLowerCase()) {
        matches++;
      }
    }
    if (_filterMinLevel != null) {
      total++;
      final pXp = (profile['experience_points'] as int? ?? profile['xp'] as int? ?? 0);
      final pLevel = 1 + (pXp ~/ 100);
      if (pLevel >= _filterMinLevel!) {
        matches++;
      }
    }

    // Base score from XP
    final xp = (profile['experience_points'] as int? ?? profile['xp'] as int? ?? 0);
    final xpScore = ((xp / 2000).clamp(0.0, 1.0) * 30);

    // Filter match score
    final filterScore = total > 0 ? (matches / total) * 70 : 50;

    return (xpScore + filterScore).roundToDouble();
  }

  Future<void> _loadMatches({String? searchQuery}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _recommendedPlayers = [];
    });
    final svc = context.read<SupabaseBackendService>();
    try {
      List<Map<String, dynamic>> results;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final profiles = await svc.searchPlayers(searchQuery);
        results = profiles
            .map((p) => {
                  'profile': p,
                  'compatibilityScore': _compatibilityScore(p),
                })
            .toList();
      } else {
        results = await svc.findMatches(
          gameType: _filterGameType,
          region: _filterRegion,
          availability: null,
        );
        // Client-side filtering for fields the backend doesn't support natively
        if (_filterRole != null || _filterCountry != null || _filterLanguage != null || _filterGames.isNotEmpty) {
          // Pre-fetch favorite games for game filter
          Map<String, List<String>>? favGamesMap;
          if (_filterGames.isNotEmpty && results.isNotEmpty) {
            favGamesMap = {};
            final allIds = results
                .map((r) => ((r['profile'] as Map<String, dynamic>?) ?? r)['id'] as String)
                .toList();
            final futures = allIds.map((id) => svc.getOtherFavoriteGames(id));
            final allGames = await Future.wait(futures);
            for (int i = 0; i < allIds.length; i++) {
              favGamesMap[allIds[i]] = allGames[i];
            }
          }

          results = results.where((r) {
            final p = r['profile'] as Map<String, dynamic>? ?? {};
            if (_filterRole != null &&
                (p['role'] as String? ?? '').toLowerCase() != _filterRole!.toLowerCase()) {
              return false;
            }
            if (_filterCountry != null &&
                (p['country'] as String? ?? '') != _filterCountry) {
              return false;
            }
            if (_filterLanguage != null &&
                (p['language'] as String? ?? '').toLowerCase() != _filterLanguage!.toLowerCase()) {
              return false;
            }
            if (_filterGames.isNotEmpty && favGamesMap != null) {
              final pid = p['id'] as String;
              final games = favGamesMap[pid] ?? [];
              final gameNames = games.map((g) => g.toLowerCase());
              if (!_filterGames.any((fg) => gameNames.any((g) => g.contains(fg.toLowerCase())))) {
                return false;
              }
            }
            return true;
          }).toList();
        }
      }
      if (mounted) {
        results.sort((a, b) => (b['compatibilityScore'] as num)
            .compareTo(a['compatibilityScore'] as num));
        setState(() {
          _matches = results;
          _recommendedPlayers = results.take(3).toList();
          _isLoading = false;
        });
        context.read<GamificationCubit>().recordEvent('match_found');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendInvite(String profileId, String playerName) async {
    final svc = context.read<SupabaseBackendService>();
    try {
      await svc.sendInvitation(profileId);
      if (mounted) {
        context.read<GamificationCubit>().recordEvent('invitation_sent');
        setState(() => _sentInvites.add(profileId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📩 Invitation envoyée à $playerName !'),
            backgroundColor: AppTheme.tertiaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showFilterSheet() {
    String? localGameType = _filterGameType;
    String? localRole = _filterRole;
    String? localCountry = _filterCountry;
    String? localLanguage = _filterLanguage;
    String? localRegion = _filterRegion;
    int? localMinLevel = _filterMinLevel;
    List<String> localGames = List.from(_filterGames);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollCtrl) => SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('FILTRES',
                            style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              localGameType = null;
                              localRole = null;
                              localCountry = null;
                              localLanguage = null;
                              localRegion = null;
                              localMinLevel = null;
                              localGames = [];
                            });
                          },
                          child: Text('Tout effacer',
                              style: TextStyle(color: AppTheme.primaryColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _filterDropdown(ctx, 'Type de jeu', localGameType, [
                      'FPS', 'MOBA', 'Battle Royale', 'MMO', 'RTS', 'RPG', 'Sports',
                    ], (v) => setSheetState(() => localGameType = v)),
                    const SizedBox(height: 16),

                    _filterDropdown(ctx, 'Rôle', localRole, [
                      'support', 'assault', 'sniper', 'tank', 'flex', 'IGL',
                    ], (v) => setSheetState(() => localRole = v)),
                    const SizedBox(height: 16),

                    _filterDropdown(ctx, 'Région', localRegion, [
                      'EU', 'NA', 'ASIA', 'OCE', 'MENA', 'SA',
                    ], (v) => setSheetState(() => localRegion = v)),
                    const SizedBox(height: 16),

                    _filterDropdown(ctx, 'Niveau min', localMinLevel?.toString(), [
                      '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
                      '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
                    ], (v) => setSheetState(() => localMinLevel = v != null ? int.parse(v) : null)),
                    const SizedBox(height: 16),

                    _filterDropdown(ctx, 'Langue', localLanguage, [
                      'en', 'fr', 'es', 'de', 'ar', 'pt', 'jp',
                    ], (v) => setSheetState(() => localLanguage = v)),
                    const SizedBox(height: 16),

                    _filterDropdown(ctx, 'Pays', localCountry,
                        _countries.isNotEmpty ? _countries : ['France', 'United States'],
                        (v) => setSheetState(() => localCountry = v)),
                    const SizedBox(height: 16),
                    _buildGameFilter(ctx, localGames, setSheetState),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _filterGameType = localGameType;
                            _filterRole = localRole;
                            _filterCountry = localCountry;
                            _filterLanguage = localLanguage;
                            _filterRegion = localRegion;
                            _filterMinLevel = localMinLevel;
                            _filterGames = localGames;
                          });
                          Navigator.pop(ctx);
                          _loadMatches(searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null);
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('APPLIQUER LES FILTRES',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterDropdown(
    BuildContext ctx,
    String label,
    String? currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardHighColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentValue != null
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : AppTheme.cardHighestColor,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              hint: Text('Tous',
                  style: TextStyle(
                      color: AppTheme.textGrey.withValues(alpha: 0.6), fontSize: 14)),
              isExpanded: true,
              dropdownColor: AppTheme.cardHighColor,
              style: TextStyle(color: AppTheme.textWhite, fontSize: 14),
              icon: Icon(Icons.expand_more, color: AppTheme.textGrey),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('Tous',
                      style: TextStyle(
                          color: AppTheme.textGrey.withValues(alpha: 0.6))),
                ),
                ...options.map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameFilter(
    BuildContext ctx,
    List<String> selectedGames,
    StateSetter setSheetState,
  ) {
    return _GameFilterWidget(
      selectedGames: selectedGames,
      onSelectionChanged: (games) {
        setSheetState(() {
          selectedGames
            ..clear()
            ..addAll(games);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'FIND PLAYERS',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: -1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                onSubmitted: (q) => _loadMatches(searchQuery: q),
                decoration: InputDecoration(
                  hintText: 'Rechercher par pseudo...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () =>
                        _loadMatches(searchQuery: _searchController.text),
                  ),
                ),
              ),
            ),
            // Filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Type',
                            active: _filterGameType != null,
                            value: _filterGameType,
                            onTap: _showFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Rôle',
                            active: _filterRole != null,
                            value: _filterRole,
                            onTap: _showFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Région',
                            active: _filterRegion != null,
                            value: _filterRegion,
                            onTap: _showFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Niveau',
                            active: _filterMinLevel != null,
                            value: _filterMinLevel?.toString(),
                            onTap: _showFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Langue',
                            active: _filterLanguage != null,
                            value: _filterLanguage,
                            onTap: _showFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Pays',
                            active: _filterCountry != null,
                            value: _filterCountry,
                            onTap: _showFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Jeu',
                            active: _filterGames.isNotEmpty,
                            value: _filterGames.isEmpty ? null : '${_filterGames.length} jeu${_filterGames.length > 1 ? 'x' : ''}',
                            onTap: _showFilterSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close,
                            color: AppTheme.errorColor, size: 18),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF0053DB)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showFilterSheet,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune,
                                  color: Colors.white, size: 18),
                              if (_activeFilterCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$_activeFilterCount',
                                    style: const TextStyle(
                                        color: Color(0xFF7C3AED),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Results
            // Recommendation banner
            if (_recommendedPlayers.isNotEmpty && !_isLoading && _error == null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF0053DB)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 6),
                        Text('MEILLEURS MATCHS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._recommendedPlayers.map((r) {
                      final p = r['profile'] as Map<String, dynamic>? ?? r;
                      final pseudo = p['pseudo'] ?? 'Joueur';
                      final role = (p['role'] ?? 'FLEX').toString().toUpperCase();
                      final xp = p['experience_points'] as int? ?? 0;
                      final recLevel = 1 + (xp ~/ 100);
                      final score = (r['compatibilityScore'] as num?)?.toInt() ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('$score%',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            AnimatedBadge(level: recLevel, size: 18),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(pseudo,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(role,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text('Erreur: $_error',
                              style: TextStyle(color: theme.colorScheme.error)))
                      : _matches.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 64,
                                      color: AppTheme.textVariant.withValues(alpha: 0.2)),
                                  const SizedBox(height: 16),
                                  Text('Aucun joueur trouvé.',
                                      style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant)),
                                  if (_hasActiveFilters) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _clearFilters,
                                      child: const Text('Effacer les filtres'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _loadMatches(),
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _matches.length,
                                itemBuilder: (context, index) {
                                  final item = _matches[index];
                                  final profile =
                                      item['profile'] as Map<String, dynamic>? ?? item;
                                  final score =
                                      (item['compatibilityScore'] as num?)?.toInt() ?? 0;
                                  final pseudo = profile['pseudo'] ?? 'Joueur';
                                  final role = (profile['role'] ?? 'FLEX')
                                      .toString()
                                      .toUpperCase();
                                  final region = profile['region'] ?? '??';
                                  final country = profile['country'] as String? ?? '';
                                  final lang = (profile['language'] as String? ?? '').toUpperCase();
                                  final avatarUrl =
                                      profile['avatar_url'] as String?;
                                  final profileId = profile['id'].toString();
                                  final xp = profile['experience_points'] as int? ?? 0;
                                  final playerLevel = 1 + (xp ~/ 100);
                                  final alreadySent = _sentInvites.contains(profileId);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _PlayerCard(
                                      pseudo: pseudo,
                                      level: playerLevel,
                                      role: role,
                                      region: region,
                                      country: country,
                                      language: lang,
                                      avatarUrl: avatarUrl,
                                      compatScore: score,
                                      alreadySent: alreadySent,
                                      onTap: () => _showPlayerProfile(profile),
                                      onInvite: () {
                                        if (alreadySent) return;
                                        _sendInvite(profileId, pseudo);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final String? value;
  final VoidCallback onTap;

  _FilterChip({
    required this.label,
    required this.active,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display = active && value != null ? '$label: $value' : label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.cardHighColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.cardHighestColor,
          ),
        ),
        child: Text(
          display,
          style: TextStyle(
            color: active ? AppTheme.primaryColor : AppTheme.textGrey,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String pseudo;
  final int level;
  final String role;
  final String region;
  final String country;
  final String language;
  final String? avatarUrl;
  final int compatScore;
  final bool alreadySent;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  _PlayerCard({
    required this.pseudo,
    required this.level,
    required this.role,
    required this.region,
    this.country = '',
    this.language = '',
    this.avatarUrl,
    required this.compatScore,
    this.alreadySent = false,
    required this.onTap,
    required this.onInvite,
  });

  Color get _scoreColor {
    if (compatScore >= 80) return Colors.greenAccent;
    if (compatScore >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.cardHighestColor,
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Text(
                          pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        )
                      : null,
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: alreadySent ? Colors.grey : theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedBadge(level: level, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(pseudo,
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Tag(role, theme.colorScheme.onSurfaceVariant),
                      _Tag(region, theme.colorScheme.tertiary),
                      if (country.isNotEmpty)
                        _Tag(country, AppTheme.primaryColor),
                      if (language.isNotEmpty)
                        _Tag(language, AppTheme.secondaryColor),
                      _Tag('$compatScore%', _scoreColor),
                    ],
                  ),
                ],
              ),
            ),

            // Invite button
            Container(
              decoration: BoxDecoration(
                gradient: alreadySent
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF0053DB)]),
                color: alreadySent ? Colors.grey.shade600 : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: alreadySent ? null : onInvite,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Icon(
                        alreadySent ? Icons.check : Icons.person_add,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _GameFilterWidget extends StatefulWidget {
  final List<String> selectedGames;
  final ValueChanged<List<String>> onSelectionChanged;

  _GameFilterWidget({
    required this.selectedGames,
    required this.onSelectionChanged,
  });

  @override
  State<_GameFilterWidget> createState() => _GameFilterWidgetState();
}

class _GameFilterWidgetState extends State<_GameFilterWidget> {
  final _searchCtrl = TextEditingController();
  List<String> _results = [];

  @override
  void initState() {
    super.initState();
    if (GamesService.isLoaded) {
      _results = GamesService.getGamesBatch(limit: 150)
          .map((g) => g.name)
          .toList();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _updateResults(String query) {
    setState(() {
      _results = query.trim().isEmpty
          ? GamesService.getGamesBatch(limit: 150)
              .map((g) => g.name)
              .toList()
          : GamesService.searchGames(query.trim(), limit: 50)
              .map((g) => g.name)
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!GamesService.isLoaded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JEU',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Center(child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
          const SizedBox(height: 8),
          Center(
            child: Text('Chargement de ${GamesService.totalGames}+ jeux...',
                style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5), fontSize: 11)),
          ),
        ],
      );
    }

    final selected = widget.selectedGames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JEU',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardHighColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected.isNotEmpty
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : AppTheme.cardHighestColor,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: AppTheme.textGrey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: AppTheme.textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un jeu...',
                    hintStyle: TextStyle(color: AppTheme.textGrey),
                    border: InputBorder.none,
                  ),
                  onChanged: _updateResults,
                ),
              ),
              if (selected.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textGrey, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    widget.onSelectionChanged([]);
                    _updateResults('');
                  },
                ),
            ],
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: selected.map((g) => Chip(
                label: Text(g, style: TextStyle(color: AppTheme.textWhite, fontSize: 11)),
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                deleteIcon: Icon(Icons.close, size: 14, color: AppTheme.textVariant),
                onDeleted: () {
                  final updated = List<String>.from(selected)..remove(g);
                  widget.onSelectionChanged(updated);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              )).toList(),
            ),
          ),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppTheme.cardHighColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView(
              shrinkWrap: true,
              children: _results.map((g) {
                final isSelected = selected.contains(g);
                return ListTile(
                  dense: true,
                  title: Text(g,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textWhite,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      )),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textGrey,
                    size: 20,
                  ),
                  onTap: () {
                    final updated = List<String>.from(selected);
                    if (isSelected) {
                      updated.remove(g);
                    } else {
                      updated.add(g);
                    }
                    widget.onSelectionChanged(updated);
                  },
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          selected.isEmpty
              ? 'Parcourez ou cherchez parmi ${GamesService.totalGames}+ jeux'
              : '${selected.length} jeu${selected.length > 1 ? 'x' : ''} sélectionné${selected.length > 1 ? 's' : ''}',
          style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5), fontSize: 11),
        ),
      ],
    );
  }
}
