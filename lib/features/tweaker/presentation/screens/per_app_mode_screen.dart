import 'package:flutter/material.dart';
import '../../../../core/services/android_tweaker_service.dart';
import '../../../../core/theme/app_theme.dart';

class PerAppModeScreen extends StatefulWidget {
  const PerAppModeScreen({super.key});

  @override
  State<PerAppModeScreen> createState() => _PerAppModeScreenState();
}

class _PerAppModeScreenState extends State<PerAppModeScreen> {
  List<InstalledApp> _apps = [];
  Map<String, int> _appModes = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AndroidTweakerService.getInstalledApps(),
        AndroidTweakerService.getAppModes(),
      ]);
      final apps = results[0] as List<InstalledApp>;
      final appModes = results[1] as List<AppMode>;
      if (mounted) {
        setState(() {
          _apps = apps;
          _appModes = {for (final am in appModes) am.packageName: am.mode};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _setAppMode(String packageName, int modeCode) async {
    await AndroidTweakerService.setAppMode(packageName, modeCode);
    _loadData();
  }

  Future<void> _removeAppMode(String packageName) async {
    await AndroidTweakerService.removeAppMode(packageName);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
        elevation: 0,
        title: Text('Mode par application', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: -1)),
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
                      Text('Erreur: $_error', style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : _apps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.apps, size: 48, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text('Aucune application trouvée', style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _apps.length,
                      itemBuilder: (ctx, i) {
                        final app = _apps[i];
                        final currentMode = _appModes[app.packageName];
                        return _buildAppTile(app, currentMode);
                      },
                    ),
    );
  }

  Widget _buildAppTile(InstalledApp app, int? currentMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showModePicker(app, currentMode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardHighColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentMode != null
                  ? AppTheme.primaryColor.withValues(alpha: 0.4)
                  : AppTheme.outlineColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    app.label.isNotEmpty ? app.label[0].toUpperCase() : '?',
                    style: TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.label, style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(currentMode != null
                        ? AndroidTweakerService.modeLabels[currentMode] ?? 'Auto'
                        : 'Aucun mode défini',
                        style: TextStyle(
                          color: currentMode != null ? AppTheme.primaryColor : AppTheme.textVariant,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              if (currentMode != null)
                GestureDetector(
                  onTap: () => _removeAppMode(app.packageName),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.textVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showModePicker(InstalledApp app, int? currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1729),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Mode pour ${app.label}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(app.packageName, style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 20),
            ...AndroidTweakerService.modeLabels.entries.map((entry) {
              final selected = currentMode == entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    if (entry.key == 0) {
                      _removeAppMode(app.packageName);
                    } else {
                      _setAppMode(app.packageName, entry.key);
                    }
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.cardHighColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppTheme.primaryColor : AppTheme.outlineColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Text(AndroidTweakerService.modeIcons[entry.key] ?? '⚙️', style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.value, style: TextStyle(color: selected ? AppTheme.primaryColor : Colors.white, fontWeight: FontWeight.w600)),
                              Text(_modeSubtitle(entry.key), style: TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22),
                        if (entry.key == 0 && currentMode == null)
                          Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _modeSubtitle(int mode) {
    switch (mode) {
      case 0: return 'Héritage du mode global';
      case 1: return 'Économie d\'énergie';
      case 2: return 'Équilibré';
      case 3: return 'Performances élevées';
      case 4: return 'Optimisé pour le gaming';
      default: return '';
    }
  }
}
