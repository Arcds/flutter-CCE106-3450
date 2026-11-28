import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';

/// Points the Firebase SDKs at the local emulator suite when running in
/// Firebase mode. Safe to call when emulators are disabled (no-op).
Future<void> connectFirebaseEmulators() async {
  if (!AppConfig.useFirebase || !AppConfig.useEmulators) return;

  final host = AppConfig.emulatorHost;
  FirebaseAuth.instance.useAuthEmulator(host, AppConfig.authEmulatorPort);
  FirebaseFirestore.instance.useFirestoreEmulator(
    host,
    AppConfig.firestoreEmulatorPort,
  );
  FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
      .useFunctionsEmulator(host, AppConfig.functionsEmulatorPort);
}
