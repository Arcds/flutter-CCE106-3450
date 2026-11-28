import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../models/venue_model.dart';
import 'firestore_paths.dart';
import 'functions_service.dart';

/// Firestore reads plus callable mutations for bookings. The client never
/// writes booking status, payment, hold or QR fields directly.
class BookingRepository {
  BookingRepository({
    FirebaseFirestore? firestore,
    FunctionsService? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FunctionsService();

  final FirebaseFirestore _db;
  final FunctionsService _functions;

  Stream<List<Booking>> watchPlayerBookings(String playerId) {
    return _db
        .collectionGroup('bookings')
        .where('playerId', isEqualTo: playerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  Stream<List<Booking>> watchFacilityBookings(
    String facilityId, {
    String? date,
  }) {
    Query<Map<String, dynamic>> query = FirestorePaths.bookings(_db, facilityId);
    if (date != null) {
      query = query.where('date', isEqualTo: date);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  Stream<Booking?> watchBooking(String facilityId, String bookingId) {
    return FirestorePaths.booking(_db, facilityId, bookingId)
        .snapshots()
        .map((doc) => doc.exists ? Booking.fromMap(doc.id, doc.data() ?? const {}) : null);
  }

  Future<ReserveSlotResult> reserveSlot({
    required String facilityId,
    required String courtId,
    required String date,
    required int startHour,
    required int durationHours,
    required PaymentMethod paymentMethod,
  }) {
    return _functions.reserveSlot(
      facilityId: facilityId,
      courtId: courtId,
      date: date,
      startHour: startHour,
      durationHours: durationHours,
      paymentMethod: paymentMethod,
    );
  }

  Future<void> completeMockPayment({
    required String facilityId,
    required String bookingId,
  }) =>
      _functions.completeMockPayment(
        facilityId: facilityId,
        bookingId: bookingId,
      );

  Future<void> submitPaymentProof({
    required String facilityId,
    required String bookingId,
    required String reference,
    String? proofPath,
  }) {
    return _functions.submitPaymentProof(
      facilityId: facilityId,
      bookingId: bookingId,
      reference: reference,
      proofPath: proofPath,
    );
  }

  Future<void> approvePayment({
    required String facilityId,
    required String bookingId,
  }) =>
      _functions.approvePayment(
        facilityId: facilityId,
        bookingId: bookingId,
      );

  Future<void> rejectPayment({
    required String facilityId,
    required String bookingId,
  }) =>
      _functions.rejectPayment(
        facilityId: facilityId,
        bookingId: bookingId,
      );

  Future<void> verifyAndCheckIn({
    required String facilityId,
    required String bookingId,
  }) =>
      _functions.verifyAndCheckIn(
        facilityId: facilityId,
        bookingId: bookingId,
      );

  List<Booking> _mapDocs(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final bookings = [
      for (final doc in snapshot.docs) Booking.fromMap(doc.id, doc.data()),
    ];
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
  }
}
