import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';
import 'ump_consent_service.dart';
import '../models/compass_data.dart';

/// Manages App Open ads lifecycle: loading, caching, and displaying
/// with proper cooldown logic and web simulation support.
///
/// Key features:
/// - Background preloading after AdMob initialization
/// - Configurable cooldown between ad displays (default: 30 seconds)
/// - Configurable timeout for ad loading (default: 10 seconds)
/// - Non-blocking UI - ads never prevent app usage
/// - Web platform support with simulated ads (only when test mode is enabled)
/// - Respects UMP consent status
/// - Initial load completion tracking for seamless first-launch display
/// 
/// All timing parameters are centralized in AdMobConfig for easy tuning.
class AppOpenAdManager {
  // Singleton pattern
  static final AppOpenAdManager _instance = AppOpenAdManager._internal();
  factory AppOpenAdManager() => _instance;
  AppOpenAdManager._internal();

  AppOpenAd? _appOpenAd;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  DateTime? _lastAdShownTime;
  UmpConsentService? _consentService;
  Timer? _adLoadTimeout;
  
  // Completer for tracking initial ad load completion
  Completer<bool>? _initialLoadCompleter;

  /// Initialize the ad manager with consent service reference
  void initialize(UmpConsentService consentService) {
    _consentService = consentService;
    
    // Create completer for initial load tracking
    _initialLoadCompleter = Completer<bool>();
    
    // Start loading ad in background immediately
    if (!kIsWeb && consentService.isMobileAdsInitialized) {
      loadAd();
    } else if (kIsWeb) {
      // On web, complete immediately since we use simulated ads
      _initialLoadCompleter?.complete(false);
    }
  }

  /// Wait for the initial ad load to complete (or timeout/fail)
  /// Returns true if ad loaded successfully, false otherwise
  Future<bool> waitForInitialAdLoad() async {
    if (_initialLoadCompleter == null) {
      return false;
    }
    return await _initialLoadCompleter!.future;
  }

  /// Load an App Open ad in the background with configurable timeout
  void loadAd() {
    // Skip if already loading or on web
    if (_isLoadingAd || kIsWeb) {
      return;
    }

    // Check if we can request ads based on consent
    if (_consentService?.canRequestAds() != true) {
      _completeInitialLoad(false);
      return;
    }

    _isLoadingAd = true;

    // Set up timeout for ad loading (from AdMobConfig)
    _adLoadTimeout = Timer(AdMobConfig.adLoadTimeoutDuration, () {
      if (_isLoadingAd) {
        _isLoadingAd = false;
        _adLoadTimeout = null;
        
        // Complete initial load with failure
        _completeInitialLoad(false);
        
        // Retry loading after a delay if timeout occurred
        Future.delayed(const Duration(seconds: 10), () {
          loadAd();
        });
      }
    });

    // Build ad request based on consent status
    final adRequest = AdRequest(
      nonPersonalizedAds: _consentService?.consentStatus != AdConsentStatus.obtained,
    );

    AppOpenAd.load(
      adUnitId: AdMobConfig.appOpenAdUnitId,
      request: adRequest,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          // Cancel timeout timer on successful load
          _adLoadTimeout?.cancel();
          _adLoadTimeout = null;
          
          _appOpenAd = ad;
          _isLoadingAd = false;
          
          // Complete initial load with success
          _completeInitialLoad(true);
        },
        onAdFailedToLoad: (error) {
          // Cancel timeout timer on failure
          _adLoadTimeout?.cancel();
          _adLoadTimeout = null;
          
          _isLoadingAd = false;
          
          // Complete initial load with failure
          _completeInitialLoad(false);
          
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 10), () {
            loadAd();
          });
        },
      ),
    );
  }

  /// Complete the initial load completer if it hasn't been completed yet
  void _completeInitialLoad(bool success) {
    if (_initialLoadCompleter != null && !_initialLoadCompleter!.isCompleted) {
      _initialLoadCompleter!.complete(success);
    }
  }

  /// Show the ad if available and cooldown period has passed
  /// Returns true if ad was shown or attempted, false if skipped
  /// 
  /// On web: Only shows simulated ad when test mode is enabled in AdMobConfig
  Future<bool> showAdIfAvailable(BuildContext? context) async {
    // On web, show simulated ad only if test mode is enabled
    if (kIsWeb) {
      if (AdMobConfig.isTestMode && context != null && _canShowAd()) {
        await _showSimulatedAd(context);
        return true;
      }
      return false;
    }

    // Don't show if already showing
    if (_isShowingAd) {
      return false;
    }

    // Check cooldown
    if (!_canShowAd()) {
      return false;
    }

    // Check if ad is available
    if (_appOpenAd == null) {
      // Load a new ad for next time
      loadAd();
      return false;
    }

    // Set up ad callbacks
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        _lastAdShownTime = DateTime.now();
        ad.dispose();
        _appOpenAd = null;
        // Preload next ad
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        // Load a new ad
        loadAd();
      },
    );

    // Show the ad
    await _appOpenAd!.show();
    return true;
  }

  /// Check if enough time has passed since last ad (uses AdMobConfig cooldown)
  bool _canShowAd() {
    if (_lastAdShownTime == null) {
      return true;
    }

    final timeSinceLastAd = DateTime.now().difference(_lastAdShownTime!);
    return timeSinceLastAd >= AdMobConfig.adCooldownDuration;
  }

  /// Show a simulated ad on web platform
  /// This mimics the appearance of a real App Open ad
  Future<void> _showSimulatedAd(BuildContext context) async {
    _lastAdShownTime = DateTime.now();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 600,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ad badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Ad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Simulated ad content
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mobile_friendly,
                          size: 80,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'App Open Ad',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Simulated for Web Preview',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF453A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Continue to App'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dispose of the ad manager
  void dispose() {
    _adLoadTimeout?.cancel();
    _adLoadTimeout = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}
