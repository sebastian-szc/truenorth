import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/compass_screen.dart';
import 'screens/location_screen.dart';
import 'screens/expert_mode_screen.dart';
import 'screens/settings_screen.dart';
import 'services/compass_service.dart';
import 'services/location_service.dart';
import 'services/ump_consent_service.dart';
import 'services/app_open_ad_manager.dart';
import 'config/admob_config.dart';
import 'widgets/rate_app_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AdMob test mode from SharedPreferences
  await AdMobConfig.initializeTestMode();
  
  // Keep screen awake during compass usage
  WakelockPlus.enable();
  
  // Set portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const TrueNorthApp());
}

class TrueNorthApp extends StatelessWidget {
  const TrueNorthApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create consent service to be used throughout the app
    final consentService = UmpConsentService();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CompassService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider.value(value: consentService),
      ],
      child: MaterialApp(
        title: 'Compass Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF000000),
          primaryColor: const Color(0xFFFF453A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF453A),
            surface: Color(0xFF121212),
            background: Color(0xFF000000),
            onPrimary: Colors.white,
            onSurface: Colors.white,
            onBackground: Colors.white,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF121212),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
            headlineMedium: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            labelSmall: TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1C1C1E),
            selectedItemColor: Color(0xFFFF453A),
            unselectedItemColor: Colors.white60,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),
        ),
        home: const AppContainer(),
      ),
    );
  }
}

/// Container that manages the transition from splash screen to main screen.
/// 
/// Handles:
/// - Displaying splash screen during initialization
/// - Running initialization sequence with platform-specific behavior
/// - Configurable timeout on mobile (from AdMobConfig)
/// - 3-second display on web
/// - Showing rate dialog with smart recurring logic
/// - Transitioning to main screen after initialization
class AppContainer extends StatefulWidget {
  const AppContainer({super.key});

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  /// Initialize the app with platform-specific behavior.
  /// 
  /// Web platform:
  /// - Shows splash for exactly 3 seconds
  /// - Skips UMP/AdMob initialization
  /// - Shows rate dialog on every open (if configured)
  /// 
  /// Mobile platforms:
  /// - Runs full initialization sequence
  /// - UMP consent -> AdMob -> App Open Ad Manager -> Wait for initial ad load
  /// - Maximum time: AdMobConfig.splashTimeoutDuration (with timeout)
  /// - Shows rate dialog with smart recurring logic
  Future<void> _initializeApp() async {
    try {
      if (kIsWeb) {
        // On web, just show splash for 3 seconds
        await Future.delayed(const Duration(seconds: 3));
      } else {
        // On mobile, run full initialization with configurable timeout
        await Future.any([
          _performInitialization(),
          Future.delayed(AdMobConfig.splashTimeoutDuration),
        ]);
      }
    } catch (e) {
      // Continue even if initialization fails
      // The app should work without ads
    }
    
    // Check if we should show rate dialog based on platform configuration
    // This happens after initialization but before main screen
    await _checkAndShowRateDialog();
    
    // Transition to main screen
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }
  
  /// Perform the actual initialization sequence.
  /// 
  /// This now waits for the initial app open ad to load (or timeout)
  /// before completing, ensuring the ad is ready to display when the
  /// compass screen appears.
  Future<void> _performInitialization() async {
    final consentService = Provider.of<UmpConsentService>(context, listen: false);
    
    // Initialize UMP consent and AdMob
    // This will show the UMP consent form if needed (first launch)
    await consentService.initialize();
    
    // Initialize App Open Ad Manager after AdMob is ready
    if (consentService.isMobileAdsInitialized) {
      AppOpenAdManager().initialize(consentService);
      
      // Wait for the initial ad to load (or timeout/fail)
      // This ensures the ad is ready to display when we show the compass screen
      await AppOpenAdManager().waitForInitialAdLoad();
    }
  }
  
  /// Check if rate dialog should be shown based on platform-specific configuration.
  /// 
  /// Web Platform:
  /// - If AdMobConfig.showRateDialogOnEveryOpenWeb is true: Shows on every open
  /// - Useful for demo purposes to repeatedly show the rate dialog
  /// 
  /// Mobile Platforms:
  /// - Shows on 3rd open initially (or any open after 3rd if previously missed)
  /// - If user clicks "not this time": remembers and shows again every 10 opens
  /// - If user clicks "Rate app": never shows again (permanent dismissal)
  /// - Tracks user choice via SharedPreferences
  /// - Uses >= comparison to handle edge cases where count exceeds target
  Future<void> _checkAndShowRateDialog() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Always increment app open count (used for mobile logic)
    final appOpenCount = (prefs.getInt('app_open_count') ?? 0) + 1;
    await prefs.setInt('app_open_count', appOpenCount);
    
    bool shouldShowDialog = false;
    
    if (kIsWeb) {
      // Web platform: show on every open if configured (for demo purposes)
      if (AdMobConfig.showRateDialogOnEveryOpenWeb) {
        shouldShowDialog = true;
      }
    } else {
      // Mobile platforms: smart recurring logic with robust edge case handling
      final hasRated = prefs.getBool('rate_dialog_rated') ?? false;
      
      if (hasRated) {
        // User has rated the app, never show again
        return;
      }
      
      final lastDismissedCount = prefs.getInt('rate_dialog_last_dismissed_count') ?? 0;
      final hasShownDialog = prefs.getBool('rate_dialog_has_shown') ?? false;
      
      if (lastDismissedCount == 0 && !hasShownDialog) {
        // Never shown before, show on or after configured open count (default: 3)
        // Using >= handles edge cases where count exceeds target (e.g., during development)
        shouldShowDialog = (appOpenCount >= AdMobConfig.rateDialogShowOnOpenCountMobile);
      } else if (lastDismissedCount > 0) {
        // Has been dismissed before, show every N opens after last dismissal
        shouldShowDialog = (appOpenCount - lastDismissedCount >= AdMobConfig.rateDialogShowAgainInterval);
      }
    }
    
    // Show dialog if conditions are met
    if (shouldShowDialog && mounted) {
      // Mark that we've shown the dialog at least once (prevents multiple consecutive shows)
      if (!kIsWeb) {
        final hasShownDialog = prefs.getBool('rate_dialog_has_shown') ?? false;
        if (!hasShownDialog) {
          await prefs.setBool('rate_dialog_has_shown', true);
        }
      }
      
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const RateAppDialog(),
      );
      
      // Handle user's choice (mobile only, web just shows dialog)
      if (!kIsWeb && result != null) {
        if (result == true) {
          // User clicked "Rate app on Google Play" - never show again
          await prefs.setBool('rate_dialog_rated', true);
        } else {
          // User clicked "not this time" - remember count and show again in 10 opens
          await prefs.setInt('rate_dialog_last_dismissed_count', appOpenCount);
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Show splash screen during initialization
    if (!_isInitialized) {
      return const SplashScreen();
    }
    
    // Show main screen after initialization
    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CompassScreen(),
    LocationScreen(),
    ExpertModeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Register as lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Show app open ad if ready
    // App open count is now tracked in AppContainer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAppOpenAd();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Show App Open ad
  Future<void> _showAppOpenAd() async {
    if (!mounted) return;
    
    await AppOpenAdManager().showAdIfAvailable(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Show ad when app comes to foreground (resumed)
    // Cooldown is managed by AppOpenAdManager
    if (state == AppLifecycleState.resumed) {
      _showAppOpenAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Compass',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Location',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune),
            label: 'Expert Mode',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
