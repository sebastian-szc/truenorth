import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized AdMob configuration for the True North app.
/// 
/// This class contains all AdMob ad unit IDs, test device configurations,
/// and timing parameters in a single location for easy maintenance and updates.
/// 
/// Ad Unit IDs:
/// - App Open Ad: Shown on app launch and resume (with cooldown)
/// - Banner Ad: Displayed at the top of the compass screen
/// 
/// Test Mode:
/// When `isTestMode` is true, the app uses official Google test ad unit IDs
/// instead of production IDs. This allows safe testing of ad integration
/// without affecting production metrics or violating AdMob policies.
/// 
/// Test mode can be toggled in the debug menu (web only) and persists across
/// app sessions. On web, changes take effect immediately. On mobile, changes
/// require an app restart to take effect.
/// 
/// Default test mode value:
/// - Web: true (test ads enabled for demo purposes)
/// - Mobile: false (production ads)
/// 
/// Official test ad unit IDs are provided by Google AdMob:
/// https://developers.google.com/admob/android/test-ads
/// 
/// Timing Parameters:
/// - Splash Timeout: Maximum time to show splash screen while initializing
/// - Ad Load Timeout: Maximum time to wait for app open ad to load
/// - Ad Cooldown: Minimum time between showing app open ads
/// 
/// Rate Dialog Configuration:
/// - Web: Shows on every app open for demo purposes
/// - Mobile: Shows initially on configured open count, then every N opens after dismissal
/// - Show Again Interval: Number of opens between rate dialog displays after dismissal
/// 
/// Test Device IDs:
/// Add your test device IDs to the list below for development testing.
/// These IDs are used by MobileAds to show test ads instead of production ads
/// during development, without affecting the UMP consent flow.
class AdMobConfig {
  // Private constructor to prevent instantiation
  AdMobConfig._();
  
  // SharedPreferences key for test mode
  static const String _testModeKey = 'admob_test_mode';
  
  /// Test Mode Notifier
  /// 
  /// A ValueNotifier that tracks the current test mode state and notifies
  /// listeners when it changes. This enables reactive UI updates when test
  /// mode is toggled in settings.
  /// 
  /// Default value:
  /// - Web: true (test ads enabled by default for demo purposes)
  /// - Mobile: false (production ads by default)
  /// 
  /// Listeners can subscribe to changes using ValueListenableBuilder or
  /// addListener() to rebuild UI when test mode changes.
  static final ValueNotifier<bool> testModeNotifier = ValueNotifier(kIsWeb);
  
  /// Test Mode Flag (read-only property)
  /// 
  /// Returns the current test mode state from the notifier.
  /// 
  /// When true: Uses official AdMob test ad unit IDs
  /// When false: Uses production ad unit IDs
  /// 
  /// To change the value, use setTestMode() which updates both the notifier
  /// and persists the value to SharedPreferences.
  static bool get isTestMode => testModeNotifier.value;
  
  /// Initialize test mode from SharedPreferences
  /// 
  /// Should be called early in main() before any AdMob initialization.
  /// Loads the persisted test mode preference, defaulting to:
  /// - true on web (for demo purposes)
  /// - false on mobile (production mode)
  static Future<void> initializeTestMode() async {
    final prefs = await SharedPreferences.getInstance();
    testModeNotifier.value = prefs.getBool(_testModeKey) ?? kIsWeb;
  }
  
  /// Update test mode and persist to SharedPreferences
  /// 
  /// Updates the testModeNotifier which immediately triggers UI updates
  /// in any listening widgets (like CompassScreen's banner ad).
  /// 
  /// On web: Changes take effect immediately (banner appears/disappears)
  /// On mobile: Changes require app restart since MobileAds is initialized once
  /// 
  /// Returns true if the value was successfully saved to SharedPreferences.
  static Future<bool> setTestMode(bool value) async {
    testModeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_testModeKey, value);
  }
  
  // Production Ad Unit IDs
  static const String _productionAppOpenAdUnitId = 'ca-app-pub-5850600525085444/9246747978';
  static const String _productionBannerAdUnitId = 'ca-app-pub-5850600525085444/2031752681';
  
  // Official Google AdMob Test Ad Unit IDs
  // Source: https://developers.google.com/admob/android/test-ads
  static const String _testAppOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  
  /// App Open Ad Unit ID
  /// Displayed when the app is opened or resumed from background
  /// Returns test ID when isTestMode is true, production ID otherwise
  static String get appOpenAdUnitId => 
      isTestMode ? _testAppOpenAdUnitId : _productionAppOpenAdUnitId;
  
  /// Banner Ad Unit ID
  /// Displayed at the top of the compass screen
  /// Returns test ID when isTestMode is true, production ID otherwise
  static String get bannerAdUnitId => 
      isTestMode ? _testBannerAdUnitId : _productionBannerAdUnitId;
  
  // Timing Configuration
  
  /// Splash Screen Timeout Duration
  /// Maximum time to show splash screen while initializing the app.
  /// If initialization (UMP consent + AdMob + App Open Ad loading) takes
  /// longer than this, the app proceeds to main screen anyway.
  /// 
  /// Default: 10 seconds
  static const Duration splashTimeoutDuration = Duration(seconds: 10);
  
  /// App Open Ad Load Timeout Duration
  /// Maximum time to wait for an app open ad to load.
  /// If the ad doesn't load within this time, the app proceeds without
  /// blocking the user, and retries loading after a delay.
  /// 
  /// Default: 10 seconds
  static const Duration adLoadTimeoutDuration = Duration(seconds: 10);
  
  /// App Open Ad Cooldown Duration
  /// Minimum time that must pass between showing app open ads.
  /// This prevents ads from being shown too frequently when the user
  /// switches between apps or reopens the app multiple times.
  /// 
  /// Default: 30 seconds
  static const Duration adCooldownDuration = Duration(seconds: 30);
  
  // Rate App Dialog Configuration
  
  /// Platform-specific configuration for rate app dialog display
  /// 
  /// Web Platform:
  /// - Shows on every app open when `showRateDialogOnEveryOpenWeb` is true
  /// - Useful for demo purposes to show the rate dialog repeatedly
  /// 
  /// Mobile Platforms (Android/iOS):
  /// - Shows once on the app open count specified by `rateDialogShowOnOpenCountMobile`
  /// - If user clicks "not this time", shows again every `rateDialogShowAgainInterval` opens
  /// - If user clicks "Rate app", never shows again (tracked via SharedPreferences)
  
  /// Show rate dialog on every app open (web platform only)
  /// 
  /// When true: Dialog appears on every app open on web (for demo purposes)
  /// When false: Dialog appears once on the open count specified by `rateDialogShowOnOpenCountWeb`
  /// 
  /// Default: true (enables demo mode on web)
  static const bool showRateDialogOnEveryOpenWeb = true;
  
  /// App open count when rate dialog should be shown initially (mobile platforms)
  /// 
  /// The dialog will appear once when the app has been opened this many times.
  /// After that, behavior depends on user action:
  /// - If user clicks "not this time": dialog reappears every `rateDialogShowAgainInterval` opens
  /// - If user clicks "Rate app": dialog never shows again
  /// 
  /// Default: 3 (shows on 3rd app open)
  static const int rateDialogShowOnOpenCountMobile = 3;
  
  /// Interval (in app opens) between rate dialog displays after user dismissal
  /// 
  /// After the user clicks "not this time", the dialog will reappear
  /// after this many additional app opens. This creates a recurring
  /// reminder pattern that continues until the user rates the app.
  /// 
  /// Example with interval of 10:
  /// - First show: 3rd open
  /// - User dismisses -> Next show: 13th open (3 + 10)
  /// - User dismisses -> Next show: 23rd open (13 + 10)
  /// - User rates -> Never shows again
  /// 
  /// Default: 10 opens
  static const int rateDialogShowAgainInterval = 10;
  
  /// Test Device IDs for development testing
  /// 
  /// To find your device ID:
  /// 1. Run your app on a device
  /// 2. Check logcat (Android Studio) for a message like:
  ///    "Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList(\"33BE2250...\"))"
  /// 3. Copy the device ID from the log message
  /// 4. Add it to the list below
  /// 
  /// Example: ['33BE2250B43518CCDA7DE426D04EE231', 'ANOTHER_TEST_DEVICE_ID']
  /// 
  /// Note: These IDs only affect which ads are shown (test vs real),
  /// they do not affect the UMP consent flow which always uses production mode.
  static const List<String> testDeviceIds = [
    // Add your test device IDs here for MobileAds testing
    // UMP consent will still use production mode regardless
  ];
}
