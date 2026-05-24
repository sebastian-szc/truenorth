import 'dart:math' show sin, cos, pi;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../services/compass_service.dart';
import '../models/compass_data.dart';

class CalibrationGuide extends StatefulWidget {
  final VoidCallback onDismiss;
  
  const CalibrationGuide({
    super.key,
    required this.onDismiss,
  });
  
  @override
  State<CalibrationGuide> createState() => _CalibrationGuideState();
}

class _CalibrationGuideState extends State<CalibrationGuide> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  CalibrationPhase? _previousPhase;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _triggerCalibrationVibration() async {
    if (kIsWeb) return; // Vibration not supported on web
    
    try {
      // Check if vibration is supported
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Vibrate for 2000ms (2 seconds)
        await Vibration.vibrate(duration: 2000);
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<CompassService>(
      builder: (context, compassService, child) {
        final phase = compassService.calibrationPhase;
        
        // Detect transition to completed phase and trigger vibration
        if (phase == CalibrationPhase.completed && _previousPhase != CalibrationPhase.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerCalibrationVibration();
          });
        }
        _previousPhase = phase;
        
        return Material(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: Stack(
              children: [
                // Dismiss button
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    onPressed: () {
                      compassService.resetCalibration();
                      widget.onDismiss();
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                
                // Content based on phase
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildPhaseContent(context, phase, compassService),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPhaseContent(BuildContext context, CalibrationPhase phase, CompassService compassService) {
    switch (phase) {
      case CalibrationPhase.initial:
        return _buildInitialPhase(context, compassService);
      case CalibrationPhase.calibrating:
        return _buildCalibratingPhase(context, compassService);
      case CalibrationPhase.completed:
        return _buildCompletedPhase(context, compassService);
    }
  }
  
  Widget _buildInitialPhase(BuildContext context, CompassService compassService) {
    return Column(
      key: const ValueKey('initial'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        const Text(
          'Calibration Required',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF453A),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 24),
        
        // Figure-8 illustration
        SizedBox(
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: Figure8Painter(progress: 1.0),
            child: const Center(
              child: Icon(
                Icons.phone_android,
                size: 60,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Instructions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF453A).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStep(1, 'Hold your phone upright'),
              const SizedBox(height: 12),
              _buildStep(2, 'Move it in a figure-8 pattern'),
              const SizedBox(height: 12),
              _buildStep(3, 'Rotate through all axes'),
              const SizedBox(height: 12),
              _buildStep(4, 'Continue for 10-15 seconds'),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Start calibration button
        ElevatedButton(
          onPressed: () {
            compassService.startCalibration();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF453A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text(
            'Start Calibration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCalibratingPhase(BuildContext context, CompassService compassService) {
    final progress = compassService.calibrationProgress;
    final remainingSeconds = ((1.0 - progress) * 15).ceil();
    
    return Column(
      key: const ValueKey('calibrating'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        const Text(
          'Calibrating...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF453A),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 24),
        
        // Animated figure-8 with progress
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress circle
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF453A)),
                ),
              ),
              
              // Animated figure-8
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AnimatedFigure8Painter(
                      progress: _animationController.value,
                    ),
                    child: const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: Icon(
                          Icons.phone_android,
                          size: 60,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Progress text
        Text(
          'Keep moving in figure-8 pattern',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        Text(
          '$remainingSeconds seconds remaining',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildCompletedPhase(BuildContext context, CompassService compassService) {
    return Column(
      key: const ValueKey('completed'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFFF453A).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 80,
            color: Color(0xFFFF453A),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Title
        const Text(
          'Calibration Complete!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF453A),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        // Success message
        Text(
          'Your compass has been successfully calibrated.\nYou should now see more stable readings.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.8),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        // Done button
        ElevatedButton(
          onPressed: () {
            compassService.resetCalibration();
            widget.onDismiss();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF453A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text(
            'Done',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStep(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFFF453A),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Figure8Painter extends CustomPainter {
  final double progress;
  
  Figure8Painter({this.progress = 1.0});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF453A).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.25;
    
    // Draw figure-8
    final steps = (2 * pi * 2 * progress / 0.1).toInt();
    for (int i = 0; i <= steps; i++) {
      final t = i * 0.1;
      final x = centerX + radius * sin(t);
      final y = centerY + radius * sin(t) * cos(t);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw arrow indicating direction
    if (progress > 0.1) {
      final arrowPaint = Paint()
        ..color = const Color(0xFFFF453A)
        ..style = PaintingStyle.fill;
      
      final arrowPath = Path();
      final arrowX = centerX + radius * sin(pi / 4);
      final arrowY = centerY + radius * sin(pi / 4) * cos(pi / 4);
      
      arrowPath.moveTo(arrowX, arrowY);
      arrowPath.lineTo(arrowX - 8, arrowY - 8);
      arrowPath.lineTo(arrowX - 4, arrowY - 4);
      arrowPath.lineTo(arrowX - 8, arrowY);
      arrowPath.close();
      
      canvas.drawPath(arrowPath, arrowPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant Figure8Painter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class AnimatedFigure8Painter extends CustomPainter {
  final double progress;
  
  AnimatedFigure8Painter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF453A).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.25;
    
    // Draw figure-8
    for (double t = 0; t <= 2 * pi * 2; t += 0.1) {
      final x = centerX + radius * sin(t);
      final y = centerY + radius * sin(t) * cos(t);
      
      if (t == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw animated dot
    final dotT = progress * 2 * pi * 2;
    final dotX = centerX + radius * sin(dotT);
    final dotY = centerY + radius * sin(dotT) * cos(dotT);
    
    final dotPaint = Paint()
      ..color = const Color(0xFFFF453A)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);
    
    // Draw glow around dot
    final glowPaint = Paint()
      ..color = const Color(0xFFFF453A).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(dotX, dotY), 12, glowPaint);
  }
  
  @override
  bool shouldRepaint(covariant AnimatedFigure8Painter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
