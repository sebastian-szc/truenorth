import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/compass_data.dart';

class CompassService extends ChangeNotifier {
  // Compass data
  double _magneticHeading = 0.0;
  double _displayHeading = 0.0;
  double _continuousRotation = 0.0; // Tracks continuous rotation without wrapping
  bool _useTrueNorth = false;
  double? _declination;
  
  // Raw sensor data for expert mode
  double _magX = 0.0, _magY = 0.0, _magZ = 0.0;
  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;
  
  // Orientation approximation
  double _pitch = 0.0, _roll = 0.0, _yaw = 0.0;
  
  // Target bearing
  double? _targetBearing;
  
  // Stability tracking
  final List<double> _headingHistory = [];
  static const int _historySize = 20;
  StabilityState _stabilityState = StabilityState.unknown;
  StabilityState _previousStabilityState = StabilityState.unknown;
  int _consecutiveStateCount = 0;
  
  // Post-calibration mode
  bool _postCalibrationMode = false;
  
  // Tilt tracking
  double _tiltDegrees = 0.0;
  
  // Calibration
  DateTime? _lastCalibrationTime;
  bool _calibrationShownThisSession = false;
  int _consecutiveCalibrateStates = 0;
  CalibrationPhase _calibrationPhase = CalibrationPhase.initial;
  Timer? _calibrationTimer;
  double _calibrationProgress = 0.0;
  
  // Streams
  StreamSubscription? _compassSubscription;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;
  StreamSubscription? _magnetometerSubscription;
  Timer? _throttleTimer;
  Timer? _fakeDataTimer;
  
  // Sensor state
  bool _sensorAvailable = false;
  
  // Sampling rate tracking
  DateTime? _lastUpdateTime;
  double _samplingRate = 0.0;
  final List<double> _sampleIntervals = [];
  
  // Stream smoothing toggle
  bool _streamSmoothing = true;
  
  // Last update timestamp
  DateTime _lastTimestamp = DateTime.now();
  
  // Getters
  double get magneticHeading => _magneticHeading;
  double get displayHeading => _displayHeading;
  double get continuousRotation => _continuousRotation;
  bool get useTrueNorth => _useTrueNorth;
  double? get targetBearing => _targetBearing;
  StabilityState get stabilityState => _stabilityState;
  double get tiltDegrees => _tiltDegrees;
  bool get sensorAvailable => _sensorAvailable;
  CalibrationPhase get calibrationPhase => _calibrationPhase;
  double get calibrationProgress => _calibrationProgress;
  
  // Expert mode getters
  double get magX => _magX;
  double get magY => _magY;
  double get magZ => _magZ;
  double get accelX => _accelX;
  double get accelY => _accelY;
  double get accelZ => _accelZ;
  double get gyroX => _gyroX;
  double get gyroY => _gyroY;
  double get gyroZ => _gyroZ;
  double get pitch => _pitch;
  double get roll => _roll;
  double get yaw => _yaw;
  double get samplingRate => _samplingRate;
  bool get streamSmoothing => _streamSmoothing;
  DateTime get lastTimestamp => _lastTimestamp;
  
  bool get shouldShowCalibration => 
      _stabilityState == StabilityState.calibrate && 
      !_calibrationShownThisSession &&
      _consecutiveCalibrateStates >= 3; // Require 3 consecutive bad states
  
  double? get targetDeviation {
    if (_targetBearing == null) return null;
    
    double diff = _displayHeading - _targetBearing!;
    
    // Normalize to -180 to 180
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    
    return diff;
  }
  
  Duration? get calibrationAge {
    if (_lastCalibrationTime == null) return null;
    return DateTime.now().difference(_lastCalibrationTime!);
  }
  
  Future<void> initialize() async {
    if (kIsWeb) {
      // Web: Generate fake data for UI preview
      _sensorAvailable = true;
      _stabilityState = StabilityState.stable;
      _startFakeDataGeneration();
      notifyListeners();
      return;
    }
    
    try {
      // Check if compass is available
      final compassEvents = FlutterCompass.events;
      if (compassEvents == null) {
        _sensorAvailable = false;
        _stabilityState = StabilityState.unknown;
        notifyListeners();
        return;
      }
      
      _sensorAvailable = true;
      
      // Start compass stream with throttling
      _compassSubscription = compassEvents.listen((event) {
        _throttleTimer?.cancel();
        _throttleTimer = Timer(const Duration(milliseconds: 50), () {
          _updateHeading(event.heading ?? 0);
        });
      });
      
      // Start accelerometer for tilt detection
      _accelerometerSubscription = accelerometerEventStream().listen((event) {
        _updateAccelerometer(event);
      });
      
      // Start gyroscope for expert mode
      _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
        _updateGyroscope(event);
      });
      
      // Start magnetometer for expert mode (raw data)
      _magnetometerSubscription = magnetometerEventStream().listen((event) {
        _updateMagnetometer(event);
      });
      
      notifyListeners();
    } catch (e) {
      _sensorAvailable = false;
      _stabilityState = StabilityState.unknown;
      notifyListeners();
    }
  }
  
  void _startFakeDataGeneration() {
    // Initialize fake data with realistic starting values
    _magneticHeading = 45.0;
    _displayHeading = 45.0;
    _continuousRotation = 45.0;
    
    // Magnetometer: realistic values in µT
    _magX = 20.0;
    _magY = -15.0;
    _magZ = 40.0;
    
    // Accelerometer: simulate device lying flat with gravity
    _accelX = 0.0;
    _accelY = 0.0;
    _accelZ = 9.8;
    
    // Gyroscope: minimal rotation
    _gyroX = 0.0;
    _gyroY = 0.0;
    _gyroZ = 0.0;
    
    // Orientation
    _pitch = 0.0;
    _roll = 0.0;
    _yaw = 0.0;
    
    _tiltDegrees = 0.0;
    _lastCalibrationTime = DateTime.now();
    _samplingRate = 10.0; // 10 Hz for fake data
    _lastTimestamp = DateTime.now();
    
    // Update fake data every 100ms (10 Hz)
    _fakeDataTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateFakeData();
    });
  }
  
  void _updateFakeData() {
    final now = DateTime.now();
    
    // Update timestamp and sampling rate
    if (_lastUpdateTime != null) {
      final interval = now.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
      _sampleIntervals.add(interval);
      if (_sampleIntervals.length > 10) {
        _sampleIntervals.removeAt(0);
      }
      if (_sampleIntervals.isNotEmpty) {
        final avgInterval = _sampleIntervals.reduce((a, b) => a + b) / _sampleIntervals.length;
        _samplingRate = avgInterval > 0 ? 1.0 / avgInterval : 0.0;
      }
    }
    _lastUpdateTime = now;
    _lastTimestamp = now;
    
    // Simulate slow heading rotation (~1 degree per second)
    _magneticHeading = (_magneticHeading + 0.1) % 360;
    _continuousRotation += 0.1;
    
    // Calculate display heading
    if (_useTrueNorth && _declination != null) {
      _displayHeading = (_magneticHeading + _declination!) % 360;
      if (_displayHeading < 0) _displayHeading += 360;
    } else {
      _displayHeading = _magneticHeading;
    }
    
    // Simulate oscillating magnetometer values (in µT range)
    final time = now.millisecondsSinceEpoch / 1000.0;
    _magX = 20.0 + math.sin(time * 0.5) * 10.0;
    _magY = -15.0 + math.cos(time * 0.7) * 8.0;
    _magZ = 40.0 + math.sin(time * 0.3) * 5.0;
    
    // Simulate slight accelerometer variations (gravity + small noise)
    _accelX = math.sin(time * 0.2) * 0.2;
    _accelY = math.cos(time * 0.3) * 0.2;
    _accelZ = 9.8 + math.sin(time * 0.4) * 0.1;
    
    // Simulate minimal gyroscope rotation
    _gyroX = math.sin(time * 0.6) * 0.1;
    _gyroY = math.cos(time * 0.5) * 0.1;
    _gyroZ = math.sin(time * 0.8) * 0.05;
    
    // Calculate tilt and orientation
    final magnitude = math.sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    if (magnitude > 0) {
      _tiltDegrees = math.acos(_accelZ.abs() / magnitude) * 180 / math.pi;
      _pitch = math.atan2(_accelX, math.sqrt(_accelY * _accelY + _accelZ * _accelZ)) * 180 / math.pi;
      _roll = math.atan2(_accelY, math.sqrt(_accelX * _accelX + _accelZ * _accelZ)) * 180 / math.pi;
    }
    _yaw = _gyroZ * 180 / math.pi;
    
    // Update heading history
    _headingHistory.add(_magneticHeading);
    if (_headingHistory.length > _historySize) {
      _headingHistory.removeAt(0);
    }
    
    // Keep stability as stable for fake data
    _stabilityState = StabilityState.stable;
    
    notifyListeners();
  }
  
  void _updateHeading(double rawHeading) {
    // Update timestamp and sampling rate
    final now = DateTime.now();
    if (_lastUpdateTime != null) {
      final interval = now.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
      _sampleIntervals.add(interval);
      if (_sampleIntervals.length > 10) {
        _sampleIntervals.removeAt(0);
      }
      if (_sampleIntervals.isNotEmpty) {
        final avgInterval = _sampleIntervals.reduce((a, b) => a + b) / _sampleIntervals.length;
        _samplingRate = avgInterval > 0 ? 1.0 / avgInterval : 0.0;
      }
    }
    _lastUpdateTime = now;
    _lastTimestamp = now;
    
    // Normalize to 0-360
    double normalized = rawHeading % 360;
    if (normalized < 0) normalized += 360;
    
    // Calculate shortest delta for continuous rotation
    double delta = 0;
    if (_magneticHeading == 0 && _continuousRotation == 0) {
      // First reading
      _magneticHeading = normalized;
      _continuousRotation = normalized;
      delta = 0;
    } else {
      // Calculate shortest angular difference
      delta = normalized - _magneticHeading;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      
      // Apply exponential moving average to the delta if smoothing enabled
      if (_streamSmoothing) {
        delta = delta * 0.3;
      }
      
      // Update magnetic heading with wrap-around
      _magneticHeading = (_magneticHeading + delta) % 360;
      if (_magneticHeading < 0) _magneticHeading += 360;
      
      // Update continuous rotation without wrapping
      _continuousRotation += delta;
    }
    
    // Calculate display heading (magnetic or true north)
    if (_useTrueNorth && _declination != null) {
      _displayHeading = (_magneticHeading + _declination!) % 360;
      if (_displayHeading < 0) _displayHeading += 360;
    } else {
      _displayHeading = _magneticHeading;
    }
    
    // Update heading history
    _headingHistory.add(_magneticHeading);
    if (_headingHistory.length > _historySize) {
      _headingHistory.removeAt(0);
    }
    
    // Update stability state
    _updateStability();
    
    // Check target alignment
    _checkTargetAlignment();
    
    notifyListeners();
  }
  
  void _updateAccelerometer(AccelerometerEvent event) {
    _accelX = event.x;
    _accelY = event.y;
    _accelZ = event.z;
    
    // Calculate tilt from vertical
    final x = event.x;
    final y = event.y;
    final z = event.z;
    
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude > 0) {
      // Angle from vertical (z-axis)
      _tiltDegrees = math.acos(z.abs() / magnitude) * 180 / math.pi;
      
      // Calculate approximate pitch and roll
      _pitch = math.atan2(x, math.sqrt(y * y + z * z)) * 180 / math.pi;
      _roll = math.atan2(y, math.sqrt(x * x + z * z)) * 180 / math.pi;
    }
  }
  
  void _updateGyroscope(GyroscopeEvent event) {
    _gyroX = event.x;
    _gyroY = event.y;
    _gyroZ = event.z;
    
    // Yaw is approximately the z-axis rotation (in rad/s)
    // This is very approximate without sensor fusion
    _yaw = event.z * 180 / math.pi;
  }
  
  void _updateMagnetometer(MagnetometerEvent event) {
    _magX = event.x;
    _magY = event.y;
    _magZ = event.z;
  }
  
  void _updateStability() {
    if (_headingHistory.length < _historySize) {
      _stabilityState = StabilityState.unknown;
      _consecutiveCalibrateStates = 0;
      return;
    }
    
    // Calculate variance
    final mean = _headingHistory.reduce((a, b) => a + b) / _headingHistory.length;
    
    double variance = 0;
    for (final heading in _headingHistory) {
      double diff = heading - mean;
      // Handle wrap-around
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      variance += diff * diff;
    }
    variance /= _headingHistory.length;
    
    // Adjust variance based on smoothing
    if (!_streamSmoothing) {
      // Without smoothing, expect higher variance, so adjust thresholds
      variance *= 0.5;
    }
    
    // Determine new stability state based on variance
    StabilityState newState;
    
    if (_postCalibrationMode) {
      // Post-calibration: use stricter thresholds, only detect severe issues
      if (variance < 20) {
        newState = StabilityState.stable;
      } else if (variance < 100) {
        newState = StabilityState.unstable;
      } else {
        newState = StabilityState.calibrate;
      }
    } else {
      // Pre-calibration: normal thresholds
      if (variance < 10) {
        newState = StabilityState.stable;
      } else if (variance < 50) {
        newState = StabilityState.unstable;
      } else {
        newState = StabilityState.calibrate;
      }
    }
    
    // Apply hysteresis: require consecutive readings before changing state
    if (newState == _previousStabilityState) {
      _consecutiveStateCount++;
    } else {
      _consecutiveStateCount = 1;
      _previousStabilityState = newState;
    }
    
    // Determine threshold for state change
    int requiredConsecutive = _postCalibrationMode ? 5 : 3;
    
    // Special case: if currently stable and post-calibration, require more evidence to degrade
    if (_stabilityState == StabilityState.stable && _postCalibrationMode) {
      requiredConsecutive = 10;
    }
    
    // Only change state if we have enough consecutive readings
    if (_consecutiveStateCount >= requiredConsecutive) {
      final previousState = _stabilityState;
      _stabilityState = newState;
      
      // Track consecutive calibrate states for showing calibration guide
      if (_stabilityState == StabilityState.calibrate) {
        if (previousState == StabilityState.calibrate) {
          _consecutiveCalibrateStates++;
        } else {
          _consecutiveCalibrateStates = 1;
        }
      } else {
        _consecutiveCalibrateStates = 0;
      }
      
      // Set calibration time when becoming stable
      if (_stabilityState == StabilityState.stable && previousState != StabilityState.stable) {
        _lastCalibrationTime ??= DateTime.now();
      }
    }
  }
  
  void _checkTargetAlignment() {
    if (_targetBearing == null) return;
    
    final deviation = targetDeviation;
    if (deviation != null && deviation.abs() < 2) {
      // Aligned with target - haptic feedback
      HapticFeedback.lightImpact();
    }
  }
  
  void setTrueNorth(bool value) {
    _useTrueNorth = value;
    
    // Recalculate display heading
    if (_useTrueNorth && _declination != null) {
      _displayHeading = (_magneticHeading + _declination!) % 360;
      if (_displayHeading < 0) _displayHeading += 360;
    } else {
      _displayHeading = _magneticHeading;
    }
    
    notifyListeners();
  }
  
  void setDeclination(double declination) {
    _declination = declination;
    
    // Recalculate display heading if using true north
    if (_useTrueNorth) {
      _displayHeading = (_magneticHeading + _declination!) % 360;
      if (_displayHeading < 0) _displayHeading += 360;
      notifyListeners();
    }
  }
  
  void setTargetBearing(double bearing) {
    _targetBearing = bearing;
    notifyListeners();
  }
  
  void clearTargetBearing() {
    _targetBearing = null;
    notifyListeners();
  }
  
  void markCalibrationShown() {
    _calibrationShownThisSession = true;
    notifyListeners();
  }
  
  void startCalibration() {
    _calibrationPhase = CalibrationPhase.calibrating;
    _calibrationProgress = 0.0;
    notifyListeners();
    
    // Run calibration for 15 seconds with progress updates
    const totalDuration = Duration(seconds: 15);
    const updateInterval = Duration(milliseconds: 100);
    final totalSteps = totalDuration.inMilliseconds / updateInterval.inMilliseconds;
    var currentStep = 0;
    
    _calibrationTimer?.cancel();
    _calibrationTimer = Timer.periodic(updateInterval, (timer) {
      currentStep++;
      _calibrationProgress = currentStep / totalSteps;
      
      if (_calibrationProgress >= 1.0) {
        timer.cancel();
        completeCalibration();
      } else {
        notifyListeners();
      }
    });
  }
  
  void completeCalibration() {
    _calibrationTimer?.cancel();
    _calibrationPhase = CalibrationPhase.completed;
    _calibrationProgress = 1.0;
    _lastCalibrationTime = DateTime.now();
    _stabilityState = StabilityState.stable;
    _previousStabilityState = StabilityState.stable;
    _consecutiveCalibrateStates = 0;
    _consecutiveStateCount = 0;
    
    // Enter post-calibration mode
    _postCalibrationMode = true;
    
    notifyListeners();
  }
  
  void resetCalibration() {
    _calibrationTimer?.cancel();
    _calibrationPhase = CalibrationPhase.initial;
    _calibrationProgress = 0.0;
    notifyListeners();
  }
  
  void toggleStreamSmoothing() {
    _streamSmoothing = !_streamSmoothing;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _compassSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _throttleTimer?.cancel();
    _calibrationTimer?.cancel();
    _fakeDataTimer?.cancel();
    super.dispose();
  }
}
