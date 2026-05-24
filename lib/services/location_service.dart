import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  double? _declination;
  DateTime? _declinationCalculatedAt;
  bool _hasLocation = false;
  String? _errorMessage;
  bool _isUsingLastKnown = false;
  
  static const _declinationCacheDuration = Duration(minutes: 5);
  
  // Getters
  Position? get currentPosition => _currentPosition;
  double? get declination => _declination;
  bool get hasLocation => _hasLocation;
  String? get errorMessage => _errorMessage;
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;
  double? get accuracy => _currentPosition?.accuracy;
  bool get isUsingLastKnown => _isUsingLastKnown;
  
  Future<void> initialize() async {
    try {
      // Master timeout to ensure initialization never hangs indefinitely
      await _initializeWithTimeout().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _errorMessage = 'Location initialization timed out. Please check your location settings and try again.';
          _hasLocation = false;
          _isUsingLastKnown = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Unexpected error during initialization: $e';
      _hasLocation = false;
      _isUsingLastKnown = false;
      notifyListeners();
    }
  }
  
  Future<void> _initializeWithTimeout() async {
    if (kIsWeb) {
      // Try to get location on web (might work with HTTPS)
      // If it fails, provide fake data for UI preview
      await _tryGetLocationOrFake();
    } else {
      // Mobile platform
      await _checkPermissionAndGetLocation();
    }
  }
  
  Future<void> requestPermission() async {
    // Clear previous error
    _errorMessage = null;
    notifyListeners();
    
    // Re-attempt full initialization
    await initialize();
  }
  
  Future<void> _tryGetLocationOrFake() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5));
      if (!serviceEnabled) {
        _setFakeLocation();
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 8));
      }
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setFakeLocation();
        return;
      }
      
      await _getLocation();
    } catch (e) {
      // If any error occurs, use fake data
      _setFakeLocation();
    }
  }
  
  void _setFakeLocation() {
    // Provide fake location data for web preview (San Francisco coordinates)
    _currentPosition = Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    _hasLocation = true;
    _errorMessage = null;
    _isUsingLastKnown = false;
    
    // Calculate declination for fake location
    _calculateDeclination();
  }
  
  Future<void> _checkPermissionAndGetLocation() async {
    try {
      // Check if location services are enabled with timeout
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Location service check timed out'),
          );
          
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled. Please enable location services in your device settings.';
        _hasLocation = false;
        notifyListeners();
        return;
      }
      
      // Always request permission explicitly to ensure GPS initialization
      // This helps trigger GPS even when permission was previously granted
      LocationPermission permission;
      try {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException('Permission request timed out'),
        );
      } on TimeoutException catch (_) {
        // If permission request times out, check current permission status
        permission = await Geolocator.checkPermission();
      }
      
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permission denied. Grant permission to use location features.';
        _hasLocation = false;
        notifyListeners();
        return;
      }
      
      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Location permission permanently denied. Enable it in app settings to use location features.';
        _hasLocation = false;
        notifyListeners();
        return;
      }
      
      // Get position with timeout and fallback
      await _getLocation();
    } on TimeoutException catch (_) {
      _errorMessage = 'Location request timed out. Please ensure GPS is enabled and has a clear view of the sky.';
      _hasLocation = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error accessing location: $e';
      _hasLocation = false;
      notifyListeners();
    }
  }
  
  Future<void> _getLocation() async {
    try {
      // Try to get current position with 10-second timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentPosition = position;
      _hasLocation = true;
      _errorMessage = null;
      _isUsingLastKnown = false;
      
      // Calculate declination
      await _calculateDeclination();
      
      notifyListeners();
    } on TimeoutException catch (_) {
      // Timeout occurred - try last known position as fallback
      await _tryLastKnownPosition();
    } catch (e) {
      // Other error - try last known position as fallback
      await _tryLastKnownPosition();
    }
  }
  
  Future<void> _tryLastKnownPosition() async {
    try {
      // Add timeout to getLastKnownPosition to prevent hanging
      final lastKnown = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      
      if (lastKnown != null) {
        _currentPosition = lastKnown;
        _hasLocation = true;
        _errorMessage = null;
        _isUsingLastKnown = true;
        
        // Calculate declination
        await _calculateDeclination();
        
        notifyListeners();
      } else {
        // No last known position available
        _errorMessage = 'Could not get location. Please ensure GPS is enabled and has a clear view of the sky, then try again.';
        _hasLocation = false;
        _isUsingLastKnown = false;
        notifyListeners();
      }
    } on TimeoutException catch (_) {
      _errorMessage = 'Location request timed out. Please ensure GPS is enabled and try again.';
      _hasLocation = false;
      _isUsingLastKnown = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not get location. Please ensure GPS is enabled and try again.';
      _hasLocation = false;
      _isUsingLastKnown = false;
      notifyListeners();
    }
  }
  
  Future<void> _calculateDeclination() async {
    if (_currentPosition == null) return;
    
    // Check cache
    if (_declination != null && _declinationCalculatedAt != null) {
      final age = DateTime.now().difference(_declinationCalculatedAt!);
      if (age < _declinationCacheDuration) {
        return; // Use cached value
      }
    }
    
    _declination = await calculateDeclinationForLocation(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
    _declinationCalculatedAt = DateTime.now();
    notifyListeners();
  }
  
  /// Calculate magnetic declination for any arbitrary location
  /// This method can be used to compute declination for user-defined coordinates
  Future<double> calculateDeclinationForLocation(double lat, double lon) async {
    try {
      // Simplified magnetic declination approximation
      // This is a basic approximation for demonstration purposes
      // A full WMM implementation would require complex calculations
      
      double approxDeclination = 0.0;
      
      // North America approximation
      if (lat >= 15 && lat <= 70 && lon >= -170 && lon <= -50) {
        // Rough approximation: declination increases westward in North America
        approxDeclination = -20 + (lon + 100) * 0.2;
      }
      // Europe approximation
      else if (lat >= 35 && lat <= 70 && lon >= -10 && lon <= 40) {
        // Europe generally has small eastward declination
        approxDeclination = 2 + (lon - 10) * 0.1;
      }
      // Asia approximation
      else if (lat >= 0 && lat <= 70 && lon >= 40 && lon <= 180) {
        // Asia has varied declination
        approxDeclination = -5 + (lon - 100) * 0.05;
      }
      // South America approximation
      else if (lat >= -60 && lat <= 15 && lon >= -85 && lon <= -30) {
        approxDeclination = -10 + (lon + 60) * 0.15;
      }
      // Australia approximation
      else if (lat >= -45 && lat <= -10 && lon >= 110 && lon <= 155) {
        approxDeclination = 5 + (lon - 130) * 0.1;
      }
      // Default for other regions
      else {
        approxDeclination = 0.0;
      }
      
      // Clamp to reasonable values
      return approxDeclination.clamp(-30.0, 30.0);
    } catch (e) {
      return 0.0;
    }
  }
  
  Future<void> refreshLocation() async {
    if (kIsWeb) {
      await _tryGetLocationOrFake();
    } else {
      await _getLocation();
    }
  }
}
