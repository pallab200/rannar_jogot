import 'dart:convert';
import 'dart:io';

import 'package:rannar_jogot/models/video_model.dart';
import 'package:rannar_jogot/services/youtube_service.dart';
import 'package:rannar_jogot/utils/constants.dart';

const Duration _prefetchSearchRequestInterval = Duration(seconds: 12);
const Duration _prefetchRetryInitialDelay = Duration(seconds: 75);
const int _prefetchRetryMaxAttempts = 4;

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

  if (AppConstants.youtubeApiKey.trim().isEmpty) {
    stderr.writeln('YOUTUBE_API_KEY is not configured. Skipping feed refresh.');
    return;
  }

  final outputDir = Directory(outputPath);
  final stagingDir = Directory('${outputDir.path}_staging');
  await _deleteDirectoryIfExists(stagingDir);
  await stagingDir.create(recursive: true);

  final generatedAt = DateTime.now().toUtc();
  final youtubeService = YouTubeService();
  final searchIndex = <String, VideoModel>{};
  final requestRateLimiter = _PrefetchRequestRateLimiter(
    minimumInterval: _prefetchSearchRequestInterval,
  );

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
      requestRateLimiter: requestRateLimiter,
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
      requestRateLimiter: requestRateLimiter,
      onVideosFetched: (videos) => _addToSearchIndex(searchIndex, videos),
      fetchPage: (pageToken) => youtubeService.getTrendingCookingVideos(
        maxResults: AppConstants.maxResults,
        pageToken: pageToken,
      ),
    );

    final categorySummaries = await writeDerivedCategoryFeeds(
      rootDirectory: stagingDir,
      generatedAt: generatedAt,
      maxPages: pageCount,
      sourceVideos: searchIndex.values,
    );

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

    if (error.isQuotaLimited) {
      stderr.writeln(
        'YouTube ${error.isRateLimited ? 'rate limit' : 'quota'} exceeded '
        'while refreshing feeds. '
        'Keeping any existing prefetched snapshots unchanged.',
      );

      if (error.isRateLimited) {
        stderr.writeln(
          'The workflow already retried with backoff. '
          'Run it again after the minute-level limit resets if needed.',
        );
      }

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
  required _PrefetchRequestRateLimiter requestRateLimiter,
  void Function(List<VideoModel> videos)? onVideosFetched,
  required Future<Map<String, dynamic>> Function(String? pageToken) fetchPage,
}) async {
  final targetDir = Directory(_joinPath(rootDirectory.path, relativeSegments));
  await targetDir.create(recursive: true);

  String? sourcePageToken;
  String? lastSourceToken;
  int writtenPages = 0;

  for (var page = 1; page <= maxPages; page++) {
    await requestRateLimiter.waitForTurn();
    final result = await runWithYouTubeRateLimitRetry(
      operationLabel: '$feedLabel page $page',
      operation: () => fetchPage(sourcePageToken),
    );
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

Future<T> runWithYouTubeRateLimitRetry<T>({
  required String operationLabel,
  required Future<T> Function() operation,
  int maxAttempts = _prefetchRetryMaxAttempts,
  Duration initialDelay = _prefetchRetryInitialDelay,
  Future<void> Function(Duration duration)? sleeper,
}) async {
  final effectiveSleeper = sleeper ?? Future<void>.delayed;
  var delay = initialDelay;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } on YouTubeApiException catch (error) {
      final isFinalAttempt = attempt >= maxAttempts;
      if (!error.isRateLimited || isFinalAttempt) {
        rethrow;
      }

      stderr.writeln(
        'YouTube rate limit hit while fetching $operationLabel. '
        'Retrying in ${delay.inSeconds}s '
        '(attempt ${attempt + 1} of $maxAttempts).',
      );
      await effectiveSleeper(delay);
      delay *= 2;
    }
  }

  throw StateError('Unreachable retry loop for $operationLabel.');
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

Future<List<Map<String, dynamic>>> writeDerivedCategoryFeeds({
  required Directory rootDirectory,
  required DateTime generatedAt,
  required int maxPages,
  required Iterable<VideoModel> sourceVideos,
  List<Map<String, dynamic>>? categories,
}) async {
  final effectiveCategories = categories ?? CategoryData.categories;
  final categorizedVideos = _categorizeVideos(
    sourceVideos.toList(growable: false),
    categories: effectiveCategories,
  )..sort((left, right) => right.publishedAt.compareTo(left.publishedAt));

  final summaries = <Map<String, dynamic>>[];
  for (final category in effectiveCategories) {
    final categoryId = category['id'] as String;
    stdout.writeln('Building category feed: $categoryId');
    final categoryVideos = _getVideosByCategory(
      categorizedVideos,
      categoryId,
    );

    summaries.add(
      await _writeStaticFeedPages(
        rootDirectory: rootDirectory,
        relativeSegments: ['categories', categoryId],
        maxPages: maxPages,
        feedLabel: categoryId,
        generatedAt: generatedAt,
        videos: categoryVideos,
      ),
    );
  }

  return summaries;
}

Future<Map<String, dynamic>> _writeStaticFeedPages({
  required Directory rootDirectory,
  required List<String> relativeSegments,
  required int maxPages,
  required String feedLabel,
  required DateTime generatedAt,
  required List<VideoModel> videos,
}) async {
  final targetDir = Directory(_joinPath(rootDirectory.path, relativeSegments));
  await targetDir.create(recursive: true);

  final totalResults = videos.length;
  final cappedResults = totalResults > AppConstants.maxResults * maxPages
      ? AppConstants.maxResults * maxPages
      : totalResults;
  final limitedVideos = videos.take(cappedResults).toList(growable: false);
  final pageCount = (limitedVideos.length / AppConstants.maxResults).ceil();

  for (var page = 1; page <= pageCount; page++) {
    final start = (page - 1) * AppConstants.maxResults;
    final end = start + AppConstants.maxResults > limitedVideos.length
        ? limitedVideos.length
        : start + AppConstants.maxResults;
    final pageVideos = limitedVideos.sublist(start, end);

    final pagePayload = {
      'feed': feedLabel,
      'page': page,
      'generatedAt': generatedAt.toIso8601String(),
      'totalResults': totalResults,
      'videos': pageVideos.map((video) => video.toJson()).toList(),
      'nextPageToken': page < pageCount ? '${page + 1}' : null,
      'sourceNextPageToken': null,
    };

    final pageFile = File(_joinPath(targetDir.path, ['page-$page.json']));
    await pageFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(pagePayload),
    );
  }

  return {
    'id': feedLabel,
    'path': relativeSegments.join('/'),
    'pages': pageCount,
    'continuationToken': null,
  };
}

List<VideoModel> _categorizeVideos(
  List<VideoModel> videos, {
  required List<Map<String, dynamic>> categories,
}) {
  return videos.map((video) {
    final categoryId = _categorizeVideo(video, categories: categories);
    return video.copyWith(category: categoryId);
  }).toList(growable: false);
}

String _categorizeVideo(
  VideoModel video, {
  required List<Map<String, dynamic>> categories,
}) {
  final title = video.title.toLowerCase();
  final description = video.description.toLowerCase();
  final channel = video.channelTitle.toLowerCase();

  var bestCategory = 'general';
  var bestScore = 0.0;

  for (final category in categories) {
    final categoryId = category['id'] as String;
    final keywords = List<String>.from(category['keywords'] as List<dynamic>);
    var score = 0.0;

    for (final keyword in keywords) {
      final normalizedKeyword = keyword.toLowerCase();

      if (title.contains(normalizedKeyword)) {
        score += 3.0;
        if (
          RegExp(
            '\\b${RegExp.escape(normalizedKeyword)}\\b',
            caseSensitive: false,
          ).hasMatch(title)
        ) {
          score += 1.0;
        }
      }

      if (description.contains(normalizedKeyword)) {
        score += 1.0;
      }

      if (channel.contains(normalizedKeyword)) {
        score += 2.0;
      }
    }

    if (score > bestScore) {
      bestScore = score;
      bestCategory = categoryId;
    }
  }

  return bestScore < 2.0 ? 'general' : bestCategory;
}

List<VideoModel> _getVideosByCategory(
  List<VideoModel> allVideos,
  String categoryId,
) {
  if (categoryId == 'all') {
    return allVideos;
  }

  return allVideos
      .where((video) => video.category == categoryId)
      .toList(growable: false);
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

class _PrefetchRequestRateLimiter {
  _PrefetchRequestRateLimiter({
    required this.minimumInterval,
    DateTime Function()? clock,
    Future<void> Function(Duration duration)? sleeper,
  }) : _clock = clock ?? DateTime.now,
       _sleeper = sleeper ?? Future<void>.delayed;

  final Duration minimumInterval;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _sleeper;

  DateTime? _lastRequestStartedAt;

  Future<void> waitForTurn() async {
    if (_lastRequestStartedAt != null) {
      final elapsed = _clock().difference(_lastRequestStartedAt!);
      final remaining = minimumInterval - elapsed;
      if (remaining > Duration.zero) {
        await _sleeper(remaining);
      }
    }

    _lastRequestStartedAt = _clock();
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
