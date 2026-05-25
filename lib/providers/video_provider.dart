import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';
import '../services/cache_service.dart';
import '../services/video_feed_service.dart';
import '../utils/constants.dart';

enum LoadingState { initial, loading, loaded, error }

class VideoProvider extends ChangeNotifier {
  VideoProvider({
    VideoFeedService? videoFeedService,
    CategoryService? categoryService,
    CacheService? cacheService,
  }) : _videoFeedService = videoFeedService ?? VideoFeedService(),
       _categoryService = categoryService ?? CategoryService(),
       _cacheService = cacheService ?? CacheService();

  final VideoFeedService _videoFeedService;
  final CategoryService _categoryService;
  final CacheService _cacheService;

  // State
  LoadingState _state = LoadingState.initial;
  LoadingState get state => _state;

  List<VideoModel> _allVideos = [];
  List<VideoModel> get allVideos => _allVideos;

  List<VideoModel> _trendingVideos = [];
  List<VideoModel> get trendingVideos => _trendingVideos;

  List<VideoModel> _searchResults = [];
  List<VideoModel> get searchResults => _searchResults;

  final Map<String, List<VideoModel>> _categoryVideos = {};

  List<CategoryModel> get categories => _categoryService.categories;

  String? _latestNextPageToken;
  String? _trendingNextPageToken;
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isLoadingMoreLatest = false;
  bool get isLoadingMoreLatest => _isLoadingMoreLatest;

  bool _isLoadingMoreTrending = false;
  bool get isLoadingMoreTrending => _isLoadingMoreTrending;

  bool _isLoadingMoreSearch = false;
  bool get isLoadingMore => _isLoadingMoreSearch;

  final Set<String> _categoryLoading = <String>{};
  final Map<String, String?> _categoryNextPageTokens = {};

  String _selectedCategory = 'all';
  String get selectedCategory => _selectedCategory;

  // Search state
  LoadingState _searchState = LoadingState.initial;
  LoadingState get searchState => _searchState;
  String? _searchNextPageToken;
  String _currentSearchQuery = '';

  /// Initialize — load all cooking videos
  Future<void> initialize() async {
    if (_state == LoadingState.loading) return;

    _state = LoadingState.loading;
    notifyListeners();

    try {
      final cachedLatest = await _cacheService.getCachedVideos(
        'all_videos',
        maxAgeMinutes: AppConstants.feedCacheDurationMinutes,
      );
      final cachedTrending = await _cacheService.getCachedVideos(
        'trending',
        maxAgeMinutes: AppConstants.feedCacheDurationMinutes,
      );

      if (cachedLatest != null && cachedLatest.isNotEmpty) {
        _allVideos = cachedLatest;
        if (cachedTrending != null && cachedTrending.isNotEmpty) {
          _trendingVideos = cachedTrending;
        }
        _categoryService.updateCategoryCounts(_allVideos);
        _state = LoadingState.loaded;
        notifyListeners();
        _refreshInBackground();
        return;
      }

      if (cachedTrending != null && cachedTrending.isNotEmpty) {
        _trendingVideos = cachedTrending;
      }

      await Future.wait([
        _primeLatestVideos(pageCount: AppConstants.initialLatestPageCount),
        _primeTrendingVideos(
          pageCount: AppConstants.initialTrendingPageCount,
        ),
      ]);

      _state = LoadingState.loaded;
      notifyListeners();
    } catch (e) {
      _errorMessage = _buildErrorMessage(e);
      _state = LoadingState.error;
      notifyListeners();
    }
  }

  Future<void> _fetchLatestVideos({required bool reset}) async {
    final result = await _videoFeedService.getLatestVideos(
      pageToken: reset ? null : _latestNextPageToken,
    );

    final fetchedVideos = _categoryService.categorizeVideos(
      result['videos'] as List<VideoModel>,
    );

    if (reset) {
      _allVideos = fetchedVideos;
    } else {
      _allVideos = _mergeUniqueVideos(_allVideos, fetchedVideos);
    }

    _latestNextPageToken = result['nextPageToken'] as String?;
    _categoryService.updateCategoryCounts(_allVideos);
    await _cacheService.cacheVideos('all_videos', _allVideos);
  }

  Future<void> _refreshInBackground() async {
    try {
      await Future.wait([
        _primeLatestVideos(pageCount: AppConstants.initialLatestPageCount),
        _primeTrendingVideos(
          pageCount: AppConstants.initialTrendingPageCount,
        ),
      ]);
      _state = LoadingState.loaded;
      notifyListeners();
    } catch (_) {
      // Keep cached data if refresh fails
    }
  }

  Future<void> _primeLatestVideos({required int pageCount}) async {
    for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      await _fetchLatestVideos(reset: pageIndex == 0);
      if (_latestNextPageToken == null) {
        break;
      }
    }
  }

  /// Fetch trending videos
  Future<void> fetchTrending({bool reset = false}) async {
    try {
      await _fetchTrendingVideos(reset: reset);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _primeTrendingVideos({required int pageCount}) async {
    for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      await _fetchTrendingVideos(reset: pageIndex == 0);
      if (_trendingNextPageToken == null) {
        break;
      }
    }
  }

  Future<void> _fetchTrendingVideos({required bool reset}) async {
    if (reset) {
      _trendingNextPageToken = null;
    }

    final result = await _videoFeedService.getTrendingVideos(
      pageToken: reset ? null : _trendingNextPageToken,
    );
    final fetchedVideos = _categoryService.categorizeVideos(
      result['videos'] as List<VideoModel>,
    );

    if (reset) {
      _trendingVideos = fetchedVideos;
    } else {
      _trendingVideos = _mergeUniqueVideos(_trendingVideos, fetchedVideos);
    }

    _trendingNextPageToken = result['nextPageToken'] as String?;
    await _cacheService.cacheVideos('trending', _trendingVideos);
  }

  Future<void> loadMoreTrending() async {
    if (_isLoadingMoreTrending || _trendingNextPageToken == null) return;

    _isLoadingMoreTrending = true;
    notifyListeners();

    try {
      await fetchTrending();
    } finally {
      _isLoadingMoreTrending = false;
      notifyListeners();
    }
  }

  /// Get videos for a specific category
  List<VideoModel> getVideosByCategory(String categoryId) {
    final seedVideos = _getSeedCategoryVideos(categoryId);
    final categoryFeed = _categoryVideos[categoryId];
    if (categoryFeed != null && categoryFeed.isNotEmpty) {
      return _mergeUniqueVideos(seedVideos, categoryFeed);
    }

    return seedVideos;
  }

  bool isLoadingCategory(String categoryId) =>
      _categoryLoading.contains(categoryId);

  bool hasMoreCategoryVideos(String categoryId) =>
      _categoryNextPageTokens.containsKey(categoryId) &&
      _categoryNextPageTokens[categoryId] != null;

  Future<void> ensureCategoryVideosLoaded(String categoryId) async {
    if (_categoryLoading.contains(categoryId)) return;
    if ((_categoryVideos[categoryId]?.isNotEmpty ?? false)) {
      await _restoreCategoryPaginationState(categoryId);
      return;
    }

    final cachedFeed = await _cacheService.getCachedVideoFeed(
      _categoryCacheKey(categoryId),
      maxAgeMinutes: AppConstants.feedCacheDurationMinutes,
    );
    if (cachedFeed != null && cachedFeed.videos.isNotEmpty) {
      _categoryVideos[categoryId] = _mergeUniqueVideos(
        _getSeedCategoryVideos(categoryId),
        cachedFeed.videos,
      );
      _categoryNextPageTokens[categoryId] = cachedFeed.nextPageToken;
      notifyListeners();

      if (cachedFeed.hasContinuationState) {
        return;
      }
    }

    await refreshCategoryVideos(categoryId);
  }

  Future<void> refreshCategoryVideos(String categoryId) async {
    await _fetchCategoryVideos(categoryId, reset: true);
  }

  Future<void> loadMoreCategoryVideos(String categoryId) async {
    if (_categoryLoading.contains(categoryId)) return;
    await _restoreCategoryPaginationState(categoryId);
    if (_categoryLoading.contains(categoryId)) return;
    if (_categoryNextPageTokens[categoryId] == null) return;

    await _fetchCategoryVideos(categoryId, reset: false);
  }

  Future<void> _restoreCategoryPaginationState(String categoryId) async {
    if (_categoryLoading.contains(categoryId)) return;
    if (_categoryNextPageTokens.containsKey(categoryId)) return;

    final cachedFeed = await _cacheService.getCachedVideoFeed(
      _categoryCacheKey(categoryId),
      maxAgeMinutes: AppConstants.feedCacheDurationMinutes,
    );

    if (cachedFeed != null && cachedFeed.hasContinuationState) {
      _categoryNextPageTokens[categoryId] = cachedFeed.nextPageToken;
      notifyListeners();
      return;
    }

    if (_categoryVideos[categoryId]?.isNotEmpty ?? false) {
      await _fetchCategoryVideos(categoryId, reset: true);
    }
  }

  Future<void> _fetchCategoryVideos(
    String categoryId, {
    required bool reset,
  }) async {
    final category = _categoryService.getCategoryById(categoryId);
    if (category == null) return;

    _categoryLoading.add(categoryId);
    if (reset) {
      _categoryNextPageTokens[categoryId] = null;
    }
    notifyListeners();

    try {
      final result = await _videoFeedService.getCategoryVideos(
        category,
        pageToken: reset ? null : _categoryNextPageTokens[categoryId],
      );
      final seedVideos = _getSeedCategoryVideos(categoryId);
      final fetchedVideos = (result['videos'] as List<VideoModel>)
          .map((video) => video.copyWith(category: categoryId))
          .toList();

      if (reset) {
        _categoryVideos[categoryId] = _mergeUniqueVideos(
          seedVideos,
          fetchedVideos,
        );
      } else {
        _categoryVideos[categoryId] = _mergeUniqueVideos(
          _categoryVideos[categoryId] ?? const [],
          fetchedVideos,
        );
      }

      _categoryNextPageTokens[categoryId] = result['nextPageToken'] as String?;
      await _cacheService.cacheVideoFeed(
        _categoryCacheKey(categoryId),
        videos: _categoryVideos[categoryId] ?? fetchedVideos,
        nextPageToken: _categoryNextPageTokens[categoryId],
      );
    } catch (_) {
      if (reset) {
        _categoryVideos[categoryId] = _getSeedCategoryVideos(categoryId);
      }
    } finally {
      _categoryLoading.remove(categoryId);
      notifyListeners();
    }
  }

  String _categoryCacheKey(String categoryId) => 'category_$categoryId';

  List<VideoModel> _getSeedCategoryVideos(String categoryId) {
    final localMatches = _categoryService.getVideosByCategory(
      _allVideos,
      categoryId,
    );
    final trendingMatches = _categoryService.getVideosByCategory(
      _trendingVideos,
      categoryId,
    );
    return _mergeUniqueVideos(localMatches, trendingMatches);
  }

  List<VideoModel> _mergeUniqueVideos(
    List<VideoModel> existing,
    List<VideoModel> incoming,
  ) {
    final seenIds = existing.map((video) => video.id).toSet();
    final merged = List<VideoModel>.from(existing);

    for (final video in incoming) {
      if (seenIds.add(video.id)) {
        merged.add(video);
      }
    }

    return merged;
  }

  bool get hasMoreLatestVideos => _latestNextPageToken != null;

  bool get hasMoreTrendingVideos => _trendingNextPageToken != null;

  Future<void> loadMoreLatestVideos() async {
    if (_isLoadingMoreLatest || _latestNextPageToken == null) return;

    _isLoadingMoreLatest = true;
    notifyListeners();

    try {
      await _fetchLatestVideos(reset: false);
    } catch (_) {
      // Keep existing results if pagination fails.
    }

    _isLoadingMoreLatest = false;
    notifyListeners();
  }

  Future<void> loadMoreVideos() async {
    await loadMoreLatestVideos();
  }

  /// Select category filter
  void selectCategory(String categoryId) {
    _selectedCategory = categoryId;
    notifyListeners();
  }

  /// Get currently filtered videos
  List<VideoModel> get filteredVideos {
    if (_selectedCategory == 'all') return _allVideos;
    return _allVideos.where((v) => v.category == _selectedCategory).toList();
  }

  /// Search for videos
  Future<void> searchVideos(String query) async {
    if (query.trim().isEmpty) return;

    _searchState = LoadingState.loading;
    _currentSearchQuery = query;
    _searchResults = [];
    _searchNextPageToken = null;
    notifyListeners();

    try {
      // Save to history
      await _cacheService.addSearchQuery(query);

      final normalizedQuery = query.trim();
      final result = await _videoFeedService.searchVideos(
        query: normalizedQuery,
      );

      _searchResults = _categoryService.categorizeVideos(
        result['videos'] as List<VideoModel>,
      );
      _searchNextPageToken = result['nextPageToken'] as String?;
      _searchState = LoadingState.loaded;
    } catch (e) {
      _errorMessage = _buildErrorMessage(e);
      _searchState = LoadingState.error;
    }
    notifyListeners();
  }

  /// Load more search results
  Future<void> loadMoreSearchResults() async {
    if (_isLoadingMoreSearch || _searchNextPageToken == null) return;

    _isLoadingMoreSearch = true;
    notifyListeners();

    try {
      final result = await _videoFeedService.searchVideos(
        query: _currentSearchQuery,
        pageToken: _searchNextPageToken,
      );

      final newVideos = _categoryService.categorizeVideos(
        result['videos'] as List<VideoModel>,
      );
      _searchResults = _mergeUniqueVideos(_searchResults, newVideos);
      _searchNextPageToken = result['nextPageToken'] as String?;
    } catch (_) {}

    _isLoadingMoreSearch = false;
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    _state = LoadingState.loading;
    _categoryVideos.clear();
    _categoryNextPageTokens.clear();
    notifyListeners();

    try {
      await Future.wait([
        _primeLatestVideos(pageCount: AppConstants.initialLatestPageCount),
        _primeTrendingVideos(
          pageCount: AppConstants.initialTrendingPageCount,
        ),
      ]);
      _state = LoadingState.loaded;
    } catch (e) {
      _errorMessage = _buildErrorMessage(e);
      _state = LoadingState.error;
    }

    notifyListeners();
  }

  String _buildErrorMessage(Object error) {
    final rawMessage = error.toString();
    final normalized = rawMessage.toLowerCase();

    if (_looksLikeConnectivityIssue(normalized)) {
      return 'No internet connection. Please check your connection and try again.';
    }

    if (normalized.contains('quotaexceeded') ||
        normalized.contains('exceeded your quota')) {
      return 'Video service quota is exhausted right now. Please try again later.';
    }

    if (normalized.contains('public prefetched feed is unavailable') ||
        normalized.contains('public feed search is unavailable')) {
      return 'Content is still publishing from GitHub. Please try again in a few minutes.';
    }

    if (normalized.contains('youtube api error: 403') ||
        normalized.contains('forbidden') ||
        normalized.contains('api key')) {
      return 'Video service is unavailable right now. Please try again later.';
    }

    return 'Unable to load videos right now. Please try again.';
  }

  bool _looksLikeConnectivityIssue(String normalizedMessage) {
    return normalizedMessage.contains('socketexception') ||
        normalizedMessage.contains('failed host lookup') ||
        normalizedMessage.contains('connection closed') ||
        normalizedMessage.contains('network is unreachable') ||
        normalizedMessage.contains('connection refused') ||
        normalizedMessage.contains('timed out') ||
        normalizedMessage.contains('clientexception');
  }

  /// Get search history
  Future<List<String>> getSearchHistory() {
    return _cacheService.getSearchHistory();
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    await _cacheService.clearSearchHistory();
    notifyListeners();
  }

  /// Get a category model by id
  CategoryModel? getCategoryById(String id) {
    return _categoryService.getCategoryById(id);
  }
}
