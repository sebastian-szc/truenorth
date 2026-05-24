import 'package:flutter/material.dart';
import '../models/compass_data.dart';

class StatsPanel extends StatelessWidget {
  final StabilityState stabilityState;
  final double tiltDegrees;
  final double? declination;
  final double? targetDeviation;
  final Duration? calibrationAge;
  final bool hasLocation;

  // Fixed height for all stat cards to ensure consistency
  static const double _cardHeight = 70.0;

  const StatsPanel({
    super.key,
    required this.stabilityState,
    required this.tiltDegrees,
    required this.declination,
    required this.targetDeviation,
    required this.calibrationAge,
    required this.hasLocation,
  });

  void _showDeclinationInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.explore, color: Color(0xFFFF453A), size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text('What is Declination?'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Magnetic declination is the difference between where your compass points (Magnetic North) and True North.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Why does it matter?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Earth\'s magnetic field doesn\'t point exactly at the North Pole. The difference changes based on where you are in the world.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'In your location:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              if (declination != null)
                Text(
                  declination! > 0
                      ? 'Magnetic North is ${declination!.abs().toStringAsFixed(1)}° east of True North'
                      : declination! < 0
                          ? 'Magnetic North is ${declination!.abs().toStringAsFixed(1)}° west of True North'
                          : 'Magnetic North and True North align perfectly',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFFFF453A),
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const Text(
                  'Enable location to see your local declination',
                  style: TextStyle(fontSize: 15, height: 1.5, color: Colors.orange),
                ),
              const SizedBox(height: 12),
              const Text(
                'When you enable True North in Expert Mode, this app automatically adjusts your compass reading by the declination amount to show you the real geographic north.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Row 1: Stability & Tilt
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                context,
                icon: _getStabilityIcon(),
                label: 'Stability',
                value: _getStabilityText(),
                color: _getStabilityColor(),
              ),
              _buildStatCard(
                context,
                icon: Icons.phone_android,
                label: 'Tilt',
                value: '${tiltDegrees.toStringAsFixed(1)}°',
                color: tiltDegrees < 15 ? Colors.green : Colors.orange,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Row 2: Declination (full width)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDeclinationCard(context),
            ],
          ),
          
          // Row 3: Target (if set)
          if (targetDeviation != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  context,
                  icon: Icons.adjust,
                  label: 'Target',
                  value: '${targetDeviation! >= 0 ? '+' : ''}${targetDeviation!.toStringAsFixed(1)}°',
                  color: targetDeviation!.abs() < 5 ? Colors.green : Colors.white70,
                ),
                Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 4))),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDeclinationCard(BuildContext context) {
    return Expanded(
      child: Container(
        height: _cardHeight,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.explore, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                const Text(
                  'Declination',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: () => _showDeclinationInfo(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFFFF453A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              declination != null
                  ? '${declination! >= 0 ? '+' : ''}${declination!.toStringAsFixed(1)}°'
                  : hasLocation
                      ? 'Calculating...'
                      : 'No location',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF453A),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        height: _cardHeight,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getStabilityIcon() {
    switch (stabilityState) {
      case StabilityState.stable:
        return Icons.check_circle;
      case StabilityState.unstable:
        return Icons.warning;
      case StabilityState.calibrate:
        return Icons.loop;
      case StabilityState.unknown:
        return Icons.help_outline;
    }
  }
  
  String _getStabilityText() {
    switch (stabilityState) {
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
  
  Color _getStabilityColor() {
    switch (stabilityState) {
      case StabilityState.stable:
        return Colors.green;
      case StabilityState.unstable:
        return Colors.orange;
      case StabilityState.calibrate:
        return const Color(0xFFFF453A);
      case StabilityState.unknown:
        return Colors.white54;
    }
  }
}
