import '../models/category_model.dart';
import '../utils/constants.dart';
import 'feed_api_service.dart';
import 'youtube_service.dart';

class VideoFeedService {
  VideoFeedService({
    FeedApiService? feedApiService,
    YouTubeService? youTubeService,
  }) : _feedApiService = feedApiService ?? FeedApiService(),
       _youTubeService = youTubeService ?? YouTubeService();

  final FeedApiService _feedApiService;
  final YouTubeService _youTubeService;

  Future<Map<String, dynamic>> getLatestVideos({String? pageToken}) async {
    if (_isDirectSourceToken(pageToken)) {
      return _fetchLatestFromYouTube(
        pageToken: _extractDirectSourceToken(pageToken),
      );
    }

    final remote = await _tryRemoteFeed(
      pageToken: pageToken,
      remoteLoader: (token) =>
          _feedApiService.getLatestVideos(pageToken: token),
    );
    if (remote != null) {
      return remote;
    }

    return _fetchLatestFromYouTube(pageToken: pageToken);
  }

  Future<Map<String, dynamic>> getTrendingVideos({String? pageToken}) async {
    if (_isDirectSourceToken(pageToken)) {
      return _fetchTrendingFromYouTube(
        pageToken: _extractDirectSourceToken(pageToken),
      );
    }

    final remote = await _tryRemoteFeed(
      pageToken: pageToken,
      remoteLoader: (token) =>
          _feedApiService.getTrendingVideos(pageToken: token),
    );
    if (remote != null) {
      return remote;
    }

    return _fetchTrendingFromYouTube(pageToken: pageToken);
  }

  Future<Map<String, dynamic>> getCategoryVideos(
    CategoryModel category, {
    String? pageToken,
  }) async {
    if (_isDirectSourceToken(pageToken)) {
      return _fetchCategoryFromYouTube(
        category,
        pageToken: _extractDirectSourceToken(pageToken),
      );
    }

    final remote = await _tryRemoteFeed(
      pageToken: pageToken,
      remoteLoader: (token) =>
          _feedApiService.getCategoryVideos(category.id, pageToken: token),
    );
    if (remote != null) {
      return remote;
    }

    return _fetchCategoryFromYouTube(category, pageToken: pageToken);
  }

  Future<Map<String, dynamic>> searchVideos({
    required String query,
    String? pageToken,
  }) {
    return _youTubeService.searchWithDetails(
      query: '$query বাংলাদেশী রান্না',
      maxResults: AppConstants.searchMaxResults,
      pageToken: pageToken,
    );
  }

  Future<Map<String, dynamic>?> _tryRemoteFeed({
    required String? pageToken,
    required Future<Map<String, dynamic>?> Function(String? pageToken)
    remoteLoader,
  }) async {
    if (!_feedApiService.isConfigured) {
      return null;
    }

    final remoteResult = await remoteLoader(pageToken);
    if (remoteResult != null) {
      return remoteResult;
    }

    if (_isRemotePageToken(pageToken)) {
      throw Exception('Failed to load remote feed page $pageToken.');
    }

    return null;
  }

  Future<Map<String, dynamic>> _fetchLatestFromYouTube({String? pageToken}) {
    return _youTubeService.searchWithDetails(
      query: AppConstants.latestFeedQuery,
      maxResults: AppConstants.maxResults,
      pageToken: pageToken,
      order: 'date',
    );
  }

  Future<Map<String, dynamic>> _fetchTrendingFromYouTube({String? pageToken}) {
    return _youTubeService.getTrendingCookingVideos(
      maxResults: AppConstants.maxResults,
      pageToken: pageToken,
    );
  }

  Future<Map<String, dynamic>> _fetchCategoryFromYouTube(
    CategoryModel category, {
    String? pageToken,
  }) {
    return _youTubeService.searchWithDetails(
      query: buildCategoryQuery(category),
      maxResults: AppConstants.maxResults,
      pageToken: pageToken,
      order: 'date',
    );
  }

  String buildCategoryQuery(CategoryModel category) {
    final keywords = category.keywords.take(4).join(' ');
    return '${category.nameEn} $keywords বাংলাদেশী রান্না recipe';
  }

  bool _isRemotePageToken(String? pageToken) {
    return pageToken != null && int.tryParse(pageToken) != null;
  }

  bool _isDirectSourceToken(String? pageToken) {
    return pageToken != null && pageToken.startsWith('yt:');
  }

  String? _extractDirectSourceToken(String? pageToken) {
    if (!_isDirectSourceToken(pageToken)) {
      return pageToken;
    }

    return pageToken!.substring(3);
  }
}
