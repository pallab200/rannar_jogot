import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_license_screen.dart';
import '../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _contactDeveloper(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.developerEmail,
      queryParameters: {'subject': '${AppConstants.appName} Support'},
    );

    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email: ${AppConstants.developerEmail}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('About', style: theme.appBarTheme.titleTextStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${AppConstants.appVersion}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Offered by ${AppConstants.offeredBy}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: const Text('Developer'),
                  subtitle: Text(AppConstants.developerName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.business_rounded),
                  title: const Text('Offered by'),
                  subtitle: Text(AppConstants.offeredBy),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Contact Developer'),
                  subtitle: Text(AppConstants.developerEmail),
                  onTap: () => _contactDeveloper(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('About', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            '${AppConstants.appName} is offered by ${AppConstants.offeredBy} and developed by ${AppConstants.developerName}. The app helps users discover Bangladeshi cooking videos, while video content remains the property of its respective YouTube creators and channels.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('License & Notices'),
              subtitle: Text(
                '${AppConstants.developerName} • ${AppConstants.offeredBy}',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppLicenseScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
