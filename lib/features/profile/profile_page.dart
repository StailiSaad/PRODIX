import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/profile_defaults.dart';
import '../../shared/widgets/animated_badge.dart';
import 'profile_cubit.dart';
import '../gamification/gamification_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Controllers
  final _pseudoCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _langCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();

  // Dropdowns
  String _availability = 'evening';
  String _gameType = 'FPS';
  String _role = 'Support';
  String _region = 'EU';
  String _country = '';
  List<String> _favoriteGames = [];
  List<String> _countries = [];

  // Privacy toggles
  bool _showEmail = false;
  bool _showPhone = false;
  bool _showLocation = true;

  String? _localImagePath;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileCubit>().loadProfile();
    });
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final data = await rootBundle.loadString('assets/data/countries.json');
      final list = List<String>.from(jsonDecode(data));
      if (mounted) setState(() => _countries = list);
    } catch (e) {
      debugPrint('_loadCountries error: $e');
      if (mounted) setState(() => _countries = [
        'France', 'United States', 'United Kingdom', 'Canada', 'Germany',
        'Spain', 'Italy', 'Portugal', 'Brazil', 'Morocco', 'Algeria', 'Tunisia',
        'Belgium', 'Switzerland', 'Netherlands', 'Sweden', 'Norway', 'Poland',
        'Japan', 'South Korea', 'China', 'India', 'Australia', 'Mexico',
        'Argentina', 'Colombia', 'Egypt', 'South Africa', 'Turkey', 'Russia',
      ]);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _pseudoCtrl.dispose();
    _bioCtrl.dispose();
    _langCtrl.dispose();
    _birthDateCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _githubCtrl.dispose();
    super.dispose();
  }

  void _syncFromState(ProfileState state) {
    if (_initialized) return;
    _initialized = true;
    _pseudoCtrl.text = state.pseudo;
    _bioCtrl.text = state.bio;
    _langCtrl.text = state.language;
    _birthDateCtrl.text = state.birthDate ?? '';
    _phoneCtrl.text = state.phone ?? '';
    _locationCtrl.text = state.location ?? '';
    _availability =
        state.availability.isNotEmpty ? state.availability : ProfileDefaults.availability;
    _gameType = state.gameType.isNotEmpty ? state.gameType : ProfileDefaults.gameType;
    _role = state.role.isNotEmpty ? state.role : ProfileDefaults.role;
    _region = state.region.isNotEmpty ? state.region : ProfileDefaults.region;
    _country = state.country.isNotEmpty ? state.country : ProfileDefaults.country;
    _favoriteGames = List.from(state.favoriteGames);
    _showEmail = state.showEmail;
    _showPhone = state.showPhone;
    _showLocation = state.showLocation;
    _instagramCtrl.text = state.socialInstagram;
    _facebookCtrl.text = state.socialFacebook;
    _githubCtrl.text = state.socialGithub;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _localImagePath = picked.path);
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      if (!mounted) return;
      context.read<ProfileCubit>().updateAvatar(bytes, ext);
    }
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(
          () => _birthDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _save(ProfileState state) {
    context.read<ProfileCubit>().saveProfile(
          pseudo: _pseudoCtrl.text.trim(),
          language:
              _langCtrl.text.trim().isEmpty ? 'fr' : _langCtrl.text.trim(),
          availability: _availability,
          gameType: _gameType,
          role: _role,
          region: _region,
          country: _country,
          bio: _bioCtrl.text.trim(),
          birthDate: _birthDateCtrl.text.trim().isEmpty
              ? null
              : _birthDateCtrl.text.trim(),
          favoriteGames: _favoriteGames,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          location: _locationCtrl.text.trim().isEmpty
              ? null
              : _locationCtrl.text.trim(),
          showEmail: _showEmail,
          showPhone: _showPhone,
          showLocation: _showLocation,
          socialInstagram: _instagramCtrl.text.trim(),
          socialFacebook: _facebookCtrl.text.trim(),
          socialGithub: _githubCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.savedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Profil mis à jour'),
              backgroundColor: Colors.green,
            ));
            context.read<ProfileCubit>().resetSavedSuccess();
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('❌ ${state.error!}'),
              backgroundColor: Colors.red,
            ));
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          _syncFromState(state);
          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(child: _buildHeader(context, state, theme)),
            ],
            body: Column(
              children: [
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textGrey,
                  tabs: const [
                    Tab(text: 'PROFIL'),
                    Tab(text: 'MODIFIER'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildViewTab(state, theme),
                      _buildEditTab(state, theme),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, ProfileState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
            bottom: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.2))),
      ),
      child: Column(
        children: [
          // Completion bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.completionPercent,
                    backgroundColor: AppTheme.bgColor,
                    valueColor: AlwaysStoppedAnimation(
                      state.completionPercent >= 0.8
                          ? AppTheme.tertiaryColor
                          : Colors.orangeAccent,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(state.completionPercent * 100).toInt()}%',
                style: TextStyle(
                  color: state.completionPercent >= 0.8
                      ? AppTheme.tertiaryColor
                      : Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Avatar + name row
          Row(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.bgColor,
                      backgroundImage: _localImagePath != null
                          ? FileImage(File(_localImagePath!)) as ImageProvider
                          : (state.avatarUrl != null &&
                                  state.avatarUrl!.isNotEmpty
                              ? NetworkImage(state.avatarUrl!)
                              : null),
                      child: (_localImagePath == null &&
                              (state.avatarUrl == null ||
                                  state.avatarUrl!.isEmpty))
                          ? Icon(Icons.person,
                              size: 44, color: AppTheme.textGrey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppTheme.cardColor, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 14, color: Color(0xFF3F008E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BlocBuilder<GamificationCubit, GamificationState>(
                          builder: (context, gState) {
                            final lvl = gState.progress?.level ?? 1;
                            return AnimatedBadge(level: lvl, size: 28);
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.pseudo.isNotEmpty
                                ? state.pseudo.toUpperCase()
                                : 'JOUEUR',
                            style: TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.gameType} • ${state.role} • ${state.country.isNotEmpty ? state.country : state.region}',
                      style: TextStyle(
                          color: AppTheme.primaryColor, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _badge('${state.xp} XP',
                            AppTheme.primaryColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ─── VIEW TAB ────────────────────────────────────────────────────────────────
  Widget _buildViewTab(ProfileState state, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Stats grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _statCard('NIVEAU', '${state.numericLevel}', Icons.star,
                AppTheme.tertiaryColor),
            _statCard(
                'AMIS', '${state.friendsCount}', Icons.people, AppTheme.tertiaryColor),
          ],
        ),
        const SizedBox(height: 24),

        // Contact info card (respects privacy settings)
        _sectionTitle('INFORMATIONS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Name always shown
              _infoRow(Icons.person, 'Pseudo', state.pseudo,
                  alwaysVisible: true),
              Divider(color: AppTheme.cardHighestColor),
              // Email — shown only if user opted in
              _infoRow(Icons.email, 'Email',
                  state.showEmail ? state.email : '••••••••',
                  locked: !state.showEmail),
              Divider(color: AppTheme.cardHighestColor),
              // Phone
              _infoRow(
                  Icons.phone,
                  'Téléphone',
                  state.showPhone
                      ? (state.phone?.isNotEmpty == true
                          ? state.phone!
                          : 'Non renseigné')
                      : '••••••••',
                  locked: !state.showPhone),
              Divider(color: AppTheme.cardHighestColor),
              // Location
              _infoRow(
                  Icons.location_on,
                  'Localisation',
                  state.showLocation
                      ? (state.location?.isNotEmpty == true
                          ? state.location!
                          : 'Non renseignée')
                      : '••••••••',
                  locked: !state.showLocation),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Social links
        _sectionTitle('RÉSEAUX'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _socialRow(Icons.camera_alt, 'Instagram', state.socialInstagram, 'https://instagram.com/'),
              Divider(color: AppTheme.cardHighestColor),
              _socialRow(Icons.facebook, 'Facebook', state.socialFacebook, 'https://facebook.com/'),
              Divider(color: AppTheme.cardHighestColor),
              _socialRow(Icons.code, 'GitHub', state.socialGithub, 'https://github.com/'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Bio
        if (state.bio.isNotEmpty) ...[
          _sectionTitle('BIO'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(state.bio,
                style: TextStyle(
                    color: AppTheme.textWhite, fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 24),
        ],

        // Favorite games
        if (state.favoriteGames.isNotEmpty) ...[
          _sectionTitle('JEUX FAVORIS'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.favoriteGames
                .map((g) => Chip(
                      label: Text(g,
                          style: TextStyle(
                              color: AppTheme.textWhite, fontSize: 12)),
                      backgroundColor: AppTheme.cardColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Other info
        _sectionTitle('DÉTAILS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _detailRow('Pays', state.country.isNotEmpty ? state.country : 'Non défini'),
              _detailRow('Disponibilité', state.availability),
              _detailRow('Langue', state.language.toUpperCase()),
              if (state.birthDate != null && state.birthDate!.isNotEmpty)
                _detailRow('Date de naissance', state.birthDate!),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          Text(label,
              style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool locked = false, bool alwaysVisible = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppTheme.textGrey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                      color: locked ? AppTheme.textGrey : AppTheme.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          if (locked && !alwaysVisible)
            Icon(Icons.lock_outline, color: AppTheme.textGrey, size: 16),
          if (alwaysVisible)
            Icon(Icons.public, color: AppTheme.tertiaryColor, size: 16),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _sectionTitle(String title) {
    return Text(title,
        style: TextStyle(
          color: AppTheme.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ));
  }

  Widget _socialRow(IconData icon, String label, String value, String baseUrl) {
    final isEmpty = value.isEmpty;
    final display = isEmpty ? 'Non renseigné' : value;
    return GestureDetector(
      onTap: isEmpty
          ? null
          : () {
              final url = value.startsWith('http') ? value : '$baseUrl$value';
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: AppTheme.textGrey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(display,
                      style: TextStyle(
                        color: isEmpty ? AppTheme.textGrey : AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: isEmpty ? null : TextDecoration.underline,
                      )),
                ],
              ),
            ),
            if (!isEmpty)
              Icon(Icons.open_in_new, color: AppTheme.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── EDIT TAB ────────────────────────────────────────────────────────────────
  Widget _buildEditTab(ProfileState state, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('IDENTITÉ (obligatoire)'),
        const SizedBox(height: 10),
        _field('Pseudo *', _pseudoCtrl, icon: Icons.person),
        const SizedBox(height: 16),
        _field('Bio', _bioCtrl, icon: Icons.notes, maxLines: 3),
        const SizedBox(height: 24),

        _sectionTitle('RÉSEAUX SOCIAUX'),
        const SizedBox(height: 10),
        _field('Instagram (URL ou pseudo)', _instagramCtrl, icon: Icons.camera_alt),
        const SizedBox(height: 12),
        _field('Facebook (URL ou pseudo)', _facebookCtrl, icon: Icons.facebook),
        const SizedBox(height: 12),
        _field('GitHub (URL ou pseudo)', _githubCtrl, icon: Icons.code),
        const SizedBox(height: 24),

        _sectionTitle('CONTACT & LOCALISATION'),
        const SizedBox(height: 10),
        // Email — read-only, shown from auth
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardHighColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.email, color: AppTheme.textGrey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email (compte)',
                        style:
                            TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                    Text(state.email,
                        style: TextStyle(
                            color: AppTheme.textWhite, fontSize: 14)),
                  ],
                ),
              ),
              Icon(Icons.lock, color: AppTheme.textGrey, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _privacyToggle(
          'Afficher l\'email aux autres joueurs',
          _showEmail,
          (v) => setState(() => _showEmail = v),
        ),
        const SizedBox(height: 16),
        _field('Numéro de téléphone', _phoneCtrl,
            icon: Icons.phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 8),
        _privacyToggle(
          'Afficher le téléphone aux autres joueurs',
          _showPhone,
          (v) => setState(() => _showPhone = v),
        ),
        const SizedBox(height: 16),
        _field('Localisation (ville / pays)', _locationCtrl,
            icon: Icons.location_on),
        const SizedBox(height: 8),
        _privacyToggle(
          'Afficher la localisation aux autres joueurs',
          _showLocation,
          (v) => setState(() => _showLocation = v),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.cardHighColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _countries.contains(_country) ? _country : null,
              hint: Text('Sélectionnez votre pays',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              isExpanded: true,
              dropdownColor: AppTheme.cardColor,
              style: TextStyle(color: AppTheme.textWhite, fontSize: 14),
              items: _countries.isEmpty
                  ? [const DropdownMenuItem(value: '', child: Text('Chargement...'))]
                  : _countries
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: _countries.isEmpty
                  ? null
                  : (v) {
                      if (v != null) setState(() => _country = v);
                    },
            ),
          ),
        ),
        const SizedBox(height: 24),

        _sectionTitle('GAMING'),
        const SizedBox(height: 10),
        Row(children: [
              Expanded(
                  child: _dropdown(
                      'Type de jeu',
                      _gameType,
                      ['FPS', 'MOBA', 'Battle Royale', 'MMO', 'RTS', 'RPG', 'Sports'],
                      (v) => setState(() => _gameType = v!))),
              const SizedBox(width: 12),
              Expanded(
                  child: _dropdown(
                      'Rôle',
                      _role,
                      ['Support', 'Dueliste', 'Tank', 'IGL', 'AWPer', 'Sniper', 'Flex'],
                      (v) => setState(() => _role = v!))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _dropdown(
                      'Région',
                      _region,
                      ['EU', 'NA', 'ASIA', 'OCE', 'SA', 'ME'],
                      (v) => setState(() => _region = v!))),
              const SizedBox(width: 12),
              Expanded(
                  child: _dropdown(
                      'Dispo',
                      _availability,
                      ['Soirée', 'Matin', 'Après-midi', 'Week-end', 'Nuit'],
                      (v) => setState(() => _availability = v!))),
            ]),
        const SizedBox(height: 12),
        _field('Langue', _langCtrl, icon: Icons.language),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _selectBirthDate,
          child: AbsorbPointer(
              child: _field('Date de naissance', _birthDateCtrl,
                  icon: Icons.cake)),
        ),
        const SizedBox(height: 24),

        _sectionTitle('JEUX FAVORIS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Valorant',
            'CS2',
            'LoL',
            'Apex',
            'Fortnite',
            'Dota 2',
            'Overwatch 2',
            'PUBG',
            'R6 Siege'
          ].map((g) {
            final sel = _favoriteGames.contains(g);
            return FilterChip(
              label: Text(g,
                  style: TextStyle(
                      color: sel ? Color(0xFF3F008E) : AppTheme.textWhite,
                      fontSize: 12)),
              selected: sel,
              onSelected: (_) => setState(() {
                sel ? _favoriteGames.remove(g) : _favoriteGames.add(g);
              }),
              selectedColor: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardColor,
              checkmarkColor: const Color(0xFF3F008E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: state.isSaving ? null : () => _save(state),
            icon: state.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF3F008E)))
                : const Icon(Icons.save),
            label: Text(
                state.isSaving ? 'Enregistrement...' : 'ENREGISTRER LE PROFIL',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _privacyToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardHighColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: value
                ? AppTheme.tertiaryColor.withValues(alpha: 0.4)
                : AppTheme.cardHighestColor),
      ),
      child: Row(
        children: [
          Icon(value ? Icons.visibility : Icons.visibility_off,
              color: value ? AppTheme.tertiaryColor : AppTheme.textGrey,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: value ? AppTheme.textWhite : AppTheme.textGrey,
                      fontSize: 13))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.tertiaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.textWhite),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.textGrey, size: 20)
            : null,
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    final safeValue = items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label),
      dropdownColor: AppTheme.cardColor,
      style: TextStyle(color: AppTheme.textWhite, fontSize: 14),
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}
