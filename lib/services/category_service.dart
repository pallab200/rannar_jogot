import '../models/category_model.dart';
import '../models/video_model.dart';
import '../utils/constants.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  late final List<CategoryModel> _categories;
  bool _initialized = false;

  List<CategoryModel> get categories {
    _ensureInitialized();
    return _categories;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      _categories = CategoryData.categories
          .map((data) => CategoryModel.fromMap(data))
          .toList();
      _initialized = true;
    }
  }

  /// Auto-categorize a video based on title, description, and tags
  /// Uses weighted keyword matching:
  /// - Title matches: weight 3x
  /// - Description matches: weight 1x
  /// - Channel title matches: weight 2x
  String categorizeVideo(VideoModel video) {
    _ensureInitialized();

    final title = video.title.toLowerCase();
    final description = video.description.toLowerCase();
    final channel = video.channelTitle.toLowerCase();

    Map<String, double> scores = {};

    for (final category in _categories) {
      double score = 0;

      for (final keyword in category.keywords) {
        final kw = keyword.toLowerCase();

        // Title match — highest weight
        if (title.contains(kw)) {
          score += 3.0;
          // Bonus for exact word match in title
          if (RegExp('\\b$kw\\b', caseSensitive: false).hasMatch(title)) {
            score += 1.0;
          }
        }

        // Description match
        if (description.contains(kw)) {
          score += 1.0;
        }

        // Channel name match
        if (channel.contains(kw)) {
          score += 2.0;
        }
      }

      scores[category.id] = score;
    }

    // Find the category with the highest score
    String bestCategory = 'general';
    double bestScore = 0;

    scores.forEach((categoryId, score) {
      if (score > bestScore) {
        bestScore = score;
        bestCategory = categoryId;
      }
    });

    // Minimum threshold to assign a category
    if (bestScore < 2.0) {
      return 'general';
    }

    return bestCategory;
  }

  /// Categorize a list of videos
  List<VideoModel> categorizeVideos(List<VideoModel> videos) {
    return videos.map((video) {
      final category = categorizeVideo(video);
      return video.copyWith(category: category);
    }).toList();
  }

  /// Get videos filtered by category
  List<VideoModel> getVideosByCategory(List<VideoModel> allVideos, String categoryId) {
    if (categoryId == 'all') return allVideos;
    return allVideos.where((v) => v.category == categoryId).toList();
  }

  /// Get category by ID
  CategoryModel? getCategoryById(String id) {
    _ensureInitialized();
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Update video counts for each category
  void updateCategoryCounts(List<VideoModel> videos) {
    _ensureInitialized();
    for (final category in _categories) {
      category.videoCount = videos.where((v) => v.category == category.id).length;
    }
  }
}
