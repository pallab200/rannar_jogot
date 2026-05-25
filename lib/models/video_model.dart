class VideoModel {
  static final RegExp _isoDurationPattern = RegExp(
    r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?',
  );
  static final RegExp _clockDurationPattern = RegExp(
    r'^(?:(\d+):)?(\d{1,2}):(\d{2})$',
  );
  static final RegExp _shortsMarkerPattern = RegExp(
    r'(^|[^a-z0-9])#?shorts([^a-z0-9]|$)',
    caseSensitive: false,
  );

  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String channelId;
  final String publishedAt;
  final String duration;
  final String viewCount;
  final String likeCount;
  final String category;
  bool isFavorite;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.channelId,
    required this.publishedAt,
    this.duration = '',
    this.viewCount = '0',
    this.likeCount = '0',
    this.category = 'general',
    this.isFavorite = false,
  });

  factory VideoModel.fromSearchJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final high = thumbnails['high'] ?? thumbnails['medium'] ?? thumbnails['default'] ?? {};

    return VideoModel(
      id: json['id']?['videoId'] ?? '',
      title: snippet['title'] ?? '',
      description: snippet['description'] ?? '',
      thumbnailUrl: high['url'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      channelId: snippet['channelId'] ?? '',
      publishedAt: snippet['publishedAt'] ?? '',
    );
  }

  factory VideoModel.fromVideoJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final statistics = json['statistics'] ?? {};
    final contentDetails = json['contentDetails'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final high = thumbnails['high'] ?? thumbnails['medium'] ?? thumbnails['default'] ?? {};

    return VideoModel(
      id: json['id'] ?? '',
      title: snippet['title'] ?? '',
      description: snippet['description'] ?? '',
      thumbnailUrl: high['url'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      channelId: snippet['channelId'] ?? '',
      publishedAt: snippet['publishedAt'] ?? '',
      duration: _parseDuration(contentDetails['duration'] ?? ''),
      viewCount: statistics['viewCount'] ?? '0',
      likeCount: statistics['likeCount'] ?? '0',
    );
  }

  static String _parseDuration(String isoDuration) {
    final totalSeconds = _durationToSeconds(isoDuration);
    if (totalSeconds == null) return '';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'channelTitle': channelTitle,
      'channelId': channelId,
      'publishedAt': publishedAt,
      'duration': duration,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'category': category,
      'isFavorite': isFavorite,
    };
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      channelTitle: json['channelTitle'] ?? '',
      channelId: json['channelId'] ?? '',
      publishedAt: json['publishedAt'] ?? '',
      duration: json['duration'] ?? '',
      viewCount: json['viewCount'] ?? '0',
      likeCount: json['likeCount'] ?? '0',
      category: json['category'] ?? 'general',
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? channelTitle,
    String? channelId,
    String? publishedAt,
    String? duration,
    String? viewCount,
    String? likeCount,
    String? category,
    bool? isFavorite,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelTitle: channelTitle ?? this.channelTitle,
      channelId: channelId ?? this.channelId,
      publishedAt: publishedAt ?? this.publishedAt,
      duration: duration ?? this.duration,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  bool get isShortForm {
    if (_containsShortsMarker(title) || _containsShortsMarker(description)) {
      return true;
    }

    final durationSeconds = _durationToSeconds(duration);
    return durationSeconds != null && durationSeconds <= 60;
  }

  static List<VideoModel> filterSupportedFeedVideos(
    Iterable<VideoModel> videos,
  ) {
    return videos.where((video) => !video.isShortForm).toList(growable: false);
  }

  static bool _containsShortsMarker(String value) {
    if (value.isEmpty) {
      return false;
    }

    return _shortsMarkerPattern.hasMatch(value);
  }

  static int? _durationToSeconds(String value) {
    if (value.isEmpty) {
      return null;
    }

    final normalized = value.trim();
    final clockMatch = _clockDurationPattern.firstMatch(normalized);
    if (clockMatch != null) {
      final hours = int.tryParse(clockMatch.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(clockMatch.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(clockMatch.group(3) ?? '0') ?? 0;
      return hours * 3600 + minutes * 60 + seconds;
    }

    final isoMatch = _isoDurationPattern.firstMatch(normalized);
    if (isoMatch == null) {
      return null;
    }

    final hours = int.tryParse(isoMatch.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(isoMatch.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(isoMatch.group(3) ?? '0') ?? 0;
    return hours * 3600 + minutes * 60 + seconds;
  }

  String get formattedViewCount {
    final count = int.tryParse(viewCount) ?? 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String get timeAgo {
    try {
      final published = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final diff = now.difference(published);

      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()}y ago';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()}mo ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inMinutes}m ago';
      }
    } catch (_) {
      return '';
    }
  }
}
