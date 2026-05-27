import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/video_provider.dart';
import '../providers/localization_provider.dart';
import '../services/ad_service.dart';
import '../utils/constants.dart';
import '../utils/app_strings.dart';
import '../widgets/video_card.dart';
import '../widgets/category_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/test_banner_ad.dart';
import 'about_screen.dart';
import 'category_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'privacy_policy_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  Future<void> _shareApp(String language) {
    final shareText = [
      AppStrings.getByLang('shareAppMessage', language),
      AppConstants.appShareUrl,
    ].join('\n');

    return SharePlus.instance.share(
      ShareParams(text: shareText, subject: AppConstants.appName),
    );
  }

  Future<void> _onBottomNavigationTap(int index) async {
    if (index == 3) {
      await _showMenuSheet();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _showMenuSheet() async {
    final locProvider = context.read<LocalizationProvider>();
    final lang = locProvider.currentLanguage;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: Text(AppStrings.getByLang('settings', lang)),
                  subtitle: Text(
                    AppStrings.getByLang('settingsSubtitle', lang),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(AppStrings.getByLang('history', lang)),
                  subtitle: Text(AppStrings.getByLang('historySubtitle', lang)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(AppStrings.getByLang('privacyPolicy', lang)),
                  subtitle: Text(
                    AppStrings.getByLang('privacyPolicySubtitle', lang),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(AppStrings.getByLang('about', lang)),
                  subtitle: Text(AppStrings.getByLang('aboutSubtitle', lang)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: Text(AppStrings.getByLang('shareApp', lang)),
                  subtitle: Text(
                    AppStrings.getByLang('shareAppSubtitle', lang),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _shareApp(lang);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeTab(),
      const _CategoriesTab(),
      const FavoritesScreen(),
      const SizedBox.shrink(),
    ];

    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        final lang = locProvider.currentLanguage;
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
              onTap: _onBottomNavigationTap,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_rounded),
                  label: AppStrings.getByLang('home', lang),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.category_rounded),
                  label: AppStrings.getByLang('categories', lang),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.favorite_rounded),
                  label: AppStrings.getByLang('favorites', lang),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.menu_rounded),
                  label: AppStrings.getByLang('menu', lang),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        final lang = locProvider.currentLanguage;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('🍛 ', style: TextStyle(fontSize: 24)),
                Text(
                  AppStrings.getByLang('rannarJogot', lang),
                  style: theme.appBarTheme.titleTextStyle,
                ),
              ],
            ),
            actions: [
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
                      _sectionTitle(
                        theme,
                        AppStrings.getByLang('trendingRecipes', lang),
                      ),
                      const ShimmerHorizontalList(),
                      const SizedBox(height: 16),
                      _sectionTitle(
                        theme,
                        AppStrings.getByLang('latestVideos', lang),
                      ),
                      const ShimmerLoading(itemCount: 4),
                    ],
                  ),
                );
              }

              if (vp.state == LoadingState.error && vp.allVideos.isEmpty) {
                return _errorWidget(context, vp, lang);
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
                        _sectionTitle(
                          theme,
                          '🔥 ${AppStrings.getByLang('trendingRecipes', lang)}',
                        ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
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
                        _sectionTitle(
                          theme,
                          '📂 ${AppStrings.getByLang('categories', lang)}',
                        ),
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
                                  language: lang,
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
                        _sectionTitle(
                          theme,
                          '🎬 ${AppStrings.getByLang('latestVideos', lang)}',
                        ),
                        if (vp.allVideos.isEmpty)
                          const ShimmerLoading(itemCount: 4)
                        else
                          Builder(
                            builder: (context) {
                              final includeBanners = AdService.supportsAds;
                              final latestContentCount = includeBanners
                                  ? AdService.listItemCountForVideos(
                                      vp.allVideos.length,
                                    )
                                  : vp.allVideos.length;

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount:
                                    latestContentCount +
                                    (vp.isLoadingMoreLatest ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i >= latestContentCount) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  if (includeBanners &&
                                      AdService.isBannerIndex(i)) {
                                    return const TestBannerAdListItem();
                                  }

                                  final videoIndex = includeBanners
                                      ? AdService.videoIndexForListIndex(i)
                                      : i;
                                  final video = vp.allVideos[videoIndex];
                                  return VideoCard(
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
                              );
                            },
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
      },
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Text(title, style: theme.textTheme.headlineSmall),
    );
  }

  Widget _errorWidget(BuildContext context, VideoProvider vp, String lang) {
    final message = vp.errorMessage.isEmpty
        ? 'Unable to load videos right now. Please try again.'
        : vp.errorMessage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load videos',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
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

    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        final lang = locProvider.currentLanguage;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppStrings.getByLang('categories', lang),
              style: theme.appBarTheme.titleTextStyle,
            ),
          ),
          body: Consumer<VideoProvider>(
            builder: (context, vp, child) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: vp.categories.length,
                  itemBuilder: (_, i) {
                    final cat = vp.categories[i];
                    return CategoryCard(
                      category: cat,
                      language: lang,
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
      },
    );
  }
}
