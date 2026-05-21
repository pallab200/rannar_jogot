import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/video_provider.dart';
import '../services/youtube_service.dart';
import '../widgets/video_card.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  YoutubePlayerController? _controller;
  bool _isDescriptionExpanded = false;
  bool _isCheckingAvailability = true;
  bool _isVideoAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    final isEmbeddable = await _youtubeService.isVideoEmbeddable(
      widget.video.id,
    );
    if (!mounted) return;

    if (!isEmbeddable) {
      setState(() {
        _isCheckingAvailability = false;
        _isVideoAvailable = false;
      });
      return;
    }

    final controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        mute: false,
      ),
    );

    setState(() {
      _controller = controller;
      _isCheckingAvailability = false;
      _isVideoAvailable = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<FavoritesProvider>(
            builder: (_, fp, _) {
              final isFav = fp.isFavorite(widget.video.id);
              return IconButton(
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? Colors.redAccent : null,
                ),
                onPressed: () => fp.toggleFavorite(widget.video),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () => _openInYouTube(),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _shareVideo(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YouTube Player
            _buildPlayerSection(theme),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _decodeHtml(widget.video.title),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Stats row
                  Row(
                    children: [
                      if (widget.video.viewCount != '0') ...[
                        _statChip(
                          Icons.visibility_outlined,
                          '${widget.video.formattedViewCount} views',
                          theme,
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (widget.video.likeCount != '0') ...[
                        _statChip(
                          Icons.thumb_up_outlined,
                          widget.video.likeCount,
                          theme,
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (widget.video.timeAgo.isNotEmpty)
                        _statChip(
                          Icons.access_time,
                          widget.video.timeAgo,
                          theme,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Channel info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(
                            0xFFE65100,
                          ).withOpacity(0.15),
                          child: Text(
                            widget.video.channelTitle.isNotEmpty
                                ? widget.video.channelTitle[0].toUpperCase()
                                : 'C',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE65100),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.video.channelTitle,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'YouTube Channel',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category badge
                  if (widget.video.category != 'general') ...[
                    Consumer<VideoProvider>(
                      builder: (_, vp, _) {
                        final cat = vp.getCategoryById(widget.video.category);
                        if (cat == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: cat.gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cat.icon,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.nameEn,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Description
                  if (widget.video.description.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => setState(
                        () => _isDescriptionExpanded = !_isDescriptionExpanded,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.video.description,
                            maxLines: _isDescriptionExpanded ? null : 3,
                            overflow: _isDescriptionExpanded
                                ? null
                                : TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isDescriptionExpanded ? 'Show less' : 'Show more',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFE65100),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Related videos
                  Text('More Videos', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // Related videos list
            Consumer<VideoProvider>(
              builder: (_, vp, _) {
                final related = vp.allVideos
                    .where((v) => v.id != widget.video.id)
                    .take(10)
                    .toList();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: related.length,
                  itemBuilder: (_, i) {
                    final v = related[i];
                    return VideoCard(
                      video: v,
                      isCompact: true,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(video: v),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.textTheme.bodySmall?.color),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPlayerSection(ThemeData theme) {
    if (_isCheckingAvailability) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isVideoAvailable || _controller == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          children: [
            const Icon(Icons.ondemand_video_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'This video cannot be played inside the app.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Some YouTube videos block embedded playback. Open it in YouTube instead.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openInYouTube,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open in YouTube'),
            ),
          ],
        ),
      );
    }

    return YoutubePlayer(controller: _controller!);
  }

  Future<void> _openInYouTube() async {
    final url = Uri.parse('https://www.youtube.com/watch?v=${widget.video.id}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _shareVideo() {
    final url = 'https://youtu.be/${widget.video.id}';
    // Simple share via clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied: $url'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
