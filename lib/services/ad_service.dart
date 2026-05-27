import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const Duration interstitialInterval = Duration(minutes: 5);
  static const int bannerInterval = 5;

  static const String _androidBannerAdUnitId =
    'ca-app-pub-5079343068930294/5230687089';
  static const String _androidInterstitialAdUnitId =
    'ca-app-pub-5079343068930294/8790658141';
  static const String _iosBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _iosInterstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  static bool get supportsAds {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<InitializationStatus> initialize() {
    return MobileAds.instance.initialize();
  }

  static String get bannerAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidBannerAdUnitId;
      case TargetPlatform.iOS:
        return _iosBannerTestAdUnitId;
      default:
        return '';
    }
  }

  static String get interstitialAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidInterstitialAdUnitId;
      case TargetPlatform.iOS:
        return _iosInterstitialTestAdUnitId;
      default:
        return '';
    }
  }

  static int bannerCountForVideos(int videoCount) {
    return videoCount ~/ bannerInterval;
  }

  static int listItemCountForVideos(int videoCount) {
    return videoCount + bannerCountForVideos(videoCount);
  }

  static bool isBannerIndex(int index) {
    return (index + 1) % (bannerInterval + 1) == 0;
  }

  static int videoIndexForListIndex(int index) {
    return index - ((index + 1) ~/ (bannerInterval + 1));
  }
}