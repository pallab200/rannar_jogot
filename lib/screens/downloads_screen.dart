import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/video_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/localization_provider.dart';
import '../utils/app_strings.dart';
import 'favorites_screen.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<LocalizationProvider, FavoritesProvider>(
      builder: (context, locProvider, favoritesProvider, _) {
        final lang = locProvider.currentLanguage;
        final favorites = favoritesProvider.favorites;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppStrings.getByLang('downloads', lang),
              style: theme.appBarTheme.titleTextStyle,
            ),
          ),
          body: favorites.isEmpty
              ? _buildEmptyState(context, theme, lang)
              : Column(
                  children: [
                    _buildInfoBanner(theme, lang),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _savedVideosLabel(favorites.length, lang),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final video = favorites[index];
                          return _DownloadVideoTile(
                            video: video,
                            lang: lang,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(video: video),
                              ),
                            ),
                            onOpenInYouTube: () => _openInYouTube(
                              context,
                              video,
                              lang,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_for_offline_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.getByLang('noDownloads', lang),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.getByLang('downloadsTip', lang),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              ),
              icon: const Icon(Icons.favorite_rounded),
              label: Text(AppStrings.getByLang('goToFavorites', lang)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(ThemeData theme, String lang) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.getByLang('downloadsOfficialTitle', lang),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.getByLang('downloadsOfficialBody', lang),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _savedVideosLabel(int count, String lang) {
    if (lang == 'bn') {
      return '$count টি সেভ করা ভিডিও';
    }

    return '$count saved videos';
  }

  Future<void> _openInYouTube(
    BuildContext context,
    VideoModel video,
    String lang,
  ) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${video.id}');
    var launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    launched = launched || await launchUrl(uri);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.getByLang('unableToOpenYouTube', lang)),
        ),
      );
    }
  }
}

class _DownloadVideoTile extends StatelessWidget {
  final VideoModel video;
  final String lang;
  final VoidCallback onTap;
  final VoidCallback onOpenInYouTube;

  const _DownloadVideoTile({
    required this.video,
    required this.lang,
    required this.onTap,
    required this.onOpenInYouTube,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  video.thumbnailUrl,
                  width: 120,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 120,
                    height: 72,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      video.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (video.duration.isNotEmpty || video.timeAgo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        [video.duration, video.timeAgo]
                            .where((value) => value.isNotEmpty)
                            .join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: onOpenInYouTube,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(
                          AppStrings.getByLang('openInYouTube', lang),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}