import 'package:cloud_firestore/cloud_firestore.dart';

/// Central place for Firestore paths and deterministic slot ids.
class FirestorePaths {
  const FirestorePaths._();

  static CollectionReference<Map<String, dynamic>> venues(FirebaseFirestore db) =>
      db.collection('venues');

  static DocumentReference<Map<String, dynamic>> venue(
    FirebaseFirestore db,
    String facilityId,
  ) =>
      venues(db).doc(facilityId);

  static CollectionReference<Map<String, dynamic>> courts(
    FirebaseFirestore db,
    String facilityId,
  ) =>
      venue(db, facilityId).collection('courts');

  static CollectionReference<Map<String, dynamic>> slots(
    FirebaseFirestore db,
    String facilityId,
    String courtId,
  ) =>
      courts(db, facilityId).doc(courtId).collection('slots');

  static String slotId(String date, int startHour) => '${date}_$startHour';

  static CollectionReference<Map<String, dynamic>> bookings(
    FirebaseFirestore db,
    String facilityId,
  ) =>
      venue(db, facilityId).collection('bookings');

  static DocumentReference<Map<String, dynamic>> booking(
    FirebaseFirestore db,
    String facilityId,
    String bookingId,
  ) =>
      bookings(db, facilityId).doc(bookingId);

  static CollectionReference<Map<String, dynamic>> openPlaySessions(
    FirebaseFirestore db,
    String facilityId,
  ) =>
      venue(db, facilityId).collection('openPlaySessions');

  static CollectionReference<Map<String, dynamic>> users(FirebaseFirestore db) =>
      db.collection('users');

  static DocumentReference<Map<String, dynamic>> user(
    FirebaseFirestore db,
    String uid,
  ) =>
      users(db).doc(uid);

  static CollectionReference<Map<String, dynamic>> checkIns(
    FirebaseFirestore db,
    String facilityId,
  ) =>
      venue(db, facilityId).collection('checkIns');

  static String checkInId(String bookingId, String deviceId) =>
      '${bookingId}_$deviceId';
}
