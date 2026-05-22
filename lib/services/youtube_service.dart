import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_model.dart';
import '../utils/constants.dart';

class YouTubeApiException implements Exception {
  const YouTubeApiException({
    required this.statusCode,
    required this.message,
    this.reason,
    this.domain,
    required this.responseBody,
  });

  final int statusCode;
  final String message;
  final String? reason;
  final String? domain;
  final String responseBody;

  bool get isQuotaExceeded => reason == 'quotaExceeded';

  @override
  String toString() => 'YouTube API error: $statusCode - $message';
}

class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  /// Search YouTube for videos matching a query
  Future<Map<String, dynamic>> searchVideos({
    required String query,
    int maxResults = AppConstants.maxResults,
    String? pageToken,
    String order = 'relevance',
    DateTime? publishedAfter,
  }) async {
    final params = {
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': maxResults.toString(),
      'key': AppConstants.youtubeApiKey,
      'regionCode': 'BD',
      'relevanceLanguage': 'bn',
      'videoCategoryId': '26', // Howto & Style (includes cooking)
      'order': order,
      'videoEmbeddable': 'true',
      'videoSyndicated': 'true',
    };

    if (pageToken != null) {
      params['pageToken'] = pageToken;
    }

    if (publishedAfter != null) {
      params['publishedAfter'] = publishedAfter.toUtc().toIso8601String();
    }

    final uri = Uri.parse(
      '${AppConstants.youtubeBaseUrl}/search',
    ).replace(queryParameters: params);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        final videos = items
            .map(
              (item) => VideoModel.fromSearchJson(item as Map<String, dynamic>),
            )
            .where((v) => v.id.isNotEmpty)
            .toList();

        return {
          'videos': videos,
          'nextPageToken': data['nextPageToken'],
          'totalResults': data['pageInfo']?['totalResults'] ?? 0,
        };
      } else {
        throw _buildApiException(response);
      }
    } on YouTubeApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to search videos: $e');
    }
  }

  /// Get detailed video info (duration, view count, etc.)
  Future<List<VideoModel>> getVideoDetails(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];

    // API supports max 50 IDs per request
    final List<VideoModel> allVideos = [];
    for (var i = 0; i < videoIds.length; i += 50) {
      final batch = videoIds.sublist(
        i,
        i + 50 > videoIds.length ? videoIds.length : i + 50,
      );
      final params = {
        'part': 'snippet,contentDetails,statistics,status',
        'id': batch.join(','),
        'key': AppConstants.youtubeApiKey,
      };

      final uri = Uri.parse(
        '${AppConstants.youtubeBaseUrl}/videos',
      ).replace(queryParameters: params);

      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List<dynamic>? ?? [];
          final videos = items
              .where((item) => _isEmbeddableVideo(item as Map<String, dynamic>))
              .map(
                (item) =>
                    VideoModel.fromVideoJson(item as Map<String, dynamic>),
              )
              .toList();
          allVideos.addAll(videos);
        }
      } catch (e) {
        // Continue with partial results
      }
    }

    return allVideos;
  }

  /// Search and get full details in one call
  Future<Map<String, dynamic>> searchWithDetails({
    required String query,
    int maxResults = AppConstants.maxResults,
    String? pageToken,
    String order = 'relevance',
    DateTime? publishedAfter,
  }) async {
    final searchResult = await searchVideos(
      query: query,
      maxResults: maxResults,
      pageToken: pageToken,
      order: order,
      publishedAfter: publishedAfter,
    );

    final searchVideos_ = searchResult['videos'] as List<VideoModel>;
    final videoIds = searchVideos_.map((v) => v.id).toList();

    if (videoIds.isEmpty) {
      return searchResult;
    }

    final detailedVideos = await getVideoDetails(videoIds);

    return {
      'videos': detailedVideos,
      'nextPageToken': searchResult['nextPageToken'],
      'totalResults': searchResult['totalResults'],
    };
  }

  /// Fetch trending/popular cooking videos from Bangladesh
  Future<Map<String, dynamic>> getTrendingCookingVideos({
    int maxResults = AppConstants.maxResults,
    String? pageToken,
  }) {
    final recentCutoff = DateTime.now().subtract(const Duration(days: 30));

    return searchWithDetails(
      query: AppConstants.trendingFeedQuery,
      maxResults: maxResults,
      pageToken: pageToken,
      order: 'viewCount',
      publishedAfter: recentCutoff,
    );
  }

  Future<bool> isVideoEmbeddable(String videoId) async {
    if (videoId.isEmpty) return false;

    final params = {
      'part': 'status',
      'id': videoId,
      'key': AppConstants.youtubeApiKey,
    };

    final uri = Uri.parse(
      '${AppConstants.youtubeBaseUrl}/videos',
    ).replace(queryParameters: params);

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return false;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) {
        return false;
      }

      return _isEmbeddableVideo(items.first as Map<String, dynamic>);
    } catch (_) {
      return false;
    }
  }

  bool _isEmbeddableVideo(Map<String, dynamic> item) {
    final status = item['status'] as Map<String, dynamic>? ?? const {};
    return status['embeddable'] == true;
  }

  YouTubeApiException _buildApiException(http.Response response) {
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>? ?? const {};
      final errors = error['errors'] as List<dynamic>? ?? const [];
      final firstError = errors.isEmpty
          ? const <String, dynamic>{}
          : errors.first as Map<String, dynamic>;

      return YouTubeApiException(
        statusCode: response.statusCode,
        message: error['message']?.toString() ?? response.body,
        reason: firstError['reason']?.toString(),
        domain: firstError['domain']?.toString(),
        responseBody: response.body,
      );
    } catch (_) {
      return YouTubeApiException(
        statusCode: response.statusCode,
        message: response.body,
        responseBody: response.body,
      );
    }
  }
}
