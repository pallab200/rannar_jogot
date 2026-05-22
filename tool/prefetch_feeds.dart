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
  final stagingDir = Directory('${outputDir.path}_staging');
  await _deleteDirectoryIfExists(stagingDir);
  await stagingDir.create(recursive: true);

  final generatedAt = DateTime.now().toUtc();
  final youtubeService = YouTubeService();
  final searchIndex = <String, VideoModel>{};

  stdout.writeln(
    'Prefetching feeds to ${outputDir.path} '
    '(${AppConstants.maxResults} items/page, $pageCount pages/feed)...',
  );

  try {
    final latestSummary = await _prefetchFeed(
      rootDirectory: stagingDir,
      relativeSegments: const ['latest'],
      maxPages: pageCount,
      feedLabel: 'latest',
      generatedAt: generatedAt,
      onVideosFetched: (videos) => _addToSearchIndex(searchIndex, videos),
      fetchPage: (pageToken) => youtubeService.searchWithDetails(
        query: AppConstants.latestFeedQuery,
        maxResults: AppConstants.maxResults,
        pageToken: pageToken,
        order: 'date',
      ),
    );

    final trendingSummary = await _prefetchFeed(
      rootDirectory: stagingDir,
      relativeSegments: const ['trending'],
      maxPages: pageCount,
      feedLabel: 'trending',
      generatedAt: generatedAt,
      onVideosFetched: (videos) => _addToSearchIndex(searchIndex, videos),
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
          rootDirectory: stagingDir,
          relativeSegments: ['categories', categoryId],
          maxPages: pageCount,
          feedLabel: categoryId,
          generatedAt: generatedAt,
          onVideosFetched: (videos) => _addToSearchIndex(searchIndex, videos),
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

    await _writeSearchIndex(
      rootDirectory: stagingDir,
      generatedAt: generatedAt,
      searchIndex: searchIndex,
    );

    final manifestFile = File(_joinPath(stagingDir.path, ['manifest.json']));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    await _replaceDirectory(source: stagingDir, target: outputDir);

    stdout.writeln(
      'Prefetch complete. Manifest written to ${_joinPath(outputDir.path, ['manifest.json'])}',
    );
  } on YouTubeApiException catch (error) {
    await _deleteDirectoryIfExists(stagingDir);

    if (error.isQuotaExceeded) {
      stderr.writeln(
        'YouTube quota exceeded while refreshing feeds. '
        'Keeping any existing prefetched snapshots unchanged.',
      );

      if (!await outputDir.exists()) {
        stderr.writeln(
          'No existing prefetched snapshots are available yet. '
          'Run the workflow again after the YouTube quota resets.',
        );
      }

      return;
    }

    rethrow;
  } catch (_) {
    await _deleteDirectoryIfExists(stagingDir);
    rethrow;
  }
}

Future<Map<String, dynamic>> _prefetchFeed({
  required Directory rootDirectory,
  required List<String> relativeSegments,
  required int maxPages,
  required String feedLabel,
  required DateTime generatedAt,
  void Function(List<VideoModel> videos)? onVideosFetched,
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
    onVideosFetched?.call(videos);

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

void _addToSearchIndex(
  Map<String, VideoModel> searchIndex,
  List<VideoModel> videos,
) {
  for (final video in videos) {
    searchIndex.putIfAbsent(video.id, () => video);
  }
}

Future<void> _writeSearchIndex({
  required Directory rootDirectory,
  required DateTime generatedAt,
  required Map<String, VideoModel> searchIndex,
}) async {
  final searchDir = Directory(_joinPath(rootDirectory.path, ['search']));
  await searchDir.create(recursive: true);

  final videos = searchIndex.values.toList(growable: false)
    ..sort((left, right) => right.publishedAt.compareTo(left.publishedAt));

  final file = File(_joinPath(searchDir.path, ['index.json']));
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'generatedAt': generatedAt.toIso8601String(),
      'totalVideos': videos.length,
      'videos': videos.map((video) => video.toJson()).toList(),
    }),
  );
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

Future<void> _replaceDirectory({
  required Directory source,
  required Directory target,
}) async {
  await _deleteDirectoryIfExists(target);
  await source.rename(target.path);
}

Future<void> _deleteDirectoryIfExists(Directory directory) async {
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
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
