import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Splash screen displayed during app initialization.
/// 
/// Features:
/// - Black background with 3D rotating wire-frame ball animation
/// - Red wire-frame with depth-shading
/// - Scales to 75% of available screen width
/// - Rotates in all directions (X, Y, Z axes)
/// - Displays "Compass Pro" title and "Loading..." text
/// - Handles UMP consent initialization
/// - Handles AdMob initialization
/// - Handles App Open ad manager initialization
/// - Configurable timeout (from AdMobConfig) to prevent blocking
/// - Smooth transition to main screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Set up continuous rotation animation for 3D wireframe ball
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate 75% of available screen width
                final screenWidth = MediaQuery.of(context).size.width;
                final sphereSize = screenWidth * 0.75;
                
                return AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(sphereSize, sphereSize),
                      painter: WireframeBallPainter(_animationController.value),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Compass Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Color(0xFFFF453A),
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for 3D rotating wireframe ball with depth shading.
class WireframeBallPainter extends CustomPainter {
  final double animationValue;
  
  WireframeBallPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;
    
    // Generate sphere vertices
    final vertices = _generateSphereVertices(radius);
    
    // Apply rotation based on animation value
    final rotatedVertices = vertices.map((vertex) {
      final rotated = _rotateVertex(vertex, animationValue);
      return rotated;
    }).toList();
    
    // Draw latitude lines
    _drawLatitudeLines(canvas, center, radius, rotatedVertices);
    
    // Draw longitude lines
    _drawLongitudeLines(canvas, center, radius, rotatedVertices);
  }
  
  /// Generate vertices for a sphere
  List<vm.Vector3> _generateSphereVertices(double radius) {
    final vertices = <vm.Vector3>[];
    const latitudeSteps = 8;
    const longitudeSteps = 16;
    
    for (int lat = 0; lat <= latitudeSteps; lat++) {
      final theta = (lat * math.pi) / latitudeSteps;
      final sinTheta = math.sin(theta);
      final cosTheta = math.cos(theta);
      
      for (int lon = 0; lon <= longitudeSteps; lon++) {
        final phi = (lon * 2 * math.pi) / longitudeSteps;
        final sinPhi = math.sin(phi);
        final cosPhi = math.cos(phi);
        
        final x = radius * sinTheta * cosPhi;
        final y = radius * cosTheta;
        final z = radius * sinTheta * sinPhi;
        
        vertices.add(vm.Vector3(x, y, z));
      }
    }
    
    return vertices;
  }
  
  /// Rotate a vertex around X, Y, and Z axes for full 3D rotation
  vm.Vector3 _rotateVertex(vm.Vector3 vertex, double t) {
    // Rotation angles for all three axes
    final angleX = t * 2 * math.pi * 0.5;
    final angleY = t * 2 * math.pi;
    final angleZ = t * 2 * math.pi * 0.3;
    
    // Rotation matrices for all three axes
    final rotationX = vm.Matrix3.rotationX(angleX);
    final rotationY = vm.Matrix3.rotationY(angleY);
    final rotationZ = vm.Matrix3.rotationZ(angleZ);
    
    // Apply rotations in sequence
    var rotated = rotationX.transform(vertex);
    rotated = rotationY.transform(rotated);
    rotated = rotationZ.transform(rotated);
    
    return rotated;
  }
  
  /// Project 3D vertex to 2D screen space
  Offset _project3DTo2D(vm.Vector3 vertex, Offset center, double distance) {
    final scale = distance / (distance + vertex.z + 200);
    return Offset(
      center.dx + vertex.x * scale,
      center.dy + vertex.y * scale,
    );
  }
  
  /// Calculate depth-based opacity (closer = brighter)
  double _calculateDepthOpacity(vm.Vector3 vertex, double radius) {
    // Normalize Z coordinate to 0-1 range
    final normalizedZ = (vertex.z + radius) / (2 * radius);
    // Map to opacity range 0.3 to 1.0
    return 0.3 + (normalizedZ * 0.7);
  }
  
  /// Draw latitude lines (horizontal circles)
  void _drawLatitudeLines(Canvas canvas, Offset center, double radius, List<vm.Vector3> vertices) {
    const latitudeSteps = 8;
    const longitudeSteps = 16;
    
    for (int lat = 0; lat <= latitudeSteps; lat++) {
      for (int lon = 0; lon < longitudeSteps; lon++) {
        final index1 = lat * (longitudeSteps + 1) + lon;
        final index2 = lat * (longitudeSteps + 1) + (lon + 1);
        
        if (index1 < vertices.length && index2 < vertices.length) {
          final v1 = vertices[index1];
          final v2 = vertices[index2];
          
          // Calculate depth for color shading
          final opacity = (_calculateDepthOpacity(v1, radius) + _calculateDepthOpacity(v2, radius)) / 2;
          
          // Project to 2D
          final p1 = _project3DTo2D(v1, center, 300);
          final p2 = _project3DTo2D(v2, center, 300);
          
          // Draw line with depth shading
          final paint = Paint()
            ..color = Color(0xFFFF453A).withOpacity(opacity)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
          
          canvas.drawLine(p1, p2, paint);
        }
      }
    }
  }
  
  /// Draw longitude lines (vertical circles)
  void _drawLongitudeLines(Canvas canvas, Offset center, double radius, List<vm.Vector3> vertices) {
    const latitudeSteps = 8;
    const longitudeSteps = 16;
    
    for (int lon = 0; lon <= longitudeSteps; lon++) {
      for (int lat = 0; lat < latitudeSteps; lat++) {
        final index1 = lat * (longitudeSteps + 1) + lon;
        final index2 = (lat + 1) * (longitudeSteps + 1) + lon;
        
        if (index1 < vertices.length && index2 < vertices.length) {
          final v1 = vertices[index1];
          final v2 = vertices[index2];
          
          // Calculate depth for color shading
          final opacity = (_calculateDepthOpacity(v1, radius) + _calculateDepthOpacity(v2, radius)) / 2;
          
          // Project to 2D
          final p1 = _project3DTo2D(v1, center, 300);
          final p2 = _project3DTo2D(v2, center, 300);
          
          // Draw line with depth shading
          final paint = Paint()
            ..color = Color(0xFFFF453A).withOpacity(opacity)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
          
          canvas.drawLine(p1, p2, paint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant WireframeBallPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
