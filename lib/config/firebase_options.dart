import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    
    switch (Platform.operatingSystem) {
      case 'android':
        return android;
      case 'ios':
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCGMTGALclzOpo-0wLaVmq42jQ6wjumvvE',
    appId: '1:965490073927:web:c5642d118bb35359d1ec62',
    messagingSenderId: '965490073927',
    projectId: 'compass-pro-7d0a6',
    storageBucket: 'compass-pro-7d0a6.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGMTGALclzOpo-0wLaVmq42jQ6wjumvvE',
    appId: '1:965490073927:android:c5642d118bb35359d1ec62',
    messagingSenderId: '965490073927',
    projectId: 'compass-pro-7d0a6',
    storageBucket: 'compass-pro-7d0a6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCGMTGALclzOpo-0wLaVmq42jQ6wjumvvE',
    appId: '1:965490073927:ios:c5642d118bb35359d1ec62',
    messagingSenderId: '965490073927',
    projectId: 'compass-pro-7d0a6',
    storageBucket: 'compass-pro-7d0a6.firebasestorage.app',
    iosBundleId: 'com.primio.truenorth',
  );
}
