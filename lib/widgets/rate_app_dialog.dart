import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Rate app dialog that prompts users to rate the app on Google Play Store.
/// 
/// Features:
/// - Star graphic and interactive 5-star rating display
/// - Animated stars that fade in sequentially with sparkling effect
/// - "Rate App on Google Play" button that opens the Play Store and exits the app
/// - "not this time" button to dismiss with lowercase styling
/// - Matches app's dark theme with red accent
/// - Non-dismissible by tapping outside (requires button interaction)
/// - Returns bool: true if user rated, false if user dismissed
class RateAppDialog extends StatefulWidget {
  const RateAppDialog({super.key});

  @override
  State<RateAppDialog> createState() => _RateAppDialogState();
}

class _RateAppDialogState extends State<RateAppDialog> {
  int _selectedStars = 5;

  /// Opens the Google Play Store page for True North app and exits the app.
  /// 
  /// Flow:
  /// 1. Launches the Play Store URL (market:// on Android, web URL on iOS)
  /// 2. Closes the dialog
  /// 3. Exits the app using SystemNavigator.pop()
  /// 
  /// The app will terminate after the URL is launched, preventing it from
  /// continuing to run in the background.
  Future<void> _openPlayStore() async {
    Uri url;
    
    // On Android, try to use the market:// scheme first to open Play Store app directly
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      url = Uri.parse('market://details?id=com.primio.truenorth');
      
      if (await canLaunchUrl(url)) {
        // Launch URL
        await launchUrl(url, mode: LaunchMode.externalApplication);
        
        // Close dialog
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        
        // Exit the app
        SystemNavigator.pop();
        return;
      }
      
      // Fallback to web URL if market:// doesn't work
      url = Uri.parse('https://play.google.com/store/apps/details?id=com.primio.truenorth');
    } else {
      // For iOS, web, and other platforms, use the web URL
      url = Uri.parse('https://play.google.com/store/apps/details?id=com.primio.truenorth');
    }
    
    // Launch URL
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    
    // Close dialog
    if (mounted) {
      Navigator.of(context).pop(true);
    }
    
    // Exit the app (only on mobile)
    if (!kIsWeb) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star graphic
            const Icon(
              Icons.star,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 24),
            
            // Title with corrected grammar
            const Text(
              'Your opinion matters to us!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Improved description text with better flow and warmth
            const Text(
              'If you enjoy using Compass Pro, would you mind rating it on the Play Store? It won\'t take more than a minute. Thank you for your support!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Interactive star rating with fade-in and sparkle animation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStars = index + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(
                      index < _selectedStars ? Icons.star : Icons.star_border,
                      size: 36,
                      color: Colors.amber,
                    ),
                  ),
                )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 400),
                  delay: Duration(milliseconds: index * 150),
                  curve: Curves.easeOut,
                )
                .scale(
                  begin: const Offset(0.3, 0.3),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 500),
                  delay: Duration(milliseconds: index * 150),
                  curve: Curves.elasticOut,
                )
                .then()
                .shimmer(
                  duration: const Duration(milliseconds: 800),
                  color: Colors.white.withOpacity(0.3),
                  angle: 0,
                );
              }),
            ),
            const SizedBox(height: 32),
            
            // Rate app button with improved title case
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openPlayStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF453A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Rate App on Google Play',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Dismiss button with intentional lowercase styling
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Return false = user dismissed
              },
              child: const Text(
                'not this time',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
