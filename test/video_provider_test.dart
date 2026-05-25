import 'package:flutter_test/flutter_test.dart';
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
}

class FakeVideoFeedService extends VideoFeedService {
  FakeVideoFeedService({
    required this.latestPageCount,
    required this.trendingPageCount,
  });

  final int latestPageCount;
  final int trendingPageCount;
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

  Map<String, dynamic> _buildPageResult({
    required String prefix,
    required String? pageToken,
    required int pageCount,
  }) {
    final pageNumber = int.tryParse(pageToken ?? '1') ?? 1;
    final videos = List<VideoModel>.generate(2, (index) {
      final videoNumber = ((pageNumber - 1) * 2) + index + 1;
      return VideoModel(
        id: '$prefix-$videoNumber',
        title: '$prefix recipe $videoNumber',
        description: 'Bangla cooking recipe $videoNumber',
        thumbnailUrl: 'https://img.youtube.com/vi/$prefix-$videoNumber/hqdefault.jpg',
        channelTitle: 'Cooking Channel',
        channelId: 'channel-$prefix',
        publishedAt: '2026-05-20T10:00:00Z',
        duration: '08:30',
      );
    });

    return {
      'videos': videos,
      'nextPageToken': pageNumber < pageCount ? '${pageNumber + 1}' : null,
      'totalResults': pageCount * 2,
    };
  }
}

class FakeCacheService extends CacheService {
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