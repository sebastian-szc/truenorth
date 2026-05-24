import 'dart:async';
import 'dart:math' show atan2, pi;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../config/admob_config.dart';
import '../models/compass_data.dart';
import '../services/compass_service.dart';
import '../services/location_service.dart';
import '../services/ump_consent_service.dart';
import '../services/admob_service.dart';
import '../widgets/compass_dial.dart';
import '../widgets/stats_panel.dart';
import '../widgets/calibration_guide.dart';

// Height constant to match bottom navigation bar
const double kBottomNavBarHeight = 80.0;

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  bool _showCalibrationGuide = false;
  BannerAd? _bannerAd;
  AdSize? _bannerAdSize;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    final compassService = context.read<CompassService>();
    final locationService = context.read<LocationService>();
    final consentService = context.read<UmpConsentService>();
    
    // Initialize AdMobService with consent service
    AdMobService.instance.initialize(consentService);
    
    // Start compass
    await compassService.initialize();
    
    // Start location for declination
    await locationService.initialize();
    
    // Monitor stability and show calibration guide if needed
    compassService.addListener(_checkStability);
    
    // Load banner ad after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAd();
    });
  }
  
  void _checkStability() {
    final compassService = context.read<CompassService>();
    final shouldShow = compassService.shouldShowCalibration;
    
    if (shouldShow && !_showCalibrationGuide) {
      setState(() => _showCalibrationGuide = true);
      compassService.markCalibrationShown();
    }
  }
  
  /// Load an anchored adaptive banner ad following Google's official pattern.
  /// 
  /// Gets the screen width using MediaQuery, computes the adaptive ad size,
  /// and creates a BannerAd with comprehensive lifecycle listeners.
  void _loadAd() async {
    // Skip on web - will show simulated banner
    if (kIsWeb) {
      return;
    }
    
    // Check if we can request ads
    if (!AdMobService.instance.isInitialized || 
        !AdMobService.instance.canRequestAds) {
      return;
    }
    
    // Get an AnchoredAdaptiveBannerAdSize before loading the ad
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.sizeOf(context).width.truncate(),
    );
    
    if (size == null) {
      // Unable to get width of anchored banner
      return;
    }
    
    // Store the ad size
    _bannerAdSize = size;
    
    // Get consent service for ad request configuration
    final consentService = context.read<UmpConsentService>();
    
    // Build ad request based on consent status
    final adRequest = AdRequest(
      nonPersonalizedAds: consentService.consentStatus != AdConsentStatus.obtained,
    );
    
    // Create and load the banner ad
    _bannerAd = BannerAd(
      adUnitId: AdMobConfig.bannerAdUnitId,
      request: adRequest,
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // Called when an ad is successfully received
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, err) {
          // Called when an ad request failed
          ad.dispose();
          setState(() {
            _bannerAd = null;
            _bannerAdSize = null;
          });
        },
        onAdOpened: (Ad ad) {
          // Called when an ad opens an overlay that covers the screen
        },
        onAdClosed: (Ad ad) {
          // Called when an ad removes an overlay that covers the screen
        },
        onAdImpression: (Ad ad) {
          // Called when an impression occurs on the ad
        },
        onAdClicked: (Ad ad) {
          // Called when a click event occurs on the ad
        },
        onAdWillDismissScreen: (Ad ad) {
          // iOS only - called before dismissing a full screen view
        },
      ),
    );
    
    await _bannerAd!.load();
  }
  
  @override
  void dispose() {
    context.read<CompassService>().removeListener(_checkStability);
    _bannerAd?.dispose();
    super.dispose();
  }
  
  void _onDialTapped(Offset localPosition, Size dialSize) {
    // Calculate angle from tap position
    final center = Offset(dialSize.width / 2, dialSize.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    // Calculate bearing (0° = North = top)
    double angle = (atan2(dx, -dy) * 180 / pi) % 360;
    if (angle < 0) angle += 360;
    
    // Set target bearing
    context.read<CompassService>().setTargetBearing(angle);
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Target set to ${angle.toStringAsFixed(0)}°'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFFF453A),
      ),
    );
  }
  
  void _clearTarget() {
    context.read<CompassService>().clearTargetBearing();
    HapticFeedback.lightImpact();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Header with banner ad
                _buildHeader(),
                
                // Compass dial with responsive sizing
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: Consumer2<CompassService, LocationService>(
                          builder: (context, compassService, locationService, child) {
                            return CompassDial(
                              heading: compassService.displayHeading,
                              continuousRotation: compassService.continuousRotation,
                              targetBearing: compassService.targetBearing,
                              onTap: _onDialTapped,
                              availableWidth: constraints.maxWidth,
                              availableHeight: constraints.maxHeight,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                
                // Stats panel
                Consumer2<CompassService, LocationService>(
                  builder: (context, compassService, locationService, child) {
                    return StatsPanel(
                      stabilityState: compassService.stabilityState,
                      tiltDegrees: compassService.tiltDegrees,
                      declination: locationService.declination,
                      targetDeviation: compassService.targetDeviation,
                      calibrationAge: compassService.calibrationAge,
                      hasLocation: locationService.hasLocation,
                    );
                  },
                ),
                
                const SizedBox(height: 16),
              ],
            ),
            
            // Calibration guide overlay
            if (_showCalibrationGuide)
              CalibrationGuide(
                onDismiss: () {
                  setState(() => _showCalibrationGuide = false);
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Banner ad area
          _buildBannerAd(),
          
          // Clear target button
          Consumer<CompassService>(
            builder: (context, compassService, child) {
              if (compassService.targetBearing == null) {
                return const SizedBox.shrink();
              }
              
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: _clearTarget,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Target'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF453A),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildBannerAd() {
    // Web simulation - listen to test mode changes
    if (kIsWeb) {
      return ValueListenableBuilder<bool>(
        valueListenable: AdMobConfig.testModeNotifier,
        builder: (context, isTestMode, child) {
          // Only show web banner simulation if test mode is enabled
          if (!isTestMode) {
            // Test ads disabled, don't show banner
            return const SizedBox.shrink();
          }
          return _buildWebBannerSimulation();
        },
      );
    }
    
    // Display loaded ad
    if (_bannerAd != null && _bannerAdSize != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: SizedBox(
            width: _bannerAdSize!.width.toDouble(),
            height: _bannerAdSize!.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      );
    }
    
    // Reserved space for banner - no text, just empty space
    return Container(
      height: kBottomNavBarHeight,
    );
  }
  
  /// Build a simulated banner for web platform.
  Widget _buildWebBannerSimulation() {
    return Container(
      width: double.infinity,
      height: kBottomNavBarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Stack(
        children: [
          // Ad badge in top left
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'Ad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Simulated ad content
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ads_click, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Adaptive Banner - Web Preview',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
