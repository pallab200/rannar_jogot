import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rannar_jogot/models/video_model.dart';
import 'package:rannar_jogot/services/youtube_service.dart';

import '../tool/prefetch_feeds.dart' as prefetch;

void main() {
  test('YouTubeApiException detects minute-level rate limits', () {
    const error = YouTubeApiException(
      statusCode: 429,
      message:
          'Quota exceeded for quota metric Search Queries per minute of service youtube.googleapis.com.',
      responseBody: '{}',
    );

    expect(error.isRateLimited, isTrue);
    expect(error.isQuotaLimited, isTrue);
  });

  test('runWithYouTubeRateLimitRetry retries transient rate limits', () async {
    final delays = <Duration>[];
    var attemptCount = 0;

    final result = await prefetch.runWithYouTubeRateLimitRetry<int>(
      operationLabel: 'latest page 1',
      maxAttempts: 3,
      initialDelay: const Duration(seconds: 2),
      sleeper: (duration) async => delays.add(duration),
      operation: () async {
        attemptCount += 1;
        if (attemptCount < 3) {
          throw const YouTubeApiException(
            statusCode: 429,
            message: 'Search Queries per minute exceeded.',
            reason: 'rateLimitExceeded',
            responseBody: '{}',
          );
        }

        return 99;
      },
    );

    expect(result, 99);
    expect(attemptCount, 3);
    expect(delays, <Duration>[const Duration(seconds: 2), const Duration(seconds: 4)]);
  });

  test('writeDerivedCategoryFeeds builds category files from existing videos', () async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'prefetch-derived-category-test',
    );
    addTearDown(() async {
      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    final summaries = await prefetch.writeDerivedCategoryFeeds(
      rootDirectory: rootDirectory,
      generatedAt: DateTime.parse('2026-05-25T00:00:00Z'),
      maxPages: 3,
      sourceVideos: <VideoModel>[
        _buildVideo(
          id: 'fish-1',
          title: 'Ilish fish curry recipe',
          description: 'Traditional fish curry tutorial',
        ),
        _buildVideo(
          id: 'meat-1',
          title: 'Chicken roast recipe',
          description: 'Bangla chicken cooking',
        ),
      ],
    );

    final fishPage = File(
      '${rootDirectory.path}${Platform.pathSeparator}categories${Platform.pathSeparator}fish${Platform.pathSeparator}page-1.json',
    );
    final meatPage = File(
      '${rootDirectory.path}${Platform.pathSeparator}categories${Platform.pathSeparator}meat${Platform.pathSeparator}page-1.json',
    );

    expect(await fishPage.exists(), isTrue);
    expect(await meatPage.exists(), isTrue);
    expect(
      summaries.firstWhere((summary) => summary['id'] == 'fish')['pages'],
      1,
    );
    expect(
      summaries.firstWhere((summary) => summary['id'] == 'meat')['pages'],
      1,
    );
  });
}

VideoModel _buildVideo({
  required String id,
  required String title,
  required String description,
}) {
  return VideoModel(
    id: id,
    title: title,
    description: description,
    thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
    channelTitle: 'Cooking Channel',
    channelId: 'channel-1',
    publishedAt: '2026-05-20T10:00:00Z',
    duration: '08:30',
  );
}