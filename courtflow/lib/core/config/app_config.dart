import 'package:flutter/foundation.dart';

/// Phase 2 runs the UI against the in-memory demo store by default.
/// Enable the Firebase backend with:
///
/// ```bash
/// flutter run --dart-define=USE_FIREBASE=true
/// ```
///
/// Emulators are used automatically in debug builds unless
/// `--dart-define=USE_EMULATORS=false` is passed.
class AppConfig {
  const AppConfig._();

  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

  static const bool useEmulators =
      bool.fromEnvironment('USE_EMULATORS', defaultValue: kDebugMode);

  static const String functionsRegion = 'asia-southeast1';

  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8081;
  static const int functionsEmulatorPort = 5001;

  static String get emulatorHost {
    if (kIsWeb) return '127.0.0.1';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return '127.0.0.1';
  }
}
