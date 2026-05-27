import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../models/video_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/video_provider.dart';
import '../services/ad_service.dart';
import '../services/cache_service.dart';
import '../services/youtube_service.dart';
import '../utils/app_strings.dart';
import '../utils/constants.dart';
import '../widgets/video_card.dart';

enum _InterstitialTrigger { initial, timed }

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final CacheService _cacheService = CacheService();
  final YouTubeService _youtubeService = YouTubeService();
  static const MethodChannel _orientationChannel = MethodChannel(
    'rannar_jogot/orientation',
  );
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  bool _isDescriptionExpanded = false;
  bool _isCheckingAvailability = true;
  bool _isVideoAvailable = false;

  // Fullscreen state tracking
  bool _isFullscreen = false;
  bool _wasPlaying = false;
  Timer? _resumeTimer;
  Timer? _interstitialTimer;
  InterstitialAd? _interstitialAd;
  bool _isAdShowing = false;
  bool _hasShownInitialInterstitial = false;
  bool _isPlaybackActive = false;
  _InterstitialTrigger? _pendingInterstitialTrigger;
  _InterstitialTrigger? _activeInterstitialTrigger;
  bool _wasPlayingBeforeAd = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    unawaited(context.read<VideoProvider>().addToWatchHistory(widget.video));
    _loadInterstitialAd();
    _initializePlayer();
  }

  @override
  void dispose() {
    _interstitialTimer?.cancel();
    _resumeTimer?.cancel();
    _subscription?.cancel();
    _interstitialAd?.dispose();
    _controller?.close();
    // Restore portrait lock when leaving the screen
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    final autoPlayEnabled = await _cacheService.isAutoplayEnabled();
    if (!mounted) return;

    if (AppConstants.youtubeApiKey.isNotEmpty) {
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
    }

    final controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: autoPlayEnabled,
      params: const YoutubePlayerParams(
        showFullscreenButton: false,
        showControls: true,
        showVideoAnnotations: false,
        strictRelatedVideos: true,
        privacyEnhancedMode: true,
        mute: false,
      ),
    );

    controller.setFullScreenListener((isFullscreen) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFullscreen = isFullscreen;
      });

      if (isFullscreen) {
        unawaited(_setLandscapeMode());
      } else {
        unawaited(_setPortraitMode());
      }

      if (_wasPlaying) {
        _scheduleResume(controller);
      }
    });

    _subscription = controller.stream.listen((value) {
      if (!mounted) return;

      // Track if we were playing BEFORE a fullscreen change
      if (!_isFullscreen) {
        // Only update wasPlaying when NOT transitioning fullscreen
        if (value.playerState == PlayerState.playing) {
          _wasPlaying = true;
        } else if (value.playerState == PlayerState.paused ||
            value.playerState == PlayerState.ended) {
          _wasPlaying = false;
        }
      }

      _handlePlaybackState(value.playerState);
    });

    setState(() {
      _controller = controller;
      _isCheckingAvailability = false;
      _isVideoAvailable = true;
    });
  }

  void _loadInterstitialAd() {
    if (!AdService.supportsAds || _interstitialAd != null) {
      return;
    }

    InterstitialAd.load(
      adUnitId: AdService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          _interstitialAd = ad;
          _attachInterstitialCallbacks(ad);
          _showInterstitialIfReady();
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _attachInterstitialCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isAdShowing = true;
        if (_activeInterstitialTrigger == _InterstitialTrigger.initial) {
          _hasShownInitialInterstitial = true;
        }
        _interstitialTimer?.cancel();

        // Pause video when ad shows
        final controller = _controller;
        if (controller != null &&
            controller.value.playerState == PlayerState.playing) {
          _wasPlayingBeforeAd = true;
          controller.pauseVideo();
        } else {
          _wasPlayingBeforeAd = false;
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        _isAdShowing = false;
        _activeInterstitialTrigger = null;
        ad.dispose();

        // Resume video if it was playing before the ad
        if (_wasPlayingBeforeAd && _controller != null) {
          _controller!.playVideo();
          _wasPlayingBeforeAd = false;
        }

        _loadInterstitialAd();
        if (_isPlaybackActive) {
          _scheduleTimedInterstitial();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _isAdShowing = false;
        _activeInterstitialTrigger = null;
        ad.dispose();

        // Resume video if it was playing before the ad
        if (_wasPlayingBeforeAd && _controller != null) {
          _controller!.playVideo();
          _wasPlayingBeforeAd = false;
        }

        _loadInterstitialAd();
        if (_isPlaybackActive) {
          _scheduleTimedInterstitial();
        }
      },
    );
  }

  void _requestInterstitial(_InterstitialTrigger trigger) {
    if (!AdService.supportsAds || _isAdShowing) {
      return;
    }

    if (_pendingInterstitialTrigger == trigger ||
        _activeInterstitialTrigger == trigger) {
      return;
    }

    _pendingInterstitialTrigger = trigger;
    _showInterstitialIfReady();
    _loadInterstitialAd();
  }

  void _showInterstitialIfReady() {
    final ad = _interstitialAd;
    final trigger = _pendingInterstitialTrigger;
    if (!mounted ||
        ad == null ||
        trigger == null ||
        _isAdShowing ||
        !_isPlaybackActive) {
      return;
    }

    _activeInterstitialTrigger = trigger;
    _pendingInterstitialTrigger = null;
    _interstitialAd = null;
    ad.show();
  }

  void _handlePlaybackState(PlayerState state) {
    final isPlaybackActive =
        state == PlayerState.playing || state == PlayerState.buffering;

    if (state == PlayerState.playing &&
        !_hasShownInitialInterstitial &&
        _pendingInterstitialTrigger != _InterstitialTrigger.initial &&
        _activeInterstitialTrigger != _InterstitialTrigger.initial) {
      _requestInterstitial(_InterstitialTrigger.initial);
    }

    if (_isPlaybackActive == isPlaybackActive) {
      if (isPlaybackActive) {
        _showInterstitialIfReady();
      }
      return;
    }

    _isPlaybackActive = isPlaybackActive;
    if (!isPlaybackActive) {
      _interstitialTimer?.cancel();
      return;
    }

    _showInterstitialIfReady();
    _scheduleTimedInterstitial();
  }

  void _scheduleTimedInterstitial() {
    _interstitialTimer?.cancel();
    if (!_isPlaybackActive || _isAdShowing) {
      return;
    }

    _interstitialTimer = Timer(AdService.interstitialInterval, () {
      if (!mounted || !_isPlaybackActive) {
        return;
      }

      _requestInterstitial(_InterstitialTrigger.timed);
    });
  }

  /// Try to resume playback at 300ms, 600ms, 1000ms, and 1500ms intervals
  /// to handle different device/WebView timings during fullscreen transition.
  void _scheduleResume(YoutubePlayerController controller) {
    _resumeTimer?.cancel();

    final delays = [300, 600, 1000, 1500];
    for (final ms in delays) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted) return;
        if (controller.value.playerState != PlayerState.playing) {
          controller.playVideo();
        }
      });
    }
  }

  Future<void> _setLandscapeMode() async {
    await _invokeOrientationMethod('forceLandscape');
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || !_isFullscreen) {
      return;
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _setPortraitMode() async {
    await _invokeOrientationMethod('forcePortrait');
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _invokeOrientationMethod(String method) async {
    try {
      await _orientationChannel.invokeMethod<void>(method);
    } catch (_) {
      // Fall back to SystemChrome-only orientation control when the platform
      // channel is unavailable.
    }
  }

  Future<void> _openFullscreenPlayer() async {
    final controller = _controller;
    if (controller == null || _isFullscreen) {
      return;
    }

    final shouldResume =
        _wasPlaying ||
        controller.value.playerState == PlayerState.playing ||
        controller.value.playerState == PlayerState.buffering;

    controller.enterFullScreen(lock: false);

    if (shouldResume) {
      _scheduleResume(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show loading state
    if (_isCheckingAvailability) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show unavailable state
    if (!_isVideoAvailable || _controller == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: _buildUnavailableBody(theme),
      );
    }

    return YoutubePlayerControllerProvider(
      controller: _controller!,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // YouTube Player
              _buildPlayer(),
              _buildPlayerControls(theme),

              // Video Info
              _buildVideoInfo(theme),

              // Related videos list
              _buildRelatedVideos(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
        autoFullScreen: false,
        keepAlive: true,
        enableFullScreenOnVerticalDrag: false,
      ),
    );
  }

  Widget _buildPlayerControls(ThemeData theme) {
    if (_isFullscreen) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.tonalIcon(
            onPressed: _openFullscreenPlayer,
            icon: const Icon(Icons.fullscreen_rounded),
            label: const Text('Fullscreen'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              foregroundColor: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? Colors.redAccent : null,
              ),
              onPressed: () => fp.toggleFavorite(widget.video),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          onPressed: () => _shareVideo(),
        ),
      ],
    );
  }

  Widget _buildVideoInfo(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _decodeHtml(widget.video.title),
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
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
                _statChip(Icons.access_time, widget.video.timeAgo, theme),
            ],
          ),
          const SizedBox(height: 14),

          // Channel info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(
                    0xFFE65100,
                  ).withValues(alpha: 0.15),
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
                      Text('YouTube Channel', style: theme.textTheme.bodySmall),
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
                    gradient: LinearGradient(colors: cat.gradientColors),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.icon, style: const TextStyle(fontSize: 14)),
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
                  Text('Description', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    widget.video.description,
                    maxLines: _isDescriptionExpanded ? null : 3,
                    overflow: _isDescriptionExpanded
                        ? null
                        : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
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

          // Related videos header
          Text('More Videos', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildRelatedVideos() {
    return Consumer<VideoProvider>(
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
    );
  }

  Widget _buildUnavailableBody(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
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
          ),

          // Still show related videos
          _buildVideoInfo(Theme.of(context)),
          _buildRelatedVideos(),
        ],
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

  Future<void> _openInYouTube() async {
    final url = Uri.parse('https://www.youtube.com/watch?v=${widget.video.id}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareVideo() {
    final language = context.read<LocalizationProvider>().currentLanguage;
    final url = 'https://youtu.be/${widget.video.id}';
    final shareText = [
      widget.video.title,
      url,
      '',
      AppStrings.getByLang('shareVideoMessage', language),
      AppConstants.appShareUrl,
    ].join('\n');

    return SharePlus.instance.share(
      ShareParams(text: shareText, subject: widget.video.title),
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
