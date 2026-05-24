import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/compass_service.dart';
import '../services/location_service.dart';
import '../models/compass_data.dart';
import '../utils/file_saver_stub.dart'
    if (dart.library.html) '../utils/web_file_saver.dart';

/// Expert Mode Screen - Compass Diagnostics
/// 
/// Displays detailed, live sensor diagnostics for power users:
/// - Raw sensor streams (magnetometer, accelerometer, gyroscope)
/// - Fused orientation (heading, pitch, roll, yaw)
/// - Model outputs (declination, true heading via WMM)
/// - Metadata (stability, sampling rate, calibration age, location)
/// 
/// Note: Declination is computed using the World Magnetic Model (WMM).
/// Android has GeomagneticField.getDeclination() natively; we approximate
/// this via simplified calculations in Dart for cross-platform support.
/// True heading = Magnetic heading + Declination.
/// 
/// On web platforms, displays simulated sensor data for UI preview purposes.
class ExpertModeScreen extends StatefulWidget {
  const ExpertModeScreen({super.key});

  @override
  State<ExpertModeScreen> createState() => _ExpertModeScreenState();
}

class _ExpertModeScreenState extends State<ExpertModeScreen> {
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    // Throttle UI updates to ~10 Hz to save battery
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  void _copySnapshot() {
    final compassService = context.read<CompassService>();
    final locationService = context.read<LocationService>();
    
    final snapshot = _generateSnapshot(compassService, locationService);
    
    Clipboard.setData(ClipboardData(text: snapshot));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostic snapshot copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFFFF453A),
      ),
    );
  }
  
  Future<void> _exportCSV() async {
    try {
      final compassService = context.read<CompassService>();
      final locationService = context.read<LocationService>();
      
      final csv = _generateCSV(compassService, locationService);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'compass_diagnostics_$timestamp.csv';
      
      if (kIsWeb) {
        // Web: trigger browser download
        downloadFile(csv, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV downloaded: $filename'),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFFFF453A),
            ),
          );
        }
      } else {
        // Mobile: use share dialog
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(csv);
        
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Compass Diagnostics',
          text: 'Compass diagnostic data export',
        );
        
        if (mounted) {
          if (result.status == ShareResultStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('CSV file shared successfully'),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFFFF453A),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _toggleSmoothing() {
    final compassService = context.read<CompassService>();
    compassService.toggleStreamSmoothing();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stream smoothing ${compassService.streamSmoothing ? "enabled" : "disabled"}',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFFF453A),
      ),
    );
  }
  
  void _showMenu() {
    final compassService = context.read<CompassService>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: Color(0xFFFF453A)),
                title: const Text('Copy snapshot'),
                onTap: () {
                  Navigator.pop(context);
                  _copySnapshot();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Color(0xFFFF453A)),
                title: const Text('Export CSV'),
                onTap: () {
                  Navigator.pop(context);
                  _exportCSV();
                },
              ),
              ListTile(
                leading: Icon(
                  compassService.streamSmoothing ? Icons.graphic_eq : Icons.show_chart,
                  color: const Color(0xFFFF453A),
                ),
                title: Text('Smoothing: ${compassService.streamSmoothing ? "On" : "Off"}'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSmoothing();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
  
  String _generateSnapshot(CompassService compass, LocationService location) {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln('  COMPASS DIAGNOSTICS SNAPSHOT');
    if (kIsWeb) {
      buffer.writeln('  (SIMULATED DATA - WEB PREVIEW)');
    }
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(compass.lastTimestamp)}');
    buffer.writeln();
    
    buffer.writeln('RAW SENSORS');
    buffer.writeln('───────────────────────────────────');
    buffer.writeln('Magnetometer X: ${compass.magX.toStringAsFixed(2)} µT');
    buffer.writeln('Magnetometer Y: ${compass.magY.toStringAsFixed(2)} µT');
    buffer.writeln('Magnetometer Z: ${compass.magZ.toStringAsFixed(2)} µT');
    buffer.writeln();
    buffer.writeln('Accelerometer X: ${compass.accelX.toStringAsFixed(2)} m/s²');
    buffer.writeln('Accelerometer Y: ${compass.accelY.toStringAsFixed(2)} m/s²');
    buffer.writeln('Accelerometer Z: ${compass.accelZ.toStringAsFixed(2)} m/s²');
    buffer.writeln();
    buffer.writeln('Gyroscope X: ${compass.gyroX.toStringAsFixed(2)} rad/s');
    buffer.writeln('Gyroscope Y: ${compass.gyroY.toStringAsFixed(2)} rad/s');
    buffer.writeln('Gyroscope Z: ${compass.gyroZ.toStringAsFixed(2)} rad/s');
    buffer.writeln();
    
    buffer.writeln('ORIENTATION (approximate, device-frame)');
    buffer.writeln('───────────────────────────────────');
    buffer.writeln('Magnetic Heading: ${compass.magneticHeading.toStringAsFixed(1)}°');
    buffer.writeln('Pitch: ${compass.pitch.toStringAsFixed(1)}°');
    buffer.writeln('Roll: ${compass.roll.toStringAsFixed(1)}°');
    buffer.writeln('Yaw Rate: ${compass.yaw.toStringAsFixed(1)}°/s');
    buffer.writeln();
    
    buffer.writeln('MODEL / COMPUTED (WMM-based)');
    buffer.writeln('───────────────────────────────────');
    if (location.hasLocation && location.declination != null) {
      buffer.writeln('Declination: ${location.declination!.toStringAsFixed(1)}°');
      final trueHeading = (compass.magneticHeading + location.declination!) % 360;
      buffer.writeln('True Heading: ${trueHeading.toStringAsFixed(1)}°');
      buffer.writeln('(True = Magnetic + Declination)');
    } else {
      buffer.writeln('Declination: N/A (location unavailable)');
      buffer.writeln('True Heading: N/A (location unavailable)');
    }
    buffer.writeln();
    
    buffer.writeln('METADATA');
    buffer.writeln('───────────────────────────────────');
    buffer.writeln('Sensor Stability: ${_stabilityStateToString(compass.stabilityState)}');
    buffer.writeln('Sampling Rate: ${compass.samplingRate.toStringAsFixed(1)} Hz');
    if (compass.calibrationAge != null) {
      buffer.writeln('Calibration Age: ${compass.calibrationAge!.inMinutes} min');
    } else {
      buffer.writeln('Calibration Age: Never calibrated');
    }
    if (location.hasLocation) {
      buffer.writeln('Location: ${location.latitude!.toStringAsFixed(6)}°, ${location.longitude!.toStringAsFixed(6)}°');
      buffer.writeln('GPS Accuracy: ±${location.accuracy!.toStringAsFixed(0)} m');
    } else {
      buffer.writeln('Location: Unavailable');
    }
    buffer.writeln('Stream Smoothing: ${compass.streamSmoothing ? "On" : "Off"}');
    buffer.writeln('True North: ${compass.useTrueNorth ? "On" : "Off"}');
    buffer.writeln();
    
    buffer.writeln('═══════════════════════════════════');
    
    return buffer.toString();
  }
  
  String _generateCSV(CompassService compass, LocationService location) {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln('Timestamp,MagX_uT,MagY_uT,MagZ_uT,AccelX_ms2,AccelY_ms2,AccelZ_ms2,GyroX_rads,GyroY_rads,GyroZ_rads,MagHeading_deg,Pitch_deg,Roll_deg,YawRate_degs,Declination_deg,TrueHeading_deg,Stability,SamplingRate_Hz,CalibrationAge_min,Lat,Lon,Accuracy_m,Smoothing,TrueNorth');
    
    // CSV Data Row
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(compass.lastTimestamp);
    final declination = location.hasLocation && location.declination != null 
        ? location.declination!.toStringAsFixed(2) 
        : 'N/A';
    final trueHeading = location.hasLocation && location.declination != null
        ? ((compass.magneticHeading + location.declination!) % 360).toStringAsFixed(1)
        : 'N/A';
    final lat = location.hasLocation ? location.latitude!.toStringAsFixed(6) : 'N/A';
    final lon = location.hasLocation ? location.longitude!.toStringAsFixed(6) : 'N/A';
    final acc = location.hasLocation ? location.accuracy!.toStringAsFixed(0) : 'N/A';
    final calAge = compass.calibrationAge != null 
        ? compass.calibrationAge!.inMinutes.toString() 
        : 'N/A';
    
    buffer.write('$timestamp,');
    buffer.write('${compass.magX.toStringAsFixed(2)},');
    buffer.write('${compass.magY.toStringAsFixed(2)},');
    buffer.write('${compass.magZ.toStringAsFixed(2)},');
    buffer.write('${compass.accelX.toStringAsFixed(2)},');
    buffer.write('${compass.accelY.toStringAsFixed(2)},');
    buffer.write('${compass.accelZ.toStringAsFixed(2)},');
    buffer.write('${compass.gyroX.toStringAsFixed(2)},');
    buffer.write('${compass.gyroY.toStringAsFixed(2)},');
    buffer.write('${compass.gyroZ.toStringAsFixed(2)},');
    buffer.write('${compass.magneticHeading.toStringAsFixed(1)},');
    buffer.write('${compass.pitch.toStringAsFixed(1)},');
    buffer.write('${compass.roll.toStringAsFixed(1)},');
    buffer.write('${compass.yaw.toStringAsFixed(1)},');
    buffer.write('$declination,');
    buffer.write('$trueHeading,');
    buffer.write('${_stabilityStateToString(compass.stabilityState)},');
    buffer.write('${compass.samplingRate.toStringAsFixed(1)},');
    buffer.write('$calAge,');
    buffer.write('$lat,');
    buffer.write('$lon,');
    buffer.write('$acc,');
    buffer.write('${compass.streamSmoothing ? "On" : "Off"},');
    buffer.write('${compass.useTrueNorth ? "On" : "Off"}');
    buffer.writeln();
    
    return buffer.toString();
  }
  
  String _stabilityStateToString(StabilityState state) {
    switch (state) {
      case StabilityState.stable:
        return 'Stable';
      case StabilityState.unstable:
        return 'Unstable';
      case StabilityState.calibrate:
        return 'Calibrate';
      case StabilityState.unknown:
        return 'Unknown';
    }
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
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Expert Mode',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 28,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      // Web preview indicator
                      if (kIsWeb) ...[ 
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'SIMULATED DATA (WEB PREVIEW)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Scrollable content
                Expanded(
                  child: Consumer2<CompassService, LocationService>(
                    builder: (context, compassService, locationService, child) {
                      // Check for sensor availability
                      if (!compassService.sensorAvailable) {
                        return _buildErrorState(
                          icon: Icons.sensors_off,
                          title: 'Sensor Unavailable',
                          message: 'Compass sensor is not available on this device',
                        );
                      }
                      
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        children: [
                          const SizedBox(height: 8),
                          
                          // Raw Sensors Section
                          _buildSectionHeader('RAW SENSORS'),
                          _buildDataCard([
                            _buildDataRow('Magnetometer X', '${compassService.magX.toStringAsFixed(2)} µT'),
                            _buildDataRow('Magnetometer Y', '${compassService.magY.toStringAsFixed(2)} µT'),
                            _buildDataRow('Magnetometer Z', '${compassService.magZ.toStringAsFixed(2)} µT'),
                            const Divider(height: 24, color: Colors.white24),
                            _buildDataRow('Accelerometer X', '${compassService.accelX.toStringAsFixed(2)} m/s²'),
                            _buildDataRow('Accelerometer Y', '${compassService.accelY.toStringAsFixed(2)} m/s²'),
                            _buildDataRow('Accelerometer Z', '${compassService.accelZ.toStringAsFixed(2)} m/s²'),
                            const Divider(height: 24, color: Colors.white24),
                            _buildDataRow('Gyroscope X', '${compassService.gyroX.toStringAsFixed(2)} rad/s'),
                            _buildDataRow('Gyroscope Y', '${compassService.gyroY.toStringAsFixed(2)} rad/s'),
                            _buildDataRow('Gyroscope Z', '${compassService.gyroZ.toStringAsFixed(2)} rad/s'),
                          ]),
                          
                          const SizedBox(height: 20),
                          
                          // Orientation Section
                          _buildSectionHeader('ORIENTATION'),
                          _buildInfoChip('approximate, device-frame'),
                          const SizedBox(height: 8),
                          _buildDataCard([
                            _buildDataRow('Magnetic Heading', '${compassService.magneticHeading.toStringAsFixed(1)}°'),
                            _buildDataRow('Pitch', '${compassService.pitch.toStringAsFixed(1)}°'),
                            _buildDataRow('Roll', '${compassService.roll.toStringAsFixed(1)}°'),
                            _buildDataRow('Yaw Rate', '${compassService.yaw.toStringAsFixed(1)}°/s'),
                          ]),
                          
                          const SizedBox(height: 20),
                          
                          // Model / Computed Section
                          _buildSectionHeader('MODEL / COMPUTED'),
                          _buildInfoChip('WMM-based declination'),
                          const SizedBox(height: 8),
                          _buildDataCard([
                            if (locationService.hasLocation && locationService.declination != null) ...[ 
                              _buildDataRow('Declination', '${locationService.declination!.toStringAsFixed(1)}°'),
                              _buildDataRow(
                                'True Heading',
                                '${((compassService.magneticHeading + locationService.declination!) % 360).toStringAsFixed(1)}°',
                              ),
                            ] else ...[
                              _buildDataRow('Declination', 'N/A', subtitle: 'Location unavailable'),
                              _buildDataRow('True Heading', 'N/A', subtitle: 'Location unavailable'),
                            ],
                          ]),
                          _buildLegend('True = Magnetic + Declination'),
                          
                          const SizedBox(height: 20),
                          
                          // Metadata Section
                          _buildSectionHeader('METADATA'),
                          _buildDataCard([
                            _buildDataRow(
                              'Sensor Stability',
                              _stabilityStateToString(compassService.stabilityState),
                              valueColor: _getStabilityColor(compassService.stabilityState),
                            ),
                            _buildDataRow('Sampling Rate', '${compassService.samplingRate.toStringAsFixed(1)} Hz'),
                            _buildDataRow(
                              'Calibration Age',
                              compassService.calibrationAge != null
                                  ? '${compassService.calibrationAge!.inMinutes} min ago'
                                  : 'Never calibrated',
                            ),
                            if (locationService.hasLocation) ...[
                              _buildDataRow('Latitude', '${locationService.latitude!.toStringAsFixed(6)}°'),
                              _buildDataRow('Longitude', '${locationService.longitude!.toStringAsFixed(6)}°'),
                              _buildDataRow('GPS Accuracy', '±${locationService.accuracy!.toStringAsFixed(0)} m'),
                            ] else
                              _buildDataRow('Location', 'Unavailable', subtitle: 'Enable location services'),
                            _buildDataRow(
                              'Last Update',
                              DateFormat('HH:mm:ss').format(compassService.lastTimestamp),
                            ),
                          ]),
                          
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            
            // Floating menu button
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'expert_menu',
                onPressed: _showMenu,
                backgroundColor: const Color(0xFFFF453A),
                foregroundColor: Colors.white,
                child: const Icon(Icons.more_vert),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF453A),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white60,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
  
  Widget _buildLegend(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white60,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
  
  Widget _buildDataCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF453A).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
  
  Widget _buildDataRow(
    String label,
    String value, {
    String? subtitle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStabilityColor(StabilityState state) {
    switch (state) {
      case StabilityState.stable:
        return Colors.green;
      case StabilityState.unstable:
        return Colors.orange;
      case StabilityState.calibrate:
        return Colors.red;
      case StabilityState.unknown:
        return Colors.grey;
    }
  }
}
