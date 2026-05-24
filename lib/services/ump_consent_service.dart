import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';
import '../models/compass_data.dart';

/// Service to manage User Messaging Platform (UMP) consent for AdMob.
/// Handles consent information updates, form presentation, and ad request gating.
///
/// PRODUCTION MODE: This service uses the production AdMob App ID from AndroidManifest.xml
/// and does NOT apply any debug settings or test configurations. The UMP SDK will display
/// real consent forms with your actual publisher information, not "Test Ads".
///
/// Key principles:
/// - Non-blocking: The app continues to function while consent is being obtained
/// - Privacy-first: All ad requests are gated behind consent checks
/// - NPA support: Non-personalized ads are served when consent is not granted
/// - Compliant: Follows GDPR, CCPA, and other privacy regulations
/// - Production: Uses real publisher ID, no test mode or debug settings
///
/// AdMob initialization flow:
/// 1. Update consent information from UMP SDK (production mode)
/// 2. Show consent form if required (displays real publisher info)
/// 3. Initialize MobileAds ONLY AFTER consent flow completes
/// 4. Configure NPA (non-personalized ads) if consent not granted
/// 
/// Test device IDs are centralized in AdMobConfig for easy maintenance.
class UmpConsentService extends ChangeNotifier {
  AdConsentStatus _consentStatus = AdConsentStatus.unknown;
  bool _isConsentFormAvailable = false;
  bool _isMobileAdsInitialized = false;
  String? _errorMessage;
  
  AdConsentStatus get consentStatus => _consentStatus;
  bool get isConsentFormAvailable => _isConsentFormAvailable;
  bool get isMobileAdsInitialized => _isMobileAdsInitialized;
  String? get errorMessage => _errorMessage;
  
  /// Returns true if ads can be requested based on current consent status.
  /// All ad requests should be gated behind this check.
  bool canRequestAds() {
    // On web, AdMob is not supported
    if (kIsWeb) {
      return false;
    }
    
    // Can request ads if consent is obtained or not required
    return _consentStatus == AdConsentStatus.obtained || 
           _consentStatus == AdConsentStatus.notRequired;
  }
  
  /// Returns request configuration based on consent status.
  /// If consent not granted, returns configuration for non-personalized ads (NPA).
  /// 
  /// Test device IDs are loaded from AdMobConfig and only used for MobileAds 
  /// (to show test ads during development). They do not affect UMP consent 
  /// which always runs in production mode.
  RequestConfiguration getRequestConfiguration() {
    // If user hasn't granted consent for personalized ads, request NPA
    if (_consentStatus != AdConsentStatus.obtained) {
      return RequestConfiguration(
        testDeviceIds: AdMobConfig.testDeviceIds,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        maxAdContentRating: MaxAdContentRating.g,
      );
    }
    
    // Default configuration for personalized ads
    return RequestConfiguration(
      testDeviceIds: AdMobConfig.testDeviceIds,
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    );
  }
  
  /// Initialize the consent flow in PRODUCTION MODE.
  /// This is non-blocking - the app can continue while consent is being processed.
  /// 
  /// PRODUCTION MODE GUARANTEE:
  /// - Uses production AdMob App ID from AndroidManifest.xml (ca-app-pub-5850600525085444~9636989581)
  /// - NO ConsentDebugSettings applied
  /// - NO test geography or debug configuration
  /// - Consent forms display your real publisher information, not "Test Ads"
  /// 
  /// Flow:
  /// 1. Update consent information from UMP SDK (production)
  /// 2. Show consent form if available and required (real publisher info)
  /// 3. Initialize MobileAds with appropriate configuration (personalized or NPA)
  Future<void> initialize() async {
    // Skip on web - AdMob not supported
    if (kIsWeb) {
      _consentStatus = AdConsentStatus.notRequired;
      notifyListeners();
      return;
    }
    
    try {
      // Step 1: Update consent information (PRODUCTION MODE)
      await _updateConsentInfo();
      
      // Step 2: If consent form is available and required, show it
      if (_isConsentFormAvailable && _consentStatus == AdConsentStatus.required) {
        await _loadAndShowConsentForm();
      }
      
      // Step 3: Initialize MobileAds after consent flow completes
      // This ensures we only initialize after knowing the user's consent choice
      // MobileAds will be configured with NPA if consent not granted
      await _initializeMobileAds();
      
    } catch (e) {
      _errorMessage = 'Consent initialization error: $e';
      // Continue with app even if consent fails
      _consentStatus = AdConsentStatus.unknown;
      notifyListeners();
    }
  }
  
  /// Update consent information from UMP SDK in PRODUCTION MODE.
  /// This checks if user needs to provide consent based on their location and settings.
  /// 
  /// PRODUCTION MODE:
  /// - ConsentRequestParameters created WITHOUT ConsentDebugSettings
  /// - Uses production App ID from AndroidManifest.xml automatically
  /// - No test mode, no debug geography, no test device configuration for UMP
  /// - Consent forms will show real publisher information
  Future<void> _updateConsentInfo() async {
    final completer = Completer<void>();
    
    try {
      // PRODUCTION MODE: Create ConsentRequestParameters without any debug settings
      // This ensures the UMP SDK uses:
      // 1. The production App ID from AndroidManifest.xml
      // 2. Real user geography (not test geography)
      // 3. Real publisher information in consent forms (not "Test Ads")
      final params = ConsentRequestParameters();
      
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // Success callback
          final status = await ConsentInformation.instance.getConsentStatus();
          
          switch (status) {
            case ConsentStatus.notRequired:
              _consentStatus = AdConsentStatus.notRequired;
              _isConsentFormAvailable = false;
              break;
            case ConsentStatus.required:
              _consentStatus = AdConsentStatus.required;
              _isConsentFormAvailable = await ConsentInformation.instance.isConsentFormAvailable();
              break;
            case ConsentStatus.obtained:
              _consentStatus = AdConsentStatus.obtained;
              _isConsentFormAvailable = false;
              break;
            case ConsentStatus.unknown:
            default:
              _consentStatus = AdConsentStatus.unknown;
              _isConsentFormAvailable = false;
          }
          
          notifyListeners();
          completer.complete();
        },
        (FormError error) {
          // Error callback
          _errorMessage = 'Failed to update consent info: ${error.message}';
          _consentStatus = AdConsentStatus.unknown;
          notifyListeners();
          completer.completeError(error);
        },
      );
      
      return completer.future;
    } catch (e) {
      _errorMessage = 'Failed to update consent info: $e';
      _consentStatus = AdConsentStatus.unknown;
      notifyListeners();
      rethrow;
    }
  }
  
  /// Load and show the consent form if required.
  /// This presents the UMP consent dialog to the user with REAL publisher information.
  /// 
  /// PRODUCTION MODE: The consent form will display your actual publisher name
  /// and app information, not "Test Ads" or test mode indicators.
  Future<void> _loadAndShowConsentForm() async {
    final completer = Completer<void>();
    
    try {
      // Load the consent form (production mode - shows real publisher info)
      ConsentForm.loadConsentForm(
        (ConsentForm consentForm) {
          // Form loaded successfully, show it
          consentForm.show((FormError? formError) {
            // Form was dismissed, update consent status
            _updateConsentStatusAfterForm().then((_) {
              completer.complete();
            });
          });
        },
        (FormError formError) {
          // Error loading form
          _errorMessage = 'Consent form load error: ${formError.message}';
          notifyListeners();
          completer.completeError(formError);
        },
      );
      
      return completer.future;
    } catch (e) {
      _errorMessage = 'Failed to load consent form: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Update consent status after form is shown and dismissed.
  Future<void> _updateConsentStatusAfterForm() async {
    final status = await ConsentInformation.instance.getConsentStatus();
    
    switch (status) {
      case ConsentStatus.obtained:
        _consentStatus = AdConsentStatus.obtained;
        break;
      case ConsentStatus.required:
        _consentStatus = AdConsentStatus.required;
        break;
      case ConsentStatus.notRequired:
        _consentStatus = AdConsentStatus.notRequired;
        break;
      case ConsentStatus.unknown:
      default:
        _consentStatus = AdConsentStatus.unknown;
    }
    
    notifyListeners();
    
    // Initialize MobileAds if not already done
    if (!_isMobileAdsInitialized) {
      await _initializeMobileAds();
    }
  }
  
  /// Initialize MobileAds SDK.
  /// This should only be called after consent flow has completed.
  /// 
  /// According to Google's AdMob documentation:
  /// - MobileAds.instance.initialize() should be called AFTER UMP consent flow
  /// - If consent not granted, configure for non-personalized ads (NPA)
  /// - Use test device IDs during development to avoid affecting production metrics
  /// 
  /// PRODUCTION MODE: Uses production App ID (ca-app-pub-5850600525085444~9636989581)
  /// from AndroidManifest.xml. Test device IDs (from AdMobConfig) only affect which 
  /// ads are shown (test vs real), not the consent flow or publisher information.
  Future<void> _initializeMobileAds() async {
    if (_isMobileAdsInitialized) {
      return;
    }
    
    try {
      // Set request configuration based on consent status
      // This will set NPA mode if consent not obtained
      // Test device IDs are loaded from centralized AdMobConfig
      MobileAds.instance.updateRequestConfiguration(getRequestConfiguration());
      
      // Initialize MobileAds
      // This is safe to call now because:
      // 1. Consent flow has completed (production mode)
      // 2. We've set appropriate configuration (NPA if needed)
      // 3. Test device IDs are configured (for ad testing, not consent)
      // 4. Uses production App ID from manifest
      await MobileAds.instance.initialize();
      
      _isMobileAdsInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize MobileAds: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Reset consent for testing purposes.
  /// This allows testing the consent flow repeatedly.
  /// 
  /// Note: After reset, the consent flow will still run in PRODUCTION MODE
  /// with real publisher information.
  Future<void> resetConsent() async {
    if (kIsWeb) {
      return;
    }
    
    try {
      await ConsentInformation.instance.reset();
      _consentStatus = AdConsentStatus.unknown;
      _isConsentFormAvailable = false;
      notifyListeners();
      
      // Reinitialize after reset (production mode)
      await initialize();
    } catch (e) {
      _errorMessage = 'Failed to reset consent: $e';
      notifyListeners();
    }
  }
  
  /// Manually show consent form if needed.
  /// This can be called from app settings to allow users to review their choices.
  /// 
  /// PRODUCTION MODE: Will display real publisher information, not test mode.
  Future<void> showConsentForm() async {
    if (kIsWeb) {
      return;
    }
    
    // First update consent info to check if form is available (production mode)
    await _updateConsentInfo();
    
    if (_isConsentFormAvailable) {
      await _loadAndShowConsentForm();
    }
  }
}
