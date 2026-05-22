import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/video_provider.dart';
import '../widgets/video_card.dart';
import '../widgets/shimmer_loading.dart';
import 'video_player_screen.dart';

class CategoryVideoScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryVideoScreen({super.key, required this.category});

  @override
  State<CategoryVideoScreen> createState() => _CategoryVideoScreenState();
}

class _CategoryVideoScreenState extends State<CategoryVideoScreen> {
  late final VideoProvider _videoProvider;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _videoProvider = context.read<VideoProvider>();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialCategoryVideos();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialCategoryVideos() async {
    await _videoProvider.ensureCategoryVideosLoaded(widget.category.id);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreIfNeeded();
    });
  }

  void _handleScroll() {
    _loadMoreIfNeeded();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) return;

    final videoProvider = context.read<VideoProvider>();
    final categoryId = widget.category.id;

    if (videoProvider.isLoadingCategory(categoryId) ||
        !videoProvider.hasMoreCategoryVideos(categoryId)) {
      return;
    }

    if (_scrollController.position.extentAfter > 320) {
      return;
    }

    videoProvider.loadMoreCategoryVideos(categoryId).then((_) {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMoreIfNeeded();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Gradient App Bar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.category.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.category.nameEn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.category.gradientColors,
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.15,
                    child: Text(
                      widget.category.icon,
                      style: const TextStyle(fontSize: 100),
                    ),
                  ),
                ),
              ),
            ),
            backgroundColor: widget.category.gradientColors.first,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Video list
          Consumer<VideoProvider>(
            builder: (context, vp, _) {
              final videos = vp.getVideosByCategory(widget.category.id);
              final isLoadingCategory = vp.isLoadingCategory(
                widget.category.id,
              );

              if ((vp.state == LoadingState.loading || isLoadingCategory) &&
                  videos.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: ShimmerLoading(isCompact: true, itemCount: 6),
                  ),
                );
              }

              if (videos.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.category.icon,
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No videos found',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try refreshing the app',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final video = videos[index];
                  return VideoCard(
                    video: video,
                    isCompact: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(video: video),
                      ),
                    ),
                  );
                }, childCount: videos.length),
              );
            },
          ),

          Consumer<VideoProvider>(
            builder: (context, vp, child) {
              if (!vp.isLoadingCategory(widget.category.id)) {
                return const SliverToBoxAdapter(child: SizedBox(height: 20));
              }

              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
