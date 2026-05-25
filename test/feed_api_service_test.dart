import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rannar_jogot/services/feed_api_service.dart';

void main() {
  test('parses a remote latest feed page', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://feeds.example.com/feeds/latest?page=2',
      );

      return http.Response(
        json.encode({
          'videos': [
            {
              'id': 'abc123',
              'title': 'Fresh recipe',
              'description': 'A new Bangladeshi cooking video',
              'thumbnailUrl': 'https://img.youtube.com/vi/abc123/hqdefault.jpg',
              'channelTitle': 'Cooking Channel',
              'channelId': 'channel-1',
              'publishedAt': '2026-05-20T10:00:00Z',
              'duration': '08:30',
              'viewCount': '1200',
              'likeCount': '33',
              'category': 'general',
              'isFavorite': false,
            },
            {
              'id': 'short123',
              'title': '#Shorts quick snack',
              'description': 'Fast short-form recipe',
              'thumbnailUrl': 'https://img.youtube.com/vi/short123/hqdefault.jpg',
              'channelTitle': 'Cooking Channel',
              'channelId': 'channel-1',
              'publishedAt': '2026-05-20T11:00:00Z',
              'duration': '00:45',
              'viewCount': '900',
              'likeCount': '12',
              'category': 'general',
              'isFavorite': false,
            },
          ],
          'nextPageToken': 'yt:CAoQAA',
          'totalResults': 2,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = FeedApiService(
      client: client,
      baseUrl: 'https://feeds.example.com/',
    );

    final result = await service.getLatestVideos(pageToken: '2');
    final videos = result?['videos'] as List<dynamic>;

    expect(videos, hasLength(1));
    expect(videos.first.id, 'abc123');
    expect(result?['nextPageToken'], 'yt:CAoQAA');
    expect(result?['totalResults'], 2);
  });

  test(
    'returns null when the remote feed base url is not configured',
    () async {
      final service = FeedApiService(baseUrl: '');

      final result = await service.getTrendingVideos();

      expect(result, isNull);
    },
  );
}
