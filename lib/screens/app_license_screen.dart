import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';

class AppLicenseScreen extends StatefulWidget {
  const AppLicenseScreen({super.key});

  @override
  State<AppLicenseScreen> createState() => _AppLicenseScreenState();
}

class _AppLicenseScreenState extends State<AppLicenseScreen> {
  late final Future<List<_PackageLicenseGroup>> _licensesFuture =
      _loadLicenses();

  Future<List<_PackageLicenseGroup>> _loadLicenses() async {
    final groupedEntries = <String, List<LicenseEntry>>{};

    await for (final entry in LicenseRegistry.licenses) {
      for (final packageName in entry.packages) {
        groupedEntries
            .putIfAbsent(packageName, () => <LicenseEntry>[])
            .add(entry);
      }
    }

    final groupedLicenses =
        groupedEntries.entries
            .map(
              (entry) => _PackageLicenseGroup(
                packageName: entry.key,
                entries: entry.value,
              ),
            )
            .toList()
          ..sort(
            (left, right) => left.packageName.toLowerCase().compareTo(
              right.packageName.toLowerCase(),
            ),
          );

    return groupedLicenses;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final legalese =
        'Developed by ${AppConstants.developerName}\nContact: ${AppConstants.developerEmail}\nOffered by ${AppConstants.offeredBy}';

    return Scaffold(
      appBar: AppBar(title: const Text('Licenses')),
      body: FutureBuilder<List<_PackageLicenseGroup>>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load licenses right now.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final packages = snapshot.data ?? const <_PackageLicenseGroup>[];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length + 1,
            separatorBuilder: (_, index) =>
                index == 0 ? const SizedBox(height: 16) : const Divider(),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppConstants.appName,
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Version ${AppConstants.appVersion}',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          legalese,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final package = packages[index - 1];
              final licenseCount = package.entries.length;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(package.packageName),
                subtitle: Text(
                  licenseCount == 1
                      ? '1 license entry'
                      : '$licenseCount license entries',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AppLicenseDetailScreen(package: package),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AppLicenseDetailScreen extends StatelessWidget {
  const _AppLicenseDetailScreen({required this.package});

  final _PackageLicenseGroup package;

  List<LicenseParagraph> _collectParagraphs() {
    final paragraphs = <LicenseParagraph>[];

    for (final entry in package.entries) {
      paragraphs.addAll(entry.paragraphs);
    }

    return paragraphs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs = _collectParagraphs();

    return Scaffold(
      appBar: AppBar(title: Text(package.packageName)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: paragraphs.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final paragraph = paragraphs[index];
          final isCentered =
              paragraph.indent == LicenseParagraph.centeredIndent;
          final leftPadding = isCentered ? 0.0 : paragraph.indent * 16.0;

          return Padding(
            padding: EdgeInsets.only(left: leftPadding),
            child: SelectableText(
              paragraph.text,
              style: theme.textTheme.bodyMedium,
              textAlign: isCentered ? TextAlign.center : TextAlign.start,
            ),
          );
        },
      ),
    );
  }
}

class _PackageLicenseGroup {
  const _PackageLicenseGroup({
    required this.packageName,
    required this.entries,
  });

  final String packageName;
  final List<LicenseEntry> entries;
}
