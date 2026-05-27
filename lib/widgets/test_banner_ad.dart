import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

class TestBannerAdListItem extends StatefulWidget {
  const TestBannerAdListItem({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final EdgeInsets margin;

  @override
  State<TestBannerAdListItem> createState() => _TestBannerAdListItemState();
}

class _TestBannerAdListItemState extends State<TestBannerAdListItem> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    if (!AdService.supportsAds) {
      return;
    }

    final banner = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
        },
      ),
    );

    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    if (!_isLoaded || bannerAd == null) {
      return const SizedBox(height: 58);
    }

    return Container(
      margin: widget.margin,
      alignment: Alignment.center,
      child: SizedBox(
        width: bannerAd.size.width.toDouble(),
        height: bannerAd.size.height.toDouble(),
        child: AdWidget(ad: bannerAd),
      ),
    );
  }
}