import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/localization_provider.dart';
import '../services/cache_service.dart';
import '../utils/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CacheService _cacheService = CacheService();

  String _preferredLanguage = 'bn';
  bool _autoplayEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final preferredLanguage = await _cacheService.getPreferredLanguage();
    final autoplayEnabled = await _cacheService.isAutoplayEnabled();
    if (!mounted) {
      return;
    }

    setState(() {
      _preferredLanguage = preferredLanguage;
      _autoplayEnabled = autoplayEnabled;
      _isLoading = false;
    });
  }

  Future<void> _updatePreferredLanguage(String? value) async {
    if (value == null) {
      return;
    }

    final localizationProvider = context.read<LocalizationProvider>();
    await localizationProvider.setLanguage(value);

    if (!mounted) {
      return;
    }

    setState(() {
      _preferredLanguage = value;
    });
  }

  Future<void> _updateAutoplay(bool value) async {
    await _cacheService.setAutoplayEnabled(value);
    if (!mounted) {
      return;
    }

    setState(() {
      _autoplayEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        final lang = locProvider.currentLanguage;
        return Scaffold(
          appBar: AppBar(
            title: Text(AppStrings.getByLang('settings', lang), style: theme.appBarTheme.titleTextStyle),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(AppStrings.getByLang('appPreferences', lang), style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          Consumer<ThemeProvider>(
                            builder: (context, tp, _) => SwitchListTile.adaptive(
                              secondary: const Icon(Icons.dark_mode_rounded),
                              title: Text(AppStrings.getByLang('darkMode', lang)),
                              subtitle: Text(AppStrings.getByLang('darkModeSubtitle', lang)),
                              value: tp.isDarkMode,
                              onChanged: tp.setDarkMode,
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            child: DropdownButtonFormField<String>(
                              initialValue: _preferredLanguage,
                              decoration: InputDecoration(
                                labelText: AppStrings.getByLang('language', lang),
                                border: const OutlineInputBorder(),
                                helperText: AppStrings.getByLang('languageHelper', lang),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'bn',
                                  child: Text(AppStrings.getByLang('bangla', lang)),
                                ),
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text(AppStrings.getByLang('english', lang)),
                                ),
                              ],
                              onChanged: _updatePreferredLanguage,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(AppStrings.getByLang('playbackDefaults', lang), style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile.adaptive(
                        secondary: const Icon(Icons.play_circle_rounded),
                        title: Text(AppStrings.getByLang('autoplayVideos', lang)),
                        subtitle: Text(AppStrings.getByLang('autoplaySubtitle', lang)),
                        value: _autoplayEnabled,
                        onChanged: _updateAutoplay,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}