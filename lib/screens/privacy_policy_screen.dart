import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/localization_provider.dart';
import '../utils/app_strings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        final lang = locProvider.currentLanguage;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppStrings.getByLang('privacyPolicy', lang),
              style: theme.appBarTheme.titleTextStyle,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.getByLang('privacyPolicy', lang),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.getByLang('privacyPolicySubtitle', lang),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              _PolicySection(
                title: AppStrings.getByLang('privacySummaryTitle', lang),
                body: AppStrings.getByLang('privacySummaryBody', lang),
              ),
              const SizedBox(height: 16),
              _PolicySection(
                title: AppStrings.getByLang('privacyYouTubeTitle', lang),
                body: AppStrings.getByLang('privacyYouTubeBody', lang),
              ),
              const SizedBox(height: 16),
              _PolicySection(
                title: AppStrings.getByLang('privacyAdsTitle', lang),
                body: AppStrings.getByLang('privacyAdsBody', lang),
              ),
              const SizedBox(height: 16),
              _PolicySection(
                title: AppStrings.getByLang('privacyControlTitle', lang),
                body: AppStrings.getByLang('privacyControlBody', lang),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}