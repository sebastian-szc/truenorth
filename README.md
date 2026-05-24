# 🧭 True North — Navigate with Precision

[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20Android%20%7C%20Web-555)](#)
[![Built with Primio.dev](https://img.shields.io/badge/Built%20with-Primio.dev-6C47FF)](https://primio.dev)

**True North** is a professional-grade compass app that delivers high-accuracy magnetic and true-north
readings with real-time sensor diagnostics, target-bearing navigation, and interactive mapping.
Whether you're hiking, sailing, orienteering, or surveying, it provides precise directional guidance
you can trust — on iOS, Android, and the web.

---

## ✨ Features

- **Accurate compass & true north** — real-time magnetic heading (0–359°) with smooth 60 FPS rotation,
  plus true-north calculation using the World Magnetic Model (WMM) and automatic declination
  adjustment based on your GPS location.
- **Target bearing & navigation** — tap the dial to set a custom bearing, then track live deviation
  with a visual target arrow and haptic alignment feedback.
- **Sensor calibration & stability** — built-in stability monitoring (Stable / Unstable / Calibrate),
  an interactive figure-8 calibration guide, and a tilt/level indicator for maximum accuracy.
- **Expert diagnostics mode** — live raw magnetometer, accelerometer, and gyroscope data (X/Y/Z),
  fused orientation (heading, pitch, roll, yaw), and one-tap CSV export for technical analysis.
- **Location & interactive mapping** — OpenStreetMap view of your GPS position, draggable pin with
  live coordinates, clipboard copy, and location-based declination.
- **Professional design** — high-contrast dark theme optimized for outdoor visibility, screen
  wake-lock during navigation, and battery-conscious throttled sensor updates.

## 🛠️ Tech stack

- **Flutter** / **Dart** (SDK ≥ 3.7.2) — single codebase for iOS, Android, and Web
- [`flutter_compass`](https://pub.dev/packages/flutter_compass) & [`sensors_plus`](https://pub.dev/packages/sensors_plus) — magnetometer, accelerometer, gyroscope
- [`geolocator`](https://pub.dev/packages/geolocator) — GPS & declination
- [`flutter_map`](https://pub.dev/packages/flutter_map) — interactive OpenStreetMap
- [`provider`](https://pub.dev/packages/provider) — state management
- [`firebase_core`](https://pub.dev/packages/firebase_core) — analytics
- [`google_mobile_ads`](https://pub.dev/packages/google_mobile_ads) — AdMob with UMP consent

## 🚀 Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.7.2).

```bash
# Install dependencies
flutter pub get

# Run on a connected device, emulator, or the web
flutter run
flutter run -d chrome
```

### Build

```bash
flutter build apk     # Android APK
flutter build aab     # Android App Bundle (Play Store)
flutter build ios     # iOS
flutter build web     # Web
```

## 📁 Project structure

```
lib/
├── main.dart            # App entry point, init, theming, navigation
├── config/              # AdMob configuration
├── models/              # Compass, location & ad data models
├── screens/             # Compass, Location, Expert Mode, Settings, Splash
├── services/            # Sensor, location, consent & ad services
└── widgets/             # Compass dial, calibration guide, stats panel
```

## 🤖 Built with Primio.dev

True North was built with **[Primio.dev](https://primio.dev)** — the AI Flutter app builder that turns
high-level ideas into production-ready iOS & Android apps. Primio generates production-grade Dart code
and UI from natural-language prompts, includes **built-in cloud emulators** for instant in-browser
previews, and ships signed builds through an automated pipeline.

- 🌐 Website: **https://primio.dev**
- 📚 Documentation: **https://www.primio.dev/docs**

> 💡 A live landing page for this project (with full attribution) is published via GitHub Pages — see
> the repository's **About** section for the link.

## 📄 License

Released under the [MIT License](LICENSE).
