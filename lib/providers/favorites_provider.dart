import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../services/cache_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final CacheService _cacheService = CacheService();

  List<VideoModel> _favorites = [];
  List<VideoModel> get favorites => _favorites;

  Set<String> _favoriteIds = {};
  Set<String> get favoriteIds => _favoriteIds;

  bool _isLoaded = false;

  /// Initialize favorites from cache
  Future<void> initialize() async {
    if (_isLoaded) return;

    final ids = await _cacheService.getFavoriteIds();
    _favoriteIds = ids.toSet();
    _favorites = await _cacheService.getFavoriteVideos();
    _isLoaded = true;
    notifyListeners();
  }

  /// Check if a video is in favorites
  bool isFavorite(String videoId) {
    return _favoriteIds.contains(videoId);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(VideoModel video) async {
    if (_favoriteIds.contains(video.id)) {
      // Remove from favorites
      _favoriteIds.remove(video.id);
      _favorites.removeWhere((v) => v.id == video.id);
      await _cacheService.removeFavorite(video.id);
    } else {
      // Add to favorites
      _favoriteIds.add(video.id);
      final favVideo = video.copyWith(isFavorite: true);
      _favorites.insert(0, favVideo);
      await _cacheService.addFavorite(video.id);
    }

    // Save full video data
    await _cacheService.saveFavoriteVideos(_favorites);
    notifyListeners();
  }

  /// Remove from favorites
  Future<void> removeFavorite(String videoId) async {
    _favoriteIds.remove(videoId);
    _favorites.removeWhere((v) => v.id == videoId);
    await _cacheService.removeFavorite(videoId);
    await _cacheService.saveFavoriteVideos(_favorites);
    notifyListeners();
  }
}
