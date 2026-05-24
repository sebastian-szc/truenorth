import 'package:flutter/material.dart';
import 'dart:math' as math;

class CompassDial extends StatelessWidget {
  final double heading;
  final double continuousRotation;
  final double? targetBearing;
  final Function(Offset, Size)? onTap;
  final double? availableWidth;
  final double? availableHeight;
  
  const CompassDial({
    super.key,
    required this.heading,
    required this.continuousRotation,
    this.targetBearing,
    this.onTap,
    this.availableWidth,
    this.availableHeight,
  });
  
  @override
  Widget build(BuildContext context) {
    // Use available space if provided, otherwise fallback to MediaQuery
    final width = availableWidth ?? MediaQuery.of(context).size.width;
    final height = availableHeight ?? MediaQuery.of(context).size.height;
    
    // Calculate dial size with appropriate constraints
    // Use 85% of available space for width or height, whichever is smaller
    // This ensures the dial fits comfortably without touching edges
    final maxWidthDial = width * 0.85;
    final maxHeightDial = height * 0.85;
    
    // Take the smaller dimension to ensure dial fits in available space
    final idealSize = math.min(maxWidthDial, maxHeightDial);
    
    // Ensure minimum readable size (200px) but don't exceed available space
    final dialSize = math.max(200.0, math.min(idealSize, math.min(maxWidthDial, maxHeightDial)));
    
    // Final constraint to ensure it never exceeds available space
    final constrainedDialSize = math.min(dialSize, math.min(width, height) * 0.9);
    
    return GestureDetector(
      onTapDown: (details) {
        if (onTap != null) {
          onTap!(details.localPosition, Size(constrainedDialSize, constrainedDialSize));
        }
      },
      child: SizedBox(
        width: constrainedDialSize,
        height: constrainedDialSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rotating compass dial
            AnimatedRotation(
              turns: -continuousRotation / 360.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: CustomPaint(
                size: Size(constrainedDialSize, constrainedDialSize),
                painter: CompassDialPainter(
                  targetBearing: targetBearing,
                ),
              ),
            ),
            
            // Center heading display
            Container(
              padding: EdgeInsets.all(constrainedDialSize * 0.08), // Responsive padding
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF453A),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF453A).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getDirectionLabel(heading),
                    style: TextStyle(
                      fontSize: (constrainedDialSize * 0.055).clamp(12.0, 16.0), // Responsive font size
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF453A),
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: constrainedDialSize * 0.01),
                  Text(
                    '${heading.toStringAsFixed(0)}°',
                    style: TextStyle(
                      fontSize: (constrainedDialSize * 0.16).clamp(24.0, 48.0), // Responsive font size
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: constrainedDialSize * 0.01),
                  Text(
                    _getDirectionLabel((heading + 180) % 360),
                    style: TextStyle(
                      fontSize: (constrainedDialSize * 0.048).clamp(10.0, 14.0), // Responsive font size
                      color: Colors.white60,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getDirectionLabel(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}

class CompassDialPainter extends CustomPainter {
  final double? targetBearing;
  
  CompassDialPainter({this.targetBearing});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw outer ring
    final outerRingPaint = Paint()
      ..color = const Color(0xFF121212)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, radius - 10, outerRingPaint);
    
    // Draw tick marks and labels
    for (int i = 0; i < 360; i += 5) {
      final angle = (i - 90) * math.pi / 180;
      final isMajor = i % 30 == 0;
      final isCardinal = i % 90 == 0;
      
      // Use proportional positioning for tick marks
      final startRadius = radius * (isMajor ? 0.85 : 0.90);
      final endRadius = radius - 10;
      
      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      
      final end = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );
      
      final tickPaint = Paint()
        ..color = isCardinal 
          ? const Color(0xFFFF453A) 
          : (isMajor ? Colors.white70 : Colors.white30)
        ..strokeWidth = isCardinal ? 3 : (isMajor ? 2 : 1)
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(start, end, tickPaint);
      
      // Draw labels for cardinal and major directions
      if (isMajor) {
        // Use proportional positioning for labels to prevent overlap with inner circle
        final labelRadius = radius * 0.73;
        final labelPos = Offset(
          center.dx + labelRadius * math.cos(angle),
          center.dy + labelRadius * math.sin(angle),
        );
        
        String label;
        if (i == 0) label = 'N';
        else if (i == 90) label = 'E';
        else if (i == 180) label = 'S';
        else if (i == 270) label = 'W';
        else label = '$i°';
        
        // Scale font size based on dial size with adjusted ratios
        final fontSize = isCardinal 
          ? (size.width * 0.060).clamp(12.0, 18.0) 
          : (size.width * 0.042).clamp(10.0, 13.0);
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: isCardinal ? const Color(0xFFFF453A) : Colors.white70,
              fontSize: fontSize,
              fontWeight: isCardinal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
    
    // Draw target arrow if set
    if (targetBearing != null) {
      final targetAngle = (targetBearing! - 90) * math.pi / 180;
      final arrowLength = radius * 0.82;
      
      final arrowEnd = Offset(
        center.dx + arrowLength * math.cos(targetAngle),
        center.dy + arrowLength * math.sin(targetAngle),
      );
      
      final arrowPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(center, arrowEnd, arrowPaint);
      
      // Draw arrowhead
      final arrowHeadPath = Path();
      final headSize = 15.0;
      
      arrowHeadPath.moveTo(arrowEnd.dx, arrowEnd.dy);
      arrowHeadPath.lineTo(
        arrowEnd.dx - headSize * math.cos(targetAngle - math.pi / 6),
        arrowEnd.dy - headSize * math.sin(targetAngle - math.pi / 6),
      );
      arrowHeadPath.moveTo(arrowEnd.dx, arrowEnd.dy);
      arrowHeadPath.lineTo(
        arrowEnd.dx - headSize * math.cos(targetAngle + math.pi / 6),
        arrowEnd.dy - headSize * math.sin(targetAngle + math.pi / 6),
      );
      
      canvas.drawPath(arrowHeadPath, arrowPaint);
    }
    
    // Draw North indicator at top
    final northIndicatorPath = Path();
    northIndicatorPath.moveTo(center.dx, center.dy - radius + 5);
    northIndicatorPath.lineTo(center.dx - 8, center.dy - radius + 20);
    northIndicatorPath.lineTo(center.dx + 8, center.dy - radius + 20);
    northIndicatorPath.close();
    
    final northPaint = Paint()
      ..color = const Color(0xFFFF453A)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(northIndicatorPath, northPaint);
    
    final northBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawPath(northIndicatorPath, northBorderPaint);
  }
  
  @override
  bool shouldRepaint(CompassDialPainter oldDelegate) {
    return targetBearing != oldDelegate.targetBearing;
  }
}
