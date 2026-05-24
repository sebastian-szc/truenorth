enum StabilityState {
  unknown,
  stable,
  unstable,
  calibrate,
}

enum LocationPermissionState {
  unknown,
  granted,
  denied,
  deniedForever,
}

enum CalibrationPhase {
  initial,
  calibrating,
  completed,
}

enum AdConsentStatus {
  unknown,
  notRequired,
  obtained,
  required,
}

class CompassReading {
  final double heading;
  final double accuracy;
  final DateTime timestamp;
  
  CompassReading({
    required this.heading,
    required this.accuracy,
    required this.timestamp,
  });
}

class LocationData {
  final double latitude;
  final double longitude;
  final double declination;
  final DateTime timestamp;
  
  LocationData({
    required this.latitude,
    required this.longitude,
    required this.declination,
    required this.timestamp,
  });
}
