import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import '../utils/constants.dart';

class CachedVideoFeed {
  const CachedVideoFeed({
    required this.videos,
    required this.nextPageToken,
    required this.hasContinuationState,
  });

  final List<VideoModel> videos;
  final String? nextPageToken;
  final bool hasContinuationState;
}

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();
  CacheService.test();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get prefs async {
    if (_prefs == null) await init();
    return _prefs!;
  }

  // ─── Video Caching ───────────────────────────────────────

  Future<void> cacheVideos(String key, List<VideoModel> videos) async {
    await cacheVideoFeed(key, videos: videos);
  }

  Future<void> cacheVideoFeed(
    String key, {
    required List<VideoModel> videos,
    String? nextPageToken,
  }) async {
    final p = await prefs;
    final sanitizedVideos = VideoModel.filterSupportedFeedVideos(videos);
    final data = {
      'version': AppConstants.videoCacheSchemaVersion,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'videos': sanitizedVideos.map((v) => v.toJson()).toList(),
      'nextPageToken': nextPageToken,
    };
    await p.setString('${AppConstants.cacheKeyPrefix}$key', json.encode(data));
  }

  Future<List<VideoModel>?> getCachedVideos(
    String key, {
    int? maxAgeMinutes,
  }) async {
    final cachedFeed = await getCachedVideoFeed(
      key,
      maxAgeMinutes: maxAgeMinutes,
    );
    return cachedFeed?.videos;
  }

  Future<CachedVideoFeed?> getCachedVideoFeed(
    String key, {
    int? maxAgeMinutes,
  }) async {
    final data = await _getValidCacheData(key, maxAgeMinutes: maxAgeMinutes);
    if (data == null) {
      return null;
    }

    final videosJson = data['videos'] as List<dynamic>? ?? const [];
    final videos = VideoModel.filterSupportedFeedVideos(
      videosJson.map((v) => VideoModel.fromJson(v as Map<String, dynamic>)),
    );
    return CachedVideoFeed(
      videos: videos,
      nextPageToken: data.containsKey('nextPageToken')
          ? data['nextPageToken'] as String?
          : null,
      hasContinuationState: data.containsKey('nextPageToken'),
    );
  }

  Future<Map<String, dynamic>?> _getValidCacheData(
    String key, {
    int? maxAgeMinutes,
  }) async {
    final p = await prefs;
    final storageKey = '${AppConstants.cacheKeyPrefix}$key';
    final cached = p.getString(storageKey);
    if (cached == null) return null;

    try {
      final data = json.decode(cached) as Map<String, dynamic>;
      final version = data['version'] as int? ?? 0;
      final timestamp = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (version != AppConstants.videoCacheSchemaVersion) {
        await p.remove(storageKey);
        return null;
      }

      // Check if cache is expired
      final ttlMinutes = maxAgeMinutes ?? AppConstants.cacheDurationMinutes;
      if (now - timestamp > ttlMinutes * 60 * 1000) {
        await p.remove(storageKey);
        return null;
      }

      return data;
    } catch (_) {
      await p.remove(storageKey);
      return null;
    }
  }

  // ─── Favorites ───────────────────────────────────────────

  Future<List<String>> getFavoriteIds() async {
    final p = await prefs;
    return p.getStringList(AppConstants.favoritesKey) ?? [];
  }

  Future<void> addFavorite(String videoId) async {
    final p = await prefs;
    final favorites = await getFavoriteIds();
    if (!favorites.contains(videoId)) {
      favorites.add(videoId);
      await p.setStringList(AppConstants.favoritesKey, favorites);
    }
  }

  Future<void> removeFavorite(String videoId) async {
    final p = await prefs;
    final favorites = await getFavoriteIds();
    favorites.remove(videoId);
    await p.setStringList(AppConstants.favoritesKey, favorites);
  }

  Future<bool> isFavorite(String videoId) async {
    final favorites = await getFavoriteIds();
    return favorites.contains(videoId);
  }

  // ─── Favorite Videos (full data) ─────────────────────────

  Future<void> saveFavoriteVideos(List<VideoModel> videos) async {
    final p = await prefs;
    final data = VideoModel.filterSupportedFeedVideos(
      videos,
    ).map((v) => v.toJson()).toList();
    await p.setString('favorite_videos_data', json.encode(data));
  }

  Future<List<VideoModel>> getFavoriteVideos() async {
    final p = await prefs;
    final cached = p.getString('favorite_videos_data');
    if (cached == null) return [];

    try {
      final data = json.decode(cached) as List<dynamic>;
      return VideoModel.filterSupportedFeedVideos(
        data.map((v) => VideoModel.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return [];
    }
  }

  // ─── Search History ──────────────────────────────────────

  Future<List<String>> getSearchHistory() async {
    final p = await prefs;
    return p.getStringList(AppConstants.searchHistoryKey) ?? [];
  }

  Future<void> addSearchQuery(String query) async {
    final p = await prefs;
    final history = await getSearchHistory();
    history.remove(query); // Remove if exists
    history.insert(0, query); // Add to front
    if (history.length > 10) {
      history.removeLast(); // Keep max 10
    }
    await p.setStringList(AppConstants.searchHistoryKey, history);
  }

  Future<void> clearSearchHistory() async {
    final p = await prefs;
    await p.remove(AppConstants.searchHistoryKey);
  }

  // ─── Watch History ──────────────────────────────────────

  Future<List<VideoModel>> getWatchHistory() async {
    final p = await prefs;
    final cached = p.getString(AppConstants.watchHistoryKey);
    if (cached == null) return [];

    try {
      final data = json.decode(cached) as List<dynamic>;
      return data.map((v) => VideoModel.fromJson(v as Map<String, dynamic>)).toList();
    } catch (_) {
      await p.remove(AppConstants.watchHistoryKey);
      return [];
    }
  }

  Future<void> addWatchVideo(VideoModel video) async {
    final p = await prefs;
    final history = await getWatchHistory();
    history.removeWhere((item) => item.id == video.id);
    history.insert(0, video);
    if (history.length > 30) {
      history.removeRange(30, history.length);
    }

    await p.setString(
      AppConstants.watchHistoryKey,
      json.encode(history.map((v) => v.toJson()).toList()),
    );
  }

  Future<void> clearWatchHistory() async {
    final p = await prefs;
    await p.remove(AppConstants.watchHistoryKey);
  }

  // ─── Theme ───────────────────────────────────────────────

  Future<bool> isDarkMode() async {
    final p = await prefs;
    return p.getBool(AppConstants.themeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final p = await prefs;
    await p.setBool(AppConstants.themeKey, value);
  }

  Future<String> getPreferredLanguage() async {
    final p = await prefs;
    final language = p.getString(AppConstants.preferredLanguageKey) ?? 'bn';
    return language == 'en' ? 'en' : 'bn';
  }

  Future<void> setPreferredLanguage(String value) async {
    final p = await prefs;
    await p.setString(
      AppConstants.preferredLanguageKey,
      value == 'en' ? 'en' : 'bn',
    );
  }

  Future<bool> isAutoplayEnabled() async {
    final p = await prefs;
    return p.getBool(AppConstants.autoPlayKey) ?? true;
  }

  Future<void> setAutoplayEnabled(bool value) async {
    final p = await prefs;
    await p.setBool(AppConstants.autoPlayKey, value);
  }
}
