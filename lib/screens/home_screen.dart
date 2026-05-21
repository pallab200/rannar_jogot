import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/video_card.dart';
import '../widgets/category_card.dart';
import '../widgets/shimmer_loading.dart';
import 'category_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeTab(),
      const _CategoriesTab(),
      const SearchScreen(),
      const FavoritesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category_rounded),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_rounded),
              label: 'Favorites',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🍛 ', style: TextStyle(fontSize: 24)),
            Text('Rannar Jogot', style: theme.appBarTheme.titleTextStyle),
          ],
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, tp, child) => IconButton(
              icon: Icon(
                tp.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              onPressed: () => tp.toggleTheme(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<VideoProvider>(
        builder: (context, vp, _) {
          if (vp.state == LoadingState.loading && vp.allVideos.isEmpty) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(theme, 'Trending Recipes'),
                  const ShimmerHorizontalList(),
                  const SizedBox(height: 16),
                  _sectionTitle(theme, 'Latest Videos'),
                  const ShimmerLoading(itemCount: 4),
                ],
              ),
            );
          }

          if (vp.state == LoadingState.error && vp.allVideos.isEmpty) {
            return _errorWidget(context, vp);
          }

          return RefreshIndicator(
            onRefresh: () => vp.refresh(),
            color: const Color(0xFFE65100),
            child: NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.axis == Axis.vertical &&
                    scroll.metrics.pixels >=
                        scroll.metrics.maxScrollExtent - 300) {
                  vp.loadMoreLatestVideos();
                }
                return false;
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trending Section
                    _sectionTitle(theme, '🔥 Trending Recipes'),
                    if (vp.trendingVideos.isEmpty)
                      const ShimmerHorizontalList()
                    else
                      SizedBox(
                        height: 240,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (scroll) {
                            if (scroll.metrics.axis == Axis.horizontal &&
                                scroll.metrics.pixels >=
                                    scroll.metrics.maxScrollExtent - 220) {
                              vp.loadMoreTrending();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount:
                                vp.trendingVideos.length +
                                (vp.isLoadingMoreTrending ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= vp.trendingVideos.length) {
                                return const SizedBox(
                                  width: 84,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final video = vp.trendingVideos[i];
                              return VideoCardHorizontal(
                                video: video,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        VideoPlayerScreen(video: video),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Categories Preview
                    _sectionTitle(theme, '📂 Categories'),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: vp.categories.length,
                        itemBuilder: (_, i) {
                          final cat = vp.categories[i];
                          return Container(
                            width: 130,
                            margin: const EdgeInsets.only(right: 10),
                            child: CategoryCard(
                              category: cat,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CategoryVideoScreen(category: cat),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Latest Videos
                    _sectionTitle(theme, '🎬 Latest Videos'),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vp.allVideos.length,
                      itemBuilder: (_, i) {
                        final video = vp.allVideos[i];
                        return VideoCard(
                          video: video,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoPlayerScreen(video: video),
                            ),
                          ),
                        );
                      },
                    ),
                    if (vp.isLoadingMoreLatest)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Text(title, style: theme.textTheme.headlineSmall),
    );
  }

  Widget _errorWidget(BuildContext context, VideoProvider vp) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => vp.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Categories', style: theme.appBarTheme.titleTextStyle),
      ),
      body: Consumer<VideoProvider>(
        builder: (context, vp, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: vp.categories.length,
              itemBuilder: (_, i) {
                final cat = vp.categories[i];
                return CategoryCard(
                  category: cat,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryVideoScreen(category: cat),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
