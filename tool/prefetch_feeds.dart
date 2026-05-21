import 'dart:convert';
import 'dart:io';

import 'package:rannar_jogot/models/video_model.dart';
import 'package:rannar_jogot/services/youtube_service.dart';
import 'package:rannar_jogot/utils/constants.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final outputPath = _readOption(args, '--output') ?? 'prefetched_feeds';
  final pageCount = int.tryParse(
    _readOption(args, '--pages') ?? '${AppConstants.prefetchPageCount}',
  );

  if (pageCount == null || pageCount < 1) {
    stderr.writeln('The --pages option must be a positive integer.');
    exitCode = 64;
    return;
  }

  final outputDir = Directory(outputPath);
  await outputDir.create(recursive: true);

  final generatedAt = DateTime.now().toUtc();
  final youtubeService = YouTubeService();

  stdout.writeln(
    'Prefetching feeds to ${outputDir.path} '
    '(${AppConstants.maxResults} items/page, $pageCount pages/feed)...',
  );

  final latestSummary = await _prefetchFeed(
    rootDirectory: outputDir,
    relativeSegments: const ['latest'],
    maxPages: pageCount,
    feedLabel: 'latest',
    generatedAt: generatedAt,
    fetchPage: (pageToken) => youtubeService.searchWithDetails(
      query: AppConstants.latestFeedQuery,
      maxResults: AppConstants.maxResults,
      pageToken: pageToken,
      order: 'date',
    ),
  );

  final trendingSummary = await _prefetchFeed(
    rootDirectory: outputDir,
    relativeSegments: const ['trending'],
    maxPages: pageCount,
    feedLabel: 'trending',
    generatedAt: generatedAt,
    fetchPage: (pageToken) => youtubeService.getTrendingCookingVideos(
      maxResults: AppConstants.maxResults,
      pageToken: pageToken,
    ),
  );

  final categorySummaries = <Map<String, dynamic>>[];
  for (final category in CategoryData.categories) {
    final categoryId = category['id'] as String;
    stdout.writeln('Prefetching category: $categoryId');
    categorySummaries.add(
      await _prefetchFeed(
        rootDirectory: outputDir,
        relativeSegments: ['categories', categoryId],
        maxPages: pageCount,
        feedLabel: categoryId,
        generatedAt: generatedAt,
        fetchPage: (pageToken) => youtubeService.searchWithDetails(
          query: _buildCategoryQuery(category),
          maxResults: AppConstants.maxResults,
          pageToken: pageToken,
          order: 'date',
        ),
      ),
    );
  }

  final manifest = {
    'generatedAt': generatedAt.toIso8601String(),
    'pageSize': AppConstants.maxResults,
    'prefetchPages': pageCount,
    'feeds': {
      'latest': latestSummary,
      'trending': trendingSummary,
      'categories': categorySummaries,
    },
  };

  final manifestFile = File(_joinPath(outputDir.path, ['manifest.json']));
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );

  stdout.writeln('Prefetch complete. Manifest written to ${manifestFile.path}');
}

Future<Map<String, dynamic>> _prefetchFeed({
  required Directory rootDirectory,
  required List<String> relativeSegments,
  required int maxPages,
  required String feedLabel,
  required DateTime generatedAt,
  required Future<Map<String, dynamic>> Function(String? pageToken) fetchPage,
}) async {
  final targetDir = Directory(_joinPath(rootDirectory.path, relativeSegments));
  await targetDir.create(recursive: true);

  String? sourcePageToken;
  String? lastSourceToken;
  int writtenPages = 0;

  for (var page = 1; page <= maxPages; page++) {
    final result = await fetchPage(sourcePageToken);
    final videos = result['videos'] as List<VideoModel>;
    final nextSourceToken = result['nextPageToken'] as String?;

    final pagePayload = {
      'feed': feedLabel,
      'page': page,
      'generatedAt': generatedAt.toIso8601String(),
      'totalResults': result['totalResults'] ?? videos.length,
      'videos': videos.map((video) => video.toJson()).toList(),
      'nextPageToken': _publicNextPageToken(
        currentPage: page,
        maxPages: maxPages,
        sourceNextPageToken: nextSourceToken,
      ),
      'sourceNextPageToken': nextSourceToken,
    };

    final pageFile = File(_joinPath(targetDir.path, ['page-$page.json']));
    await pageFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(pagePayload),
    );

    writtenPages = page;
    lastSourceToken = nextSourceToken;
    sourcePageToken = nextSourceToken;

    if (nextSourceToken == null) {
      break;
    }
  }

  return {
    'id': feedLabel,
    'path': relativeSegments.join('/'),
    'pages': writtenPages,
    'continuationToken': lastSourceToken == null ? null : 'yt:$lastSourceToken',
  };
}

String? _publicNextPageToken({
  required int currentPage,
  required int maxPages,
  required String? sourceNextPageToken,
}) {
  if (sourceNextPageToken == null) {
    return null;
  }

  if (currentPage < maxPages) {
    return '${currentPage + 1}';
  }

  return 'yt:$sourceNextPageToken';
}

String _buildCategoryQuery(Map<String, dynamic> category) {
  final keywords = (category['keywords'] as List<dynamic>)
      .take(4)
      .map((keyword) => keyword.toString())
      .join(' ');
  return '${category['nameEn']} $keywords বাংলাদেশী রান্না recipe';
}

String? _readOption(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }

  return args[index + 1];
}

String _joinPath(String root, List<String> segments) {
  final buffer = StringBuffer(root);
  for (final segment in segments) {
    buffer
      ..write(Platform.pathSeparator)
      ..write(segment);
  }
  return buffer.toString();
}

void _printUsage() {
  stdout.writeln('Usage: dart run tool/prefetch_feeds.dart [options]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --output <dir>   Output directory for feed JSON files.');
  stdout.writeln(
    '  --pages <count>  Number of pages to prefetch per feed '
    '(default: ${AppConstants.prefetchPageCount}).',
  );
  stdout.writeln('  --help           Show this message.');
}
