import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/video_model.dart';
import '../utils/constants.dart';

class FeedApiService {
  FeedApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalizeBaseUrl(baseUrl ?? AppConstants.feedApiBaseUrl);

  final http.Client _client;
  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<Map<String, dynamic>?> getLatestVideos({String? pageToken}) {
    return _fetchFeed(
      pathSegments: const ['feeds', 'latest'],
      pageToken: pageToken,
    );
  }

  Future<Map<String, dynamic>?> getTrendingVideos({String? pageToken}) {
    return _fetchFeed(
      pathSegments: const ['feeds', 'trending'],
      pageToken: pageToken,
    );
  }

  Future<Map<String, dynamic>?> getCategoryVideos(
    String categoryId, {
    String? pageToken,
  }) {
    return _fetchFeed(
      pathSegments: ['feeds', 'categories', categoryId],
      pageToken: pageToken,
    );
  }

  Future<Map<String, dynamic>?> _fetchFeed({
    required List<String> pathSegments,
    String? pageToken,
  }) async {
    if (!isConfigured) {
      return null;
    }

    final uri = _buildUri(pathSegments, pageToken: pageToken);

    try {
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final videosJson = data['videos'] as List<dynamic>? ?? const [];

      return {
        'videos': videosJson
            .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
            .toList(),
        'nextPageToken': data['nextPageToken']?.toString(),
        'totalResults': data['totalResults'] as int? ?? videosJson.length,
        'source': 'remote',
      };
    } catch (_) {
      return null;
    }
  }

  Uri _buildUri(List<String> pathSegments, {String? pageToken}) {
    final baseUri = Uri.parse(_baseUrl);
    final mergedSegments = [
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      ...pathSegments,
    ];

    return baseUri.replace(
      pathSegments: mergedSegments,
      queryParameters: <String, String>{
        'page': pageToken == null || pageToken.isEmpty ? '1' : pageToken,
      },
    );
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }
}
