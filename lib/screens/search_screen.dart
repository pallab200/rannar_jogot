import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../widgets/video_card.dart';
import '../widgets/shimmer_loading.dart';
import 'video_player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await context.read<VideoProvider>().getSearchHistory();
    setState(() => _searchHistory = history);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    _focusNode.unfocus();
    context.read<VideoProvider>().searchVideos(query.trim());
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Search', style: theme.appBarTheme.titleTextStyle),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search recipes, ingredients...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.bodyLarge,
            ),
          ),

          // Quick search chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _quickChip('🐟 Fish Curry', theme),
                _quickChip('🍗 Chicken', theme),
                _quickChip('🍚 Biryani', theme),
                _quickChip('🥘 Snacks', theme),
                _quickChip('🍮 Sweets', theme),
                _quickChip('🎉 Eid Special', theme),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: Consumer<VideoProvider>(
              builder: (_, vp, _) {
                // Show search results
                if (vp.searchState == LoadingState.loading) {
                  return const ShimmerLoading(isCompact: true, itemCount: 6);
                }

                if (vp.searchState == LoadingState.loaded &&
                    vp.searchResults.isNotEmpty) {
                  return _buildSearchResults(vp);
                }

                if (vp.searchState == LoadingState.error) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Search failed',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please try again',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                if (vp.searchState == LoadingState.loaded &&
                    vp.searchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No results found',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try a different search',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                // Show search history
                return _buildSearchHistory(theme, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(VideoProvider vp) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
          vp.loadMoreSearchResults();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: vp.searchResults.length + (vp.isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= vp.searchResults.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final video = vp.searchResults[i];
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
        },
      ),
    );
  }

  Widget _buildSearchHistory(ThemeData theme, bool isDark) {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍳', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Search for recipes', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Find your favorite Bangladeshi dishes',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Searches', style: theme.textTheme.titleMedium),
              TextButton(
                onPressed: () async {
                  await context.read<VideoProvider>().clearSearchHistory();
                  _loadHistory();
                },
                child: Text(
                  'Clear',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE65100),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          ...List.generate(
            _searchHistory.length,
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 20),
              title: Text(_searchHistory[i], style: theme.textTheme.bodyLarge),
              dense: true,
              onTap: () {
                _searchController.text = _searchHistory[i];
                _performSearch(_searchHistory[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        final query = label.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        _searchController.text = query;
        _performSearch(query);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      ),
    );
  }
}
