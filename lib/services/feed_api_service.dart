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
  List<VideoModel>? _searchIndexCache;

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

  Future<Map<String, dynamic>?> searchVideos({
    required String query,
    String? pageToken,
  }) async {
    if (!isConfigured) {
      return null;
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return {
        'videos': const <VideoModel>[],
        'nextPageToken': null,
        'totalResults': 0,
        'source': 'remote',
      };
    }

    final searchIndex = await _loadSearchIndex();
    if (searchIndex == null) {
      return null;
    }

    final filteredVideos = searchIndex
        .where((video) => _matchesSearch(video, trimmedQuery))
        .toList(growable: false);

    final page = int.tryParse(pageToken ?? '1') ?? 1;
    final start = (page - 1) * AppConstants.searchMaxResults;
    if (start >= filteredVideos.length) {
      return {
        'videos': const <VideoModel>[],
        'nextPageToken': null,
        'totalResults': filteredVideos.length,
        'source': 'remote',
      };
    }

    final end = start + AppConstants.searchMaxResults > filteredVideos.length
        ? filteredVideos.length
        : start + AppConstants.searchMaxResults;

    return {
      'videos': filteredVideos.sublist(start, end),
      'nextPageToken': end < filteredVideos.length ? '${page + 1}' : null,
      'totalResults': filteredVideos.length,
      'source': 'remote',
    };
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

  Future<List<VideoModel>?> _loadSearchIndex() async {
    if (_searchIndexCache != null) {
      return _searchIndexCache;
    }

    final uri = _buildSearchIndexUri();

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
      _searchIndexCache = videosJson
          .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      return _searchIndexCache;
    } catch (_) {
      return null;
    }
  }

  Uri _buildUri(List<String> pathSegments, {String? pageToken}) {
    final baseUri = Uri.parse(_baseUrl);

    if (_usesStaticFeedFiles(baseUri)) {
      return _buildStaticFeedUri(baseUri, pathSegments, pageToken: pageToken);
    }

    return _buildServerFeedUri(baseUri, pathSegments, pageToken: pageToken);
  }

  Uri _buildSearchIndexUri() {
    final baseUri = Uri.parse(_baseUrl);

    if (_usesStaticFeedFiles(baseUri)) {
      return baseUri.replace(
        pathSegments: [
          ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
          'search',
          'index.json',
        ],
      );
    }

    return baseUri.replace(
      pathSegments: [
        ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        'feeds',
        'search-index',
      ],
    );
  }

  Uri _buildServerFeedUri(
    Uri baseUri,
    List<String> pathSegments, {
    String? pageToken,
  }) {
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

  Uri _buildStaticFeedUri(
    Uri baseUri,
    List<String> pathSegments, {
    String? pageToken,
  }) {
    final page = pageToken == null || pageToken.isEmpty ? '1' : pageToken;
    final mergedSegments = [
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      ..._resolveStaticPathSegments(pathSegments, page),
    ];

    return baseUri.replace(pathSegments: mergedSegments);
  }

  List<String> _resolveStaticPathSegments(
    List<String> pathSegments,
    String page,
  ) {
    if (pathSegments.length == 2 && pathSegments[0] == 'feeds') {
      final feedName = pathSegments[1];
      if (feedName == 'latest' || feedName == 'trending') {
        return [feedName, 'page-$page.json'];
      }

      if (feedName == 'manifest') {
        return ['manifest.json'];
      }
    }

    if (pathSegments.length == 3 &&
        pathSegments[0] == 'feeds' &&
        pathSegments[1] == 'categories') {
      return ['categories', pathSegments[2], 'page-$page.json'];
    }

    throw ArgumentError('Unsupported feed path: ${pathSegments.join('/')}');
  }

  bool _usesStaticFeedFiles(Uri baseUri) {
    return baseUri.host == 'raw.githubusercontent.com' ||
        baseUri.host.endsWith('github.io') ||
        baseUri.pathSegments.contains('prefetched_feeds');
  }

  bool _matchesSearch(VideoModel video, String query) {
    final normalizedQueryTerms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final haystack = [
      video.title,
      video.description,
      video.channelTitle,
      video.category,
    ].join(' ').toLowerCase();

    return normalizedQueryTerms.every(haystack.contains);
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }
}
