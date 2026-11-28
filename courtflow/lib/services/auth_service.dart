import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_model.dart';

/// Firebase Auth + `users/{uid}` profile bridge.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Emits the signed-in user with their Firestore profile, or null.
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _profileFor(user);
    });
  }

  Future<AppUser> _profileFor(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      return AppUser.fromMap(user.uid, snapshot.data() ?? const {});
    }

    final profile = AppUser(
      uid: user.uid,
      name: user.displayName ??
          user.email?.split('@').first ??
          'CourtFlow Player',
      email: user.email ?? '',
      role: UserRole.player,
    );
    await ref.set({
      ...profile.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return profile;
  }

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set(
      {
        'name': user.email?.split('@').first ?? 'CourtFlow Player',
        'email': user.email ?? email,
        'role': UserRole.player.name,
        'clubRoles': <String, dynamic>{},
        'fcmTokens': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> signInStaffDemo() {
    return signIn(email: 'staff@courtflow.demo', password: 'courtflow123');
  }

  Future<void> signInPlayerDemo() {
    return signIn(email: 'player@courtflow.demo', password: 'courtflow123');
  }

  Future<void> signOut() => _auth.signOut();
}
