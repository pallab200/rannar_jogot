import 'package:flutter_test/flutter_test.dart';
import 'package:rannar_jogot/models/category_model.dart';
import 'package:rannar_jogot/models/video_model.dart';
import 'package:rannar_jogot/providers/video_provider.dart';
import 'package:rannar_jogot/services/cache_service.dart';
import 'package:rannar_jogot/services/category_service.dart';
import 'package:rannar_jogot/services/video_feed_service.dart';
import 'package:rannar_jogot/utils/constants.dart';

void main() {
  test('initialize preloads multiple latest and trending pages', () async {
    final videoFeedService = FakeVideoFeedService(
      latestPageCount: AppConstants.initialLatestPageCount,
      trendingPageCount: AppConstants.initialTrendingPageCount,
    );
    final cacheService = FakeCacheService();
    final provider = VideoProvider(
      videoFeedService: videoFeedService,
      categoryService: CategoryService(),
      cacheService: cacheService,
    );

    await provider.initialize();

    expect(
      videoFeedService.latestRequestedTokens,
      hasLength(AppConstants.initialLatestPageCount),
    );
    expect(
      videoFeedService.trendingRequestedTokens,
      hasLength(AppConstants.initialTrendingPageCount),
    );
    expect(
      provider.allVideos,
      hasLength(AppConstants.initialLatestPageCount * 2),
    );
    expect(
      provider.trendingVideos,
      hasLength(AppConstants.initialTrendingPageCount * 2),
    );
    expect(cacheService.cachedVideoLists['all_videos'], hasLength(4));
    expect(cacheService.cachedVideoLists['trending'], hasLength(4));
  });

  test('category feed merges fetched videos with local category matches', () async {
    final videoFeedService = FakeVideoFeedService(
      latestPageCount: AppConstants.initialLatestPageCount,
      trendingPageCount: AppConstants.initialTrendingPageCount,
      categoryVideos: <String, List<VideoModel>>{
        'fish': <VideoModel>[
          _buildVideo(
            id: 'remote-fish-1',
            title: 'Shorshe ilish fish curry',
            description: 'Bangla fish recipe',
          ),
        ],
      },
    );
    final provider = VideoProvider(
      videoFeedService: videoFeedService,
      categoryService: CategoryService(),
      cacheService: FakeCacheService(),
    );

    await provider.initialize();
    await provider.ensureCategoryVideosLoaded('fish');

    final fishVideos = provider.getVideosByCategory('fish');
    expect(fishVideos.map((video) => video.id), contains('remote-fish-1'));
    expect(fishVideos.length, greaterThan(1));
  });
}

class FakeVideoFeedService extends VideoFeedService {
  FakeVideoFeedService({
    required this.latestPageCount,
    required this.trendingPageCount,
    this.categoryVideos = const <String, List<VideoModel>>{},
  });

  final int latestPageCount;
  final int trendingPageCount;
  final Map<String, List<VideoModel>> categoryVideos;
  final List<String?> latestRequestedTokens = <String?>[];
  final List<String?> trendingRequestedTokens = <String?>[];

  @override
  Future<Map<String, dynamic>> getLatestVideos({String? pageToken}) async {
    latestRequestedTokens.add(pageToken);
    return _buildPageResult(
      prefix: 'latest',
      pageToken: pageToken,
      pageCount: latestPageCount,
    );
  }

  @override
  Future<Map<String, dynamic>> getTrendingVideos({String? pageToken}) async {
    trendingRequestedTokens.add(pageToken);
    return _buildPageResult(
      prefix: 'trending',
      pageToken: pageToken,
      pageCount: trendingPageCount,
    );
  }

  @override
  Future<Map<String, dynamic>> getCategoryVideos(
    CategoryModel category, {
    String? pageToken,
  }) async {
    final videos = categoryVideos[category.id] ?? const <VideoModel>[];
    return {
      'videos': videos,
      'nextPageToken': null,
      'totalResults': videos.length,
    };
  }

  Map<String, dynamic> _buildPageResult({
    required String prefix,
    required String? pageToken,
    required int pageCount,
  }) {
    final pageNumber = int.tryParse(pageToken ?? '1') ?? 1;
    final videos = List<VideoModel>.generate(2, (index) {
      final videoNumber = ((pageNumber - 1) * 2) + index + 1;
      return switch (prefix) {
        'latest' => _buildVideo(
          id: '$prefix-$videoNumber',
          title: 'Ilish fish curry recipe $videoNumber',
          description: 'Traditional bangla fish cooking $videoNumber',
        ),
        'trending' => _buildVideo(
          id: '$prefix-$videoNumber',
          title: 'Chicken roast recipe $videoNumber',
          description: 'Bangla chicken curry $videoNumber',
        ),
        _ => _buildVideo(
          id: '$prefix-$videoNumber',
          title: '$prefix recipe $videoNumber',
          description: 'Bangla cooking recipe $videoNumber',
        ),
      };
    });

    return {
      'videos': videos,
      'nextPageToken': pageNumber < pageCount ? '${pageNumber + 1}' : null,
      'totalResults': pageCount * 2,
    };
  }
}

class FakeCacheService extends CacheService {
  FakeCacheService() : super.test();

  final Map<String, List<VideoModel>> cachedVideoLists =
      <String, List<VideoModel>>{};

  @override
  Future<List<VideoModel>?> getCachedVideos(
    String key, {
    int? maxAgeMinutes,
  }) async {
    return cachedVideoLists[key];
  }

  @override
  Future<CachedVideoFeed?> getCachedVideoFeed(
    String key, {
    int? maxAgeMinutes,
  }) async {
    return null;
  }

  @override
  Future<void> cacheVideos(String key, List<VideoModel> videos) async {
    cachedVideoLists[key] = List<VideoModel>.from(videos);
  }

  @override
  Future<void> cacheVideoFeed(
    String key, {
    required List<VideoModel> videos,
    String? nextPageToken,
  }) async {
    cachedVideoLists[key] = List<VideoModel>.from(videos);
  }
}

VideoModel _buildVideo({
  required String id,
  required String title,
  required String description,
}) {
  return VideoModel(
    id: id,
    title: title,
    description: description,
    thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
    channelTitle: 'Cooking Channel',
    channelId: 'channel-1',
    publishedAt: '2026-05-20T10:00:00Z',
    duration: '08:30',
  );
}