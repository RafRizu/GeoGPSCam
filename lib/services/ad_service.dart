import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized AdMob service managing banner, interstitial, and rewarded ads.
/// Automatically uses Google test unit IDs in debug mode to prevent account bans.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ═══════════════════════════════════════════════
  // MASTER TOGGLE: Ubah ke true jika ingin mengaktifkan iklan kembali
  // ═══════════════════════════════════════════════
  static const bool kAdsMasterEnabled = true;

  // ═══════════════════════════════════════════════
  // Ad Unit IDs (AdMob Production vs Test)
  // ═══════════════════════════════════════════════
  // Official Google AdMob sample test unit IDs (aman untuk development/testing)
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // Production Ad Unit IDs
  static const String _prodBannerAdUnitId =
      'ca-app-pub-1043267437078861/3241735766';
  static const String _prodInterstitialAdUnitId =
      'ca-app-pub-1043267437078861/3848862544';
  static const String _prodRewardedAdUnitId =
      'ca-app-pub-1043267437078861/1928654093';

  // Otomatis pakai ID Test saat Debug, ID Asli saat Release (Mencegah banned AdMob)
  static String get bannerAdUnitId =>
      kDebugMode ? _testBannerAdUnitId : _prodBannerAdUnitId;
  static String get interstitialAdUnitId =>
      kDebugMode ? _testInterstitialAdUnitId : _prodInterstitialAdUnitId;
  static String get rewardedAdUnitId =>
      kDebugMode ? _testRewardedAdUnitId : _prodRewardedAdUnitId;

  bool _isInitialized = false;
  bool _adsDisabled = false; // True when user is ad-free or earned reward

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialReady = false;
  bool _isRewardedReady = false;

  // Track reward temporary ad-free
  DateTime? _rewardExpiryTime;

  bool get adsDisabled => _adsDisabled;
  bool get isRewardedReady => kAdsMasterEnabled && _isRewardedReady;

  /// Check if ads should be shown (not ad-free AND not temporarily rewarded)
  bool get shouldShowAds {
    if (!kAdsMasterEnabled) return false;
    if (_adsDisabled) return false;
    if (_rewardExpiryTime != null &&
        DateTime.now().isBefore(_rewardExpiryTime!)) {
      return false;
    }
    return true;
  }

  /// Initialize Mobile Ads SDK with optional test device IDs
  Future<void> initialize({List<String>? testDeviceIds}) async {
    if (!kAdsMasterEnabled) return;
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      if (testDeviceIds != null && testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: testDeviceIds),
        );
      }
      _isInitialized = true;
      debugPrint(
        'AdMob initialized successfully (Mode: ${kDebugMode ? "TEST (Debug)" : "PRODUCTION (Release)"})',
      );
    } catch (e) {
      debugPrint('AdMob init error: $e');
    }
  }

  /// Disable all ads (for ad-free users)
  void disableAds() {
    _adsDisabled = true;
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
    _isInterstitialReady = false;
    _isRewardedReady = false;
  }

  /// Enable ads (for non-ad-free users)
  void enableAds() {
    _adsDisabled = false;
  }

  // ═══════════════════════════════════════════════
  // BANNER AD
  // ═══════════════════════════════════════════════

  /// Create a banner ad instance
  BannerAd createBannerAd({
    VoidCallback? onLoaded,
    VoidCallback? onFailed,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded');
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('⚠️ Banner ad failed to load [Code ${error.code}]: ${error.message}');
          ad.dispose();
          onFailed?.call();
        },
        onAdOpened: (ad) => debugPrint('Banner ad opened'),
        onAdClosed: (ad) => debugPrint('Banner ad closed'),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // INTERSTITIAL AD
  // ═══════════════════════════════════════════════

  /// Preload interstitial ad
  Future<void> loadInterstitialAd() async {
    if (!kAdsMasterEnabled || _adsDisabled || !_isInitialized) return;

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          debugPrint('Interstitial ad loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialReady = false;
              _interstitialAd = null;
              // Preload next one
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialReady = false;
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ Interstitial ad failed to load [Code ${error.code}]: ${error.message}');
          _isInterstitialReady = false;
        },
      ),
    );
  }

  /// Show interstitial ad (returns true if shown)
  Future<bool> showInterstitialAd() async {
    if (!shouldShowAds || !_isInterstitialReady || _interstitialAd == null) {
      return false;
    }

    try {
      await _interstitialAd!.show();
      return true;
    } catch (e) {
      debugPrint('Show interstitial error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // REWARDED AD
  // ═══════════════════════════════════════════════

  /// Preload rewarded ad
  Future<void> loadRewardedAd() async {
    if (!kAdsMasterEnabled || !_isInitialized) return;

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedReady = true;
          debugPrint('Rewarded ad loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedReady = false;
              _rewardedAd = null;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isRewardedReady = false;
              _rewardedAd = null;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ Rewarded ad failed to load [Code ${error.code}]: ${error.message}');
          _isRewardedReady = false;
        },
      ),
    );
  }

  /// Show rewarded ad — grants temporary ad-free for 30 minutes
  Future<bool> showRewardedAd({
    VoidCallback? onRewarded,
  }) async {
    if (!_isRewardedReady || _rewardedAd == null) return false;

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('User earned reward: ${reward.amount} ${reward.type}');
          // Grant 30 minutes ad-free
          _rewardExpiryTime = DateTime.now().add(const Duration(minutes: 30));
          onRewarded?.call();
        },
      );
      return true;
    } catch (e) {
      debugPrint('Show rewarded error: $e');
      return false;
    }
  }

  /// Get remaining reward time
  Duration? get remainingRewardTime {
    if (_rewardExpiryTime == null) return null;
    final remaining = _rewardExpiryTime!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Dispose all ads
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}
