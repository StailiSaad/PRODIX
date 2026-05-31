import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'package:flutter/services.dart' show rootBundle;
import '../../profile_cubit.dart';
import '../../../auth/auth_cubit.dart';
import '../../../gamification/gamification_cubit.dart';
import '../../../dashboard/presentation/screens/main_screen.dart';
import '../../../../core/config/profile_defaults.dart';

class ProfileSetupScreens extends StatefulWidget {
  const ProfileSetupScreens({super.key});

  @override
  State<ProfileSetupScreens> createState() => _ProfileSetupScreensState();
}

class _ProfileSetupScreensState extends State<ProfileSetupScreens> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Step 1
  final _gamertagCtrl = TextEditingController();
  String _region = ProfileDefaults.region;
  String _country = ProfileDefaults.country;
  String _language = ProfileDefaults.language;
  List<String> _countries = [];
  bool _countriesLoading = true;

  // Step 2
  String _role = '';
  final List<String> _favoriteGames = [];

  // Step 3
  final Map<String, bool> _days = {'M': false, 'T': false, 'W': false, 'Th': false, 'F': false, 'S': false, 'Su': false};
  final Map<String, bool> _timeRanges = {'Morning': false, 'Afternoon': false, 'Evening': false, 'Night': false};
  String _availability = ProfileDefaults.availability;

  // Step 4
  bool _voiceComms = false;
  double _banterLevel = 0;
  bool _competitive = false;
  String _gameType = ProfileDefaults.gameType;


  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final data = await rootBundle.loadString('assets/data/countries.json');
      final list = List<String>.from(jsonDecode(data));
      if (mounted) setState(() { _countries = list; _countriesLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _countriesLoading = false; });
    }
  }

  @override
  void dispose() {
    _gamertagCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    // Derive availability from day/times selections
    if (_timeRanges['Morning'] == true) {
      _availability = 'morning';
    } else if (_timeRanges['Afternoon'] == true) {
      _availability = 'afternoon';
    } else if (_timeRanges['Evening'] == true) {
      _availability = 'evening';
    } else if (_timeRanges['Night'] == true) {
      _availability = 'night';
    }

    await context.read<ProfileCubit>().saveProfile(
      pseudo: _gamertagCtrl.text,

      language: _language,
      availability: _availability,
      gameType: _gameType,
      role: _role.toLowerCase(),
      region: _region,
      country: _country,
      bio: ProfileDefaults.bio,
      favoriteGames: _favoriteGames,
    );
    context.read<AuthCubit>().completeOnboarding();
    context.read<GamificationCubit>().recordEvent('profile_completed');
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Complete profile setup
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background Atmospheric Glows
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 100)
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      blurRadius: 120)
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header & Progress
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: theme.colorScheme.onSurfaceVariant,
                            onPressed: _previousStep,
                          ),
                          Text(
                            'PRODIX',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              letterSpacing: -1,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            color: theme.colorScheme.onSurfaceVariant,
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const MainScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'STEP ${_currentStep + 1} OF $_totalSteps',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '${((_currentStep + 1) / _totalSteps * 100).toInt()}%',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_currentStep + 1) / _totalSteps,
                                backgroundColor: const Color(0xFF2D3449),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable swipe
                    onPageChanged: (index) {
                      setState(() {
                        _currentStep = index;
                      });
                    },
                    children: [
                      _buildStep1GeneralInfo(context),
                      _buildStep2GamingStats(context),
                      _buildStep3Availability(context),
                      _buildStep4Preferences(context),
                      _buildStep5Validation(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
      {required Widget child,
      required BuildContext context,
      EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E)
                .withValues(alpha: 0.6), // surface-container-low
            borderRadius: BorderRadius.circular(16),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              left: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.4)),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 32,
                offset: Offset(0, 8),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // --- STEP 1 ---
  Widget _buildStep1GeneralInfo(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'General Info',
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Establish your identity in the arena.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildGlassCard(
            context: context,
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: theme.colorScheme.primary, width: 2),
                    color: const Color(0xFF171F33),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.add_a_photo,
                        size: 40, color: Color(0xFFD2BBFF)),
                  ),
                ),
                const SizedBox(height: 32),

                // Fields
                _buildTextField(context, 'GAMERTAG', 'Enter your gaming alias',
                    Icons.sports_esports, controller: _gamertagCtrl),
                const SizedBox(height: 16),
                _buildCountryPicker(context),
                const SizedBox(height: 16),
                _buildDropdown(context, 'PRIMARY LANGUAGE', 'Select Language', Icons.translate,
                    _language, ['fr', 'en', 'es', 'de', 'ar', 'pt', 'jp'],
                    (v) { if (v != null) setState(() => _language = v); }),
                const SizedBox(height: 32),

                // Next Button
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('NEXT'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2 ---
  Widget _buildStep2GamingStats(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'Gaming Identity',
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us what you play and how well you play it.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildGlassCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Primary Games', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGameAvatar(context, 'VALORANT', _favoriteGames.contains('VALORANT'), onTap: () => setState(() => _toggleGame('VALORANT'))),
                    _buildGameAvatar(context, 'LOL', _favoriteGames.contains('LOL'), onTap: () => setState(() => _toggleGame('LOL'))),
                    _buildGameAvatar(context, 'CS2', _favoriteGames.contains('CS2'), onTap: () => setState(() => _toggleGame('CS2'))),
                    _buildGameAvatar(context, 'ADD', false, isAdd: true),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Valorant Profile',
                        style: theme.textTheme.headlineMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'EDITING',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                Text('MAIN ROLE',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRoleChip(context, 'Duelist', _role == 'Duelist', onTap: () => setState(() => _role = 'Duelist')),
                    _buildRoleChip(context, 'Initiator', _role == 'Initiator', onTap: () => setState(() => _role = 'Initiator')),
                    _buildRoleChip(context, 'Controller', _role == 'Controller', onTap: () => setState(() => _role = 'Controller')),
                    _buildRoleChip(context, 'Sentinel', _role == 'Sentinel', onTap: () => setState(() => _role = 'Sentinel')),
                  ],
                ),
                const SizedBox(height: 32),

                // Next Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _nextStep,
                      child: Text('SKIP FOR NOW',
                          style: TextStyle(color: theme.colorScheme.secondary)),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('CONTINUE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3 ---
  Widget _buildStep3Availability(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'When do you play?',
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Set your availability to find squadmates online when you are.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildGlassCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Active Days',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['M', 'T', 'W', 'Th', 'F', 'S', 'Su'].map((d) =>
                    _buildDayToggle(context, d, _days[d] ?? false, onTap: () => setState(() => _days[d] = !(_days[d] ?? false))),
                  ).toList(),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(Icons.schedule, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Time Ranges',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTimeRange(context, 'Morning', '06:00 - 12:00',
                    Icons.wb_twilight, _timeRanges['Morning'] ?? false, onTap: () => setState(() => _timeRanges['Morning'] = !(_timeRanges['Morning'] ?? false))),
                const SizedBox(height: 8),
                _buildTimeRange(context, 'Afternoon', '12:00 - 18:00',
                    Icons.light_mode, _timeRanges['Afternoon'] ?? false, onTap: () => setState(() => _timeRanges['Afternoon'] = !(_timeRanges['Afternoon'] ?? false))),
                const SizedBox(height: 8),
                _buildTimeRange(context, 'Evening', '18:00 - 00:00',
                    Icons.bedtime, _timeRanges['Evening'] ?? false, onTap: () => setState(() => _timeRanges['Evening'] = !(_timeRanges['Evening'] ?? false))),
                const SizedBox(height: 8),
                _buildTimeRange(context, 'Night', '00:00 - 06:00',
                    Icons.nightlight, _timeRanges['Night'] ?? false, onTap: () => setState(() => _timeRanges['Night'] = !(_timeRanges['Night'] ?? false))),
                const SizedBox(height: 32),

                // Next Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('CONTINUE'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 4 ---
  Widget _buildStep4Preferences(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'Preferences',
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Fine-tune your matchmaking to find the perfect squad.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildGlassCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GAMEPLAY INTENSITY',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildIntensityCard(context, 'Casual',
                            'For fun & vibes', Icons.sports_esports, !_competitive, onTap: () => setState(() { _competitive = false; _gameType = 'FPS'; }))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildIntensityCard(context, 'Competitive',
                            'Ranked & sweating', Icons.emoji_events, _competitive, onTap: () => setState(() { _competitive = true; _gameType = 'FPS'; }))),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF4A4455)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Voice Comms',
                              style: theme.textTheme.titleMedium),
                          Text('Mic required for matches',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      Switch(
                          value: _voiceComms,
                          onChanged: (v) => setState(() => _voiceComms = v),
                          activeThumbColor: theme.colorScheme.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF4A4455)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Banter Level',
                              style: theme.textTheme.titleMedium),
                          Text(_banterLevel == 1 ? 'Low' : _banterLevel == 2 ? 'Moderate' : 'High',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                          value: _banterLevel,
                          min: 1,
                          max: 3,
                          divisions: 2,
                          onChanged: (v) => setState(() => _banterLevel = v),
                          activeColor: theme.colorScheme.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Next Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _nextStep,
                    child: const Text('NEXT STEP'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 5 ---
  Widget _buildStep5Validation(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'Profile Ready',
            style: theme.textTheme.displaySmall
                ?.copyWith(color: theme.colorScheme.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your dossier is complete. Review before deployment.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildGlassCard(
            context: context,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        border: Border.all(
                            color: theme.colorScheme.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.5),
                            blurRadius: 20,
                          )
                        ],
                      ),
                      child: const Center(child: Icon(Icons.person, size: 60)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('ONLINE',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.onTertiary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('@${_gamertagCtrl.text.isEmpty ? "Player" : _gamertagCtrl.text}', style: theme.textTheme.headlineMedium),
                    const SizedBox(width: 4),
                    Icon(Icons.verified,
                        color: theme.colorScheme.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF4A4455)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_esports,
                          color: theme.colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text('${_favoriteGames.isNotEmpty ? _favoriteGames.first : "GAMER"} MAIN', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: _buildStatBlock(context, 'PAYS', _country.isNotEmpty ? _country : 'Non défini',
                            theme.colorScheme.primary)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildStatBlock(context, 'ROLE', _role,
                            theme.colorScheme.secondary)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildStatBlock(context, 'COMMS', _voiceComms ? 'ON' : 'OFF',
                            theme.colorScheme.tertiary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF0053DB)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                    blurRadius: 20,
                  )
                ],
              ),
              child:               ElevatedButton.icon(
                onPressed: _finishSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.bolt, color: Colors.white),
                label: Text('Activer mon profil',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildTextField(
      BuildContext context, String label, String hint, IconData icon, {TextEditingController? controller}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            fillColor: const Color(0xFF171F33),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryPicker(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAYS',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF171F33),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.public, color: Color(0xFF958DA1)),
              const SizedBox(width: 12),
              Expanded(
                child: _countriesLoading
                    ? const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _country.isNotEmpty && _countries.contains(_country) ? _country : null,
                          hint: Text('Select your country',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF958DA1))),
                          isExpanded: true,
                          items: _countries.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          )).toList(),
                          onChanged: (v) { if (v != null) setState(() => _country = v); },
                          dropdownColor: const Color(0xFF222A3D),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
      BuildContext context, String label, String hint, IconData icon,
      String value, List<String> items, ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF171F33),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF958DA1)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : null,
                    hint: Text(hint,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: const Color(0xFF958DA1))),
                    isExpanded: true,
                    items: items.map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase(), style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: onChanged,
                    dropdownColor: const Color(0xFF222A3D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleGame(String game) {
    setState(() {
      if (_favoriteGames.contains(game)) {
        _favoriteGames.remove(game);
      } else {
        _favoriteGames.add(game);
      }
    });
  }

  Widget _buildGameAvatar(BuildContext context, String label, bool active,
      {bool isAdd = false, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    active ? theme.colorScheme.primary : const Color(0xFF4A4455),
                width: active ? 2 : 1,
              ),
              color: const Color(0xFF171F33),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          blurRadius: 10)
                    ]
                  : null,
            ),
            child: isAdd
                ? Icon(Icons.add, color: theme.colorScheme.onSurfaceVariant)
                : Icon(Icons.sports_esports,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context, String label, bool active,
      {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
              color:
                  active ? theme.colorScheme.primary : const Color(0xFF4A4455)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDayToggle(BuildContext context, String label, bool active,
      {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 48,
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : const Color(0xFF222A3D),
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5))
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRange(BuildContext context, String label, String time,
      IconData icon, bool active, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : const Color(0xFF222A3D),
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5))
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : const Color(0xFF171F33),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      )),
                  Text(time,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: active
                            ? theme.colorScheme.primary.withValues(alpha: 0.8)
                            : theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            Icon(
              active ? Icons.check_box : Icons.check_box_outline_blank,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityCard(BuildContext context, String title,
      String subtitle, IconData icon, bool active, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2D3449) : Colors.transparent,
          border: Border.all(
              color:
                  active ? theme.colorScheme.primary : const Color(0xFF4A4455)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10)
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurface)),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock(
      BuildContext context, String label, String value, Color glowColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF060E20).withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: const Color(0xFFCCC3D8))),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: glowColor,
              shadows: [
                Shadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 8)
              ],
            ),
          ),
        ],
      ),
    );
  }
}
