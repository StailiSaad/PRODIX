import 'package:flutter/material.dart';
import '../../../../core/services/android_tweaker_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'per_app_mode_screen.dart';

class TweakerScreen extends StatefulWidget {
  const TweakerScreen({super.key});

  @override
  State<TweakerScreen> createState() => _TweakerScreenState();
}

class _TweakerScreenState extends State<TweakerScreen> {
  TweakerStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final status = await AndroidTweakerService.getStatus();
      if (mounted) setState(() { _status = status; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleEnabled(bool val) async {
    await AndroidTweakerService.setEnabled(val);
    _loadStatus();
  }

  Future<void> _setMode(int modeCode) async {
    await AndroidTweakerService.setMode(modeCode);
    _loadStatus();
  }

  Future<void> _toggleTouchBoost(bool val) async {
    await AndroidTweakerService.setTouchBoost(val);
    _loadStatus();
  }

  Future<void> _toggleStartOnBoot(bool val) async {
    await AndroidTweakerService.setStartOnBoot(val);
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
        elevation: 0,
        title: Text('Android Tweaker', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: -1)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Failed to load tweaker status', style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadStatus, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final status = _status!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassCard(theme, child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.speed, color: AppTheme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Android Tweaker V1', style: TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(status.isRunning ? 'Service actif' : 'Service inactif',
                            style: TextStyle(color: status.isRunning ? const Color(0xFF00E676) : AppTheme.textVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: status.serviceEnabled,
                    activeTrackColor: const Color(0xFF00E676),
                    onChanged: _toggleEnabled,
                  ),
                ],
              ),
              if (status.serviceEnabled && status.isRunning) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF00E676)),
                      const SizedBox(width: 4),
                      Text('Running — ${AndroidTweakerService.modeLabels[status.mode] ?? "Auto"}',
                          style: const TextStyle(color: Color(0xFF00E676), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ],
          )),
          const SizedBox(height: 16),

          if (status.serviceEnabled) ...[
            // ── Mode Selector ──
            _buildGlassCard(theme, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.tune, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('Performance Mode', style: TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                ...AndroidTweakerService.modeLabels.entries.map((entry) {
                  final selected = status.mode == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _setMode(entry.key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.cardHighColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppTheme.primaryColor : AppTheme.outlineColor.withValues(alpha: 0.2),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(AndroidTweakerService.modeIcons[entry.key] ?? '⚙️', style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.value,
                                      style: TextStyle(color: selected ? AppTheme.primaryColor : AppTheme.textWhite,
                                          fontWeight: FontWeight.w600, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(_modeDescription(entry.key),
                                      style: TextStyle(color: AppTheme.textVariant, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (selected)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.check, size: 14, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            )),
            const SizedBox(height: 16),

            // ── Options ──
            _buildGlassCard(theme, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.settings, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('Options', style: TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                _buildToggleOption(theme, Icons.touch_app, 'Touch Boost',
                    'Optimise la réactivité tactile pour les jeux',
                    status.touchBoostEnabled, _toggleTouchBoost),
                const Divider(color: Colors.white12, height: 1),
                _buildToggleOption(theme, Icons.power_settings_new, 'Start on Boot',
                    'Démarre automatiquement au redémarrage du téléphone',
                    status.startOnBoot, _toggleStartOnBoot),
              ],
            )),
            const SizedBox(height: 16),

            // ── Per-App Mode ──
            _buildGlassCard(theme, child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PerAppModeScreen()),
                ).then((_) => _loadStatus());
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.apps, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Spacer(),
                    Text('Mode par application', style: TextStyle(color: AppTheme.textWhite, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],

          // ── Root Status ──
          _buildGlassCard(theme, child: Row(
            children: [
              Icon(
                status.isRootAvailable ? Icons.security : Icons.security_update_good,
                color: status.isRootAvailable ? const Color(0xFF00E676) : AppTheme.textVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status.isRootAvailable ? 'Accès Root disponible' : 'Mode non-root',
                        style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
                    Text(status.isRootAvailable
                        ? 'Tweaker peut contrôler le CPU/GPU directement'
                        : 'Utilise Shizuku/ADB pour les optimisations',
                        style: TextStyle(color: AppTheme.textVariant, fontSize: 11)),
                  ],
                ),
              ),
            ],
          )),
          const SizedBox(height: 24),
        ],
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

  Widget _buildToggleOption(ThemeData theme, IconData icon, String label, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: AppTheme.textVariant, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF7C3AED),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _modeDescription(int mode) {
    switch (mode) {
      case 0: return 'Ajuste automatiquement selon l\'application en cours';
      case 1: return 'Économie d\'énergie maximale, réduit les performances';
      case 2: return 'Équilibre entre performance et autonomie';
      case 3: return 'Performances maximales pour les apps exigeantes';
      case 4: return 'Mode gaming avec optimisations GPU/CPU avancées';
      default: return '';
    }
  }
}
