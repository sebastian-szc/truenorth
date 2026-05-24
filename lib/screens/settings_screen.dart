import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/compass_service.dart';
import '../services/location_service.dart';
import '../widgets/calibration_guide.dart';
import '../config/admob_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCalibrationGuide = false;
  String _appVersion = '';
  bool _isTestMode = AdMobConfig.isTestMode;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}';
    });
  }

  void _toggleTrueNorth() {
    final compassService = context.read<CompassService>();
    final locationService = context.read<LocationService>();
    
    final newValue = !compassService.useTrueNorth;
    
    if (newValue && !locationService.hasLocation) {
      // Show info dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Required'),
          content: const Text(
            'True North requires your location to calculate magnetic declination. '
            'Please enable location services and grant permission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                locationService.requestPermission();
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      return;
    }
    
    compassService.setTrueNorth(newValue);
    HapticFeedback.selectionClick();
  }
  
  void _showTrueNorthInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.navigation, color: Color(0xFFFF453A), size: 24),
            SizedBox(width: 8),
            Text('What is True North?'),
          ],
        ),
        content: const Text(
          'True North points to the geographic North Pole—the actual top of the Earth. '
          'Your compass naturally points to Magnetic North, which is slightly different.\n\n'
          'The difference between them changes depending on where you are in the world. '
          'Enable True North for navigation that matches maps and GPS directions.\n\n'
          'You need location access so we can calculate the correct adjustment for your area.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _startCalibration() {
    setState(() {
      _showCalibrationGuide = true;
    });
    
    // Start calibration in service
    final compassService = context.read<CompassService>();
    compassService.markCalibrationShown();
  }

  Future<void> _toggleTestMode(bool value) async {
    await AdMobConfig.setTestMode(value);
    setState(() {
      _isTestMode = value;
    });
    
    if (mounted) {
      // Different messages for web vs mobile
      if (kIsWeb) {
        // On web, changes take effect immediately
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: const Color(0xFFFF453A),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text('Changes Applied'),
              ],
            ),
            content: Text(
              'Test mode has been ${value ? 'enabled' : 'disabled'}.\n\n'
              'The banner ad ${value ? 'is now visible' : 'has been hidden'} on the Compass screen. '
              'Changes take effect immediately on web.',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // On mobile, restart is required
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFFFF453A),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text('Restart Required'),
              ],
            ),
            content: Text(
              'Test mode has been ${value ? 'enabled' : 'disabled'}.\n\n'
              'Please restart the app for this change to take effect. '
              'The app will ${value ? 'show test ads' : 'show production ads'} after restart.',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _launchPrimioUrl() async {
    final url = Uri.parse('https://primio.dev/');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Silently fail if URL cannot be launched
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Header
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 28,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Compass Settings Section
                _buildSectionHeader('COMPASS'),
                const SizedBox(height: 8),
                
                // True North toggle
                Consumer2<CompassService, LocationService>(
                  builder: (context, compassService, locationService, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF453A).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.navigation,
                                size: 20,
                                color: compassService.useTrueNorth && locationService.hasLocation
                                    ? const Color(0xFFFF453A)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'True North',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: compassService.useTrueNorth && locationService.hasLocation
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Color(0xFFFF453A),
                                ),
                                onPressed: _showTrueNorthInfo,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                tooltip: 'What is True North?',
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Switch(
                                value: compassService.useTrueNorth,
                                onChanged: locationService.hasLocation
                                    ? (value) => _toggleTrueNorth()
                                    : null,
                                activeColor: const Color(0xFFFF453A),
                              ),
                              if (!locationService.hasLocation)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Tooltip(
                                    message: 'Location required',
                                    child: Icon(
                                      Icons.warning_outlined,
                                      size: 18,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Recalibrate button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF453A).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _startCalibration,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.refresh,
                              size: 20,
                              color: Color(0xFFFF453A),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Recalibrate Compass',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Debug Section (Web only)
                if (kIsWeb) ...[
                  _buildSectionHeader('DEBUG'),
                  const SizedBox(height: 8),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF453A).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bug_report,
                              size: 20,
                              color: _isTestMode
                                  ? const Color(0xFFFF453A)
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Test Ads',
                              style: TextStyle(
                                fontSize: 16,
                                color: _isTestMode
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isTestMode,
                          onChanged: _toggleTestMode,
                          activeColor: const Color(0xFFFF453A),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Toggle between test and production ads. Changes take effect immediately on web.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
                
                // Credits Section
                _buildSectionHeader('CREDITS'),
                const SizedBox(height: 8),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF453A).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Made with section
                      Row(
                        children: [
                          Text(
                            'Made with',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.favorite,
                            size: 18,
                            color: Color(0xFFFF453A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'in',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _launchPrimioUrl,
                            child: const Text(
                              'Primio.dev',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFFFF453A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      
                      // Copyright
                      Text(
                        '© Copyright 2025 by Blackfinch',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        'All rights reserved',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      
                      // Disclaimer
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.orange.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DISCLAIMER',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.withOpacity(0.9),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        'This software is provided "as is" without warranty of any kind, express or implied. '
                        'The developers and publishers shall not be liable for any damages, losses, or injuries '
                        'arising from the use of this application.\n\n'
                        'This compass app is intended for general navigation assistance only and should not be '
                        'relied upon as the sole source of direction in critical situations. Users are solely '
                        'responsible for ensuring safe navigation practices.\n\n'
                        'By using this application, you acknowledge and agree that the developers and publishers '
                        'are not responsible for any consequences resulting from your use of the compass, including '
                        'but not limited to getting lost, navigation errors, or any other issues arising from compass readings.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                          height: 1.5,
                        ),
                      ),
                      
                      // App version
                      if (_appVersion.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _appVersion,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
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
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
}
