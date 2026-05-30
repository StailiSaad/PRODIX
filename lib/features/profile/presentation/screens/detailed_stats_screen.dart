import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle, MethodChannel;
import '../../profile_cubit.dart';
import '../../../auth/auth_cubit.dart';
import '../../../gamification/gamification_cubit.dart';
import '../../../theme/theme_cubit.dart';
import '../../../../data/services/games_service.dart';
import '../../../../core/config/profile_defaults.dart';
import '../../../../shared/widgets/animated_badge.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../posts/presentation/screens/user_posts_screen.dart';


class DetailedStatsScreen extends StatefulWidget {
  const DetailedStatsScreen({super.key});

  @override
  State<DetailedStatsScreen> createState() => _DetailedStatsScreenState();
}

class _DetailedStatsScreenState extends State<DetailedStatsScreen> {
  late TextEditingController _pseudoCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _facebookCtrl;
  late TextEditingController _githubCtrl;
  String _role = ProfileDefaults.role;
  String _region = ProfileDefaults.region;
  String _language = ProfileDefaults.language;
  String _availability = ProfileDefaults.availability;
  String _gameType = ProfileDefaults.gameType;
  String _country = ProfileDefaults.country;
  List<String> _countries = [];
  List<String> _favoriteGames = [];
  bool _isEditing = false;
  bool _gamesLoading = false;
  Uint8List? _newAvatarBytes;
  String? _newAvatarExtension;

  @override
  void initState() {
    super.initState();
    final s = context.read<ProfileCubit>().state;
    _pseudoCtrl = TextEditingController(text: s.pseudo);
    _bioCtrl = TextEditingController(text: s.bio);
    _instagramCtrl = TextEditingController(text: s.socialInstagram);
    _facebookCtrl = TextEditingController(text: s.socialFacebook);
    _githubCtrl = TextEditingController(text: s.socialGithub);
    _role = s.role;
    _region = s.region;
    _language = s.language;
    _availability = s.availability;
    _gameType = s.gameType;
    _country = s.country.isNotEmpty ? s.country : ProfileDefaults.country;
    _favoriteGames = List.from(s.favoriteGames);
    _preloadGames();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final data = await rootBundle.loadString('assets/data/countries.json');
      final list = List<String>.from(jsonDecode(data));
      if (mounted) {
        setState(() => _countries = list);
      }

    } catch (e) {
      debugPrint('_loadCountries error: $e');
      if (mounted) {
        setState(() => _countries = [
          'France', 'United States', 'United Kingdom', 'Canada', 'Germany',
          'Spain', 'Italy', 'Portugal', 'Brazil', 'Morocco', 'Algeria', 'Tunisia',
          'Belgium', 'Switzerland', 'Netherlands', 'Sweden', 'Norway', 'Poland',
          'Japan', 'South Korea', 'China', 'India', 'Australia', 'Mexico',
          'Argentina', 'Colombia', 'Egypt', 'South Africa', 'Turkey', 'Russia',
        ]);
      }
    }
  }

  Future<void> _preloadGames() async {
    setState(() => _gamesLoading = true);
    await GamesService.loadGames();
    if (mounted) setState(() => _gamesLoading = false);
  }

  @override
  void dispose() {
    _pseudoCtrl.dispose();
    _bioCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _githubCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await context.read<ProfileCubit>().saveProfile(
      pseudo: _pseudoCtrl.text,
      language: _language,
      availability: _availability,
      gameType: _gameType,
      role: _role,
      region: _region,
      country: _country,
      bio: _bioCtrl.text,
      favoriteGames: _favoriteGames,
      avatarBytes: _newAvatarBytes,
      avatarExtension: _newAvatarExtension,
      socialInstagram: _instagramCtrl.text,
      socialFacebook: _facebookCtrl.text,
      socialGithub: _githubCtrl.text,
    );
    context.read<GamificationCubit>().recordEvent('profile_updated');
    if (mounted) setState(() => _isEditing = false);
  }

  Future<void> _openGamesPicker() async {
    final searchCtrl = TextEditingController();
    List<GameEntry> results = [];
    final selected = Set<String>.from(_favoriteGames);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1729),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('Select Your Games', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${selected.length} selected', style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search games...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1A2340),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (q) {
                      setSheetState(() {
                        results = GamesService.searchGames(q, limit: 50);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (selected.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: selected.map((g) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(g, style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: const Color(0xFF7C3AED),
                          deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                          onDeleted: () => setSheetState(() => selected.remove(g)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: _gamesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty && searchCtrl.text.isEmpty
                      ? _buildPopularGames(selected, setSheetState, scrollCtrl)
                      : results.isEmpty
                        ? Center(child: Text('No games found for "${searchCtrl.text}"', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))))
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final game = results[i];
                              final isSelected = selected.contains(game.name);
                              return ListTile(
                                leading: Icon(
                                  isSelected ? Icons.check_circle : Icons.sports_esports,
                                  color: isSelected ? const Color(0xFF7C3AED) : Colors.white38,
                                ),
                                title: Text(game.name, style: TextStyle(color: isSelected ? const Color(0xFF7C3AED) : Colors.white)),
                                subtitle: Text('${game.genre} • ${game.platform}', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                                onTap: () {
                                  setSheetState(() {
                                    if (isSelected) { selected.remove(game.name); } else { selected.add(game.name); }
                                  });
                                },
                              );
                            },
                          ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Confirm ${selected.length} games', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    setState(() => _favoriteGames = selected.toList());
  }

  Widget _buildPopularGames(Set<String> selected, StateSetter setSheetState, ScrollController scrollCtrl) {
    final popular = GamesService.getPopularGames();
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text('🔥 POPULAR ESPORTS TITLES', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        ...popular.map((game) {
          final isSelected = selected.contains(game);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(isSelected ? Icons.check_circle : Icons.sports_esports, color: isSelected ? const Color(0xFF7C3AED) : Colors.white38),
            title: Text(game, style: TextStyle(color: isSelected ? const Color(0xFF7C3AED) : Colors.white)),
            onTap: () => setSheetState(() {
              if (isSelected) {
                selected.remove(game);
              } else {
                selected.add(game);
              }
            }),
          );
        }),
        const SizedBox(height: 12),
        Text('Or search from ${GamesService.totalGames}+ games above ☝️', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
        elevation: 0,
        title: Text('MY PROFILE', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: -1)),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              color: Colors.white54,
              onPressed: () => setState(() => _isEditing = false),
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit, color: _isEditing ? const Color(0xFF00E676) : theme.colorScheme.primary),
            tooltip: _isEditing ? 'Save' : 'Edit',
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            color: theme.colorScheme.primary,
            tooltip: 'Theme',
            onPressed: () => _showThemePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            color: theme.colorScheme.error,
            tooltip: 'Sign Out',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF171F33),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure?', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); context.read<AuthCubit>().signOut(); },
                      child: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.savedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Color(0xFF00E676)),
            );
            context.read<ProfileCubit>().resetSavedSuccess();
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading) return const Center(child: CircularProgressIndicator());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── AVATAR + NAME HEADER ──
                _buildAvatarSection(theme, state),
                const SizedBox(height: 24),

                // ── STATS ROW ──
                _buildStatsRow(theme, state),
                const SizedBox(height: 24),

                // ── PROFILE FIELDS ──
                _buildGlassCard(theme, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.person, 'Player Info'),
                    const SizedBox(height: 12),
                    _buildField('Gamertag', _pseudoCtrl, theme),
                    const SizedBox(height: 12),
                    _buildField('Bio', _bioCtrl, theme, maxLines: 3),
                  ],
                )),
                const SizedBox(height: 16),

                // ── DROPDOWNS ──
                _buildGlassCard(theme, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.tune, 'Preferences'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _buildDropdown('Role', _role, ['support', 'assault', 'sniper', 'tank', 'flex', 'IGL'], (v) => setState(() => _role = v!), theme)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDropdown('Region', _region, ['EU', 'NA', 'ASIA', 'OCE', 'MENA', 'SA'], (v) => setState(() => _region = v!), theme)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _buildDropdown('Language', _language, ['en', 'fr', 'es', 'de', 'ar', 'pt', 'jp'], (v) => setState(() => _language = v!), theme)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDropdown('Game Type', _gameType, ['FPS', 'MOBA', 'BR', 'MMO', 'RTS', 'RPG', 'Sports'], (v) => setState(() => _gameType = v!), theme)),
                    ]),
                    const SizedBox(height: 12),
                    _buildDropdown('Availability', _availability, ['morning', 'afternoon', 'evening', 'night', 'weekend', 'anytime'], (v) => setState(() => _availability = v!), theme),
                    const SizedBox(height: 12),
                    _buildCountryPicker(theme),
                  ],
                )),
                const SizedBox(height: 16),

                // ── SOCIALS ──
                _buildGlassCard(theme, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.link, 'Socials'),
                    const SizedBox(height: 12),
                    _buildField('Instagram', _instagramCtrl, theme),
                    const SizedBox(height: 12),
                    _buildField('Facebook', _facebookCtrl, theme),
                    const SizedBox(height: 12),
                    _buildField('GitHub', _githubCtrl, theme),
                  ],
                )),
                const SizedBox(height: 16),

                // ── FAVORITE GAMES ──
                _buildGlassCard(theme, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _sectionTitle(theme, Icons.sports_esports, 'Favorite Games'),
                        const Spacer(),
                        if (_isEditing)
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
                            onPressed: _openGamesPicker,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_favoriteGames.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.sports_esports, size: 40, color: Colors.white.withValues(alpha: 0.15)),
                              const SizedBox(height: 8),
                              Text('No games selected', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                              if (_isEditing) ...[
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _openGamesPicker,
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF7C3AED))),
                                  child: const Text('Browse 50,000+ games', style: TextStyle(color: Color(0xFF7C3AED))),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _favoriteGames.map((g) => Chip(
                          avatar: const Icon(Icons.videogame_asset, size: 16, color: Colors.white70),
                          label: Text(g, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: const Color(0xFF1A2340),
                          side: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                          deleteIcon: _isEditing ? const Icon(Icons.close, size: 14, color: Colors.white54) : null,
                          onDeleted: _isEditing ? () => setState(() => _favoriteGames.remove(g)) : null,
                        )).toList(),
                      ),
                  ],
                )),
                const SizedBox(height: 16),

                // ── SOCIAL LINKS (view only) ──
                if (!_isEditing)
                  _buildGlassCard(theme, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(theme, Icons.link, 'Socials'),
                      const SizedBox(height: 12),
                      _socialLink(theme, Icons.camera_alt, 'Instagram', state.socialInstagram, 'https://instagram.com/'),
                      const Divider(color: Colors.white12),
                      _socialLink(theme, Icons.facebook, 'Facebook', state.socialFacebook, 'https://facebook.com/'),
                      const Divider(color: Colors.white12),
                      _socialLink(theme, Icons.code, 'GitHub', state.socialGithub, 'https://github.com/'),
                    ],
                  )),
                const SizedBox(height: 16),

                // ── PROFILE COMPLETION ──
                _buildGlassCard(theme, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.verified, 'Profile Completion'),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: state.completionPercent,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(
                          state.completionPercent >= 0.8 ? const Color(0xFF00E676) : const Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(state.completionPercent * 100).toInt()}% complete${state.completionPercent >= 0.8 ? " — Eligible for matchmaking!" : ""}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                  ],
                )),
                const SizedBox(height: 16),

                // ── MY POSTS ──
                _buildGlassCard(theme, child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UserPostsScreen()),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _sectionTitle(theme, Icons.photo_library, 'My Posts'),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Color(0xFF7C3AED)),
                      ],
                    ),
                  ),
                )),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(ThemeData theme, ProfileState state) {
    final avatar = state.avatarUrl;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF7C3AED), width: 3),
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), blurRadius: 20)],
              ),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFF1A2340),
                backgroundImage: _newAvatarBytes != null
                    ? MemoryImage(_newAvatarBytes!)
                    : (avatar != null && avatar.isNotEmpty) 
                        ? NetworkImage(avatar) as ImageProvider 
                        : null,
                child: (_newAvatarBytes == null && (avatar == null || avatar.isEmpty))
                  ? Text(state.pseudo.isNotEmpty ? state.pseudo[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 40, color: Colors.white54))
                  : null,
              ),
            ),
            if (_isEditing)
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    final ext = image.name.split('.').last;
                    setState(() {
                      _newAvatarBytes = bytes;
                      _newAvatarExtension = ext;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BlocBuilder<GamificationCubit, GamificationState>(
              builder: (context, gState) {
                final lvl = gState.progress?.level ?? 1;
                return AnimatedBadge(level: lvl, size: 30);
              },
            ),
            const SizedBox(width: 8),
            Text(state.pseudo.isEmpty ? 'Player' : state.pseudo,
              style: theme.textTheme.headlineSmall?.copyWith(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.cardHighColor, borderRadius: BorderRadius.circular(12)),
              child: Text(state.role.toUpperCase(), style: TextStyle(color: AppTheme.textVariant, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.cardHighColor, borderRadius: BorderRadius.circular(12)),
              child: Text(state.region, style: TextStyle(color: AppTheme.textVariant, fontSize: 12)),
            ),
            if (state.country.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.cardHighColor, borderRadius: BorderRadius.circular(12)),
                child: Text(state.country, style: TextStyle(color: AppTheme.textVariant, fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        BlocBuilder<GamificationCubit, GamificationState>(
          builder: (context, gState) {
            final progress = gState.progress;
            if (progress == null) return const SizedBox.shrink();
            final xpForLevel = 100;
            final currentXp = progress.xpForCurrentLevel(xpForLevel);
            final ratio = progress.levelProgress(xpForLevel);
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF0053DB)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('Gamification Lv.${progress.level}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: AppTheme.cardHighColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('$currentXp / $xpForLevel XP',
                    style: TextStyle(color: AppTheme.textVariant, fontSize: 10)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsRow(ThemeData theme, ProfileState state) {
    return Row(
      children: [
        _buildStatPill(theme, 'AMIS', state.friendsCount.toString(), const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        _buildStatPill(theme, 'XP', '${state.xp}', const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _buildStatPill(ThemeData theme, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: AppTheme.textVariant, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _socialLink(ThemeData theme, IconData icon, String label, String value, String baseUrl) {
    final isEmpty = value.isEmpty;
    return GestureDetector(
      onTap: isEmpty ? null : () => launchUrl(Uri.parse(value.startsWith('http') ? value : '$baseUrl$value'), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AppTheme.textVariant, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(isEmpty ? 'Non renseigné' : value,
                      style: TextStyle(
                        color: isEmpty ? AppTheme.textGrey : AppTheme.primaryInverse,
                        fontSize: 14,
                        decoration: isEmpty ? null : TextDecoration.underline,
                      )),
                ],
              ),
            ),
            if (!isEmpty)
              const Icon(Icons.open_in_new, color: Color(0xFF7C3AED), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryPicker(ThemeData theme) {
    return IgnorePointer(
      ignoring: !_isEditing,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _isEditing ? AppTheme.cardHighColor : AppTheme.cardHighColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.outlineColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.public, color: AppTheme.textGrey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _countries.contains(_country) ? _country : null,
                  hint: Text('Select your country',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: AppTheme.cardColor,
                  style: TextStyle(color: AppTheme.textWhite, fontSize: 13),
                  items: _countries.isEmpty
                      ? [const DropdownMenuItem(value: '', child: Text('Loading...'))]
                      : _countries
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                  onChanged: _countries.isEmpty || !_isEditing
                      ? null
                      : (v) {
                          if (v != null) setState(() => _country = v);
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard(ThemeData theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardHighColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineColor.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, ThemeData theme, {int maxLines = 1, TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      enabled: _isEditing,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(color: AppTheme.textWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textGrey),
        filled: true,
        fillColor: _isEditing ? AppTheme.cardHighColor : AppTheme.cardHighColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.outlineColor.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primaryColor)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged, ThemeData theme) {
    return IgnorePointer(
      ignoring: !_isEditing,
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : options.first,
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase(), style: TextStyle(color: AppTheme.textWhite, fontSize: 13)))).toList(),
        onChanged: onChanged,
        dropdownColor: AppTheme.cardColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textGrey, fontSize: 12),
          filled: true,
          fillColor: _isEditing ? AppTheme.cardHighColor : AppTheme.cardHighColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final themeCubit = context.read<ThemeCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Display Mode', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 24),
            _themeOption(ctx, themeCubit, AppThemeMode.dark, Icons.dark_mode, 'Sombre', 'Mode sombre'),
            const SizedBox(height: 12),
            _themeOption(ctx, themeCubit, AppThemeMode.light, Icons.light_mode, 'Clair', 'Mode clair'),
            const SizedBox(height: 20),
            // Android Tweaker button (Android only)
            _settingsButton(
              icon: Icons.speed,
              label: 'Android Tweaker V1',
              subtitle: 'Optimiser les performances système',
              onTap: _launchAndroidEnhancer,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _launchAndroidEnhancer() {
    const channel = MethodChannel('com.example.prodix/android_enhancer');
    channel.invokeMethod('launchEnhancer');
  }

  Widget _settingsButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 28),
      title: Text(label, style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: AppTheme.textVariant, fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios, color: AppTheme.textVariant, size: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  Widget _themeOption(BuildContext sheetCtx, ThemeCubit themeCubit, AppThemeMode mode, IconData icon, String label, String subtitle) {
    final current = themeCubit.state;
    final selected = current == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFFD4AF37) : Theme.of(sheetCtx).colorScheme.primary, size: 28),
      title: Text(label, style: TextStyle(color: Theme.of(sheetCtx).colorScheme.onSurface, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Theme.of(sheetCtx).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
      trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37)) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: selected ? Theme.of(sheetCtx).colorScheme.primary.withValues(alpha: 0.1) : null,
      onTap: () {
        themeCubit.setTheme(mode);
        Navigator.pop(sheetCtx);
      },
    );
  }
}
