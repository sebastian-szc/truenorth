import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/compass_data.dart';
import 'ump_consent_service.dart';

/// Centralized service for AdMob initialization and configuration.
/// 
/// Handles AdMob initialization state and consent checking for ad requests.
/// Individual screens manage their own ad instances following Google's
/// recommended patterns.
class AdMobService {
  // Singleton pattern
  static final AdMobService _instance = AdMobService._internal();
  static AdMobService get instance => _instance;
  factory AdMobService() => _instance;
  AdMobService._internal();

  UmpConsentService? _consentService;

  /// Initialize the service with consent service reference
  void initialize(UmpConsentService consentService) {
    _consentService = consentService;
  }

  /// Check if the service is properly initialized and ready
  bool get isInitialized => _consentService != null;

  /// Check if we can request ads based on initialization and consent
  bool get canRequestAds {
    return isInitialized &&
        _consentService!.isMobileAdsInitialized &&
        _consentService!.canRequestAds();
  }

  /// Dispose of the ad service
  void dispose() {
    _consentService = null;
  }
}
