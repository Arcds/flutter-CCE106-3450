import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:courtflow/models/app_user_model.dart';
import 'package:courtflow/models/booking_model.dart';
import 'package:courtflow/models/court_model.dart';
import 'package:courtflow/models/open_play_model.dart';
import 'package:courtflow/models/slot_model.dart';
import 'package:courtflow/models/venue_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Booking.fromMap maps Firestore fields and timestamps', () {
    final createdAt = DateTime.utc(2026, 1, 1, 8);
    final holdExpiresAt = DateTime.utc(2026, 1, 1, 8, 15);
    final booking = Booking.fromMap('bk_1', {
      'facilityId': 'club',
      'facilityName': 'Club',
      'courtId': 'c1',
      'courtName': 'Court 1',
      'playerId': 'p1',
      'playerName': 'Alex',
      'date': '2026-01-02',
      'startHour': 9,
      'durationHours': 2,
      'slotIds': ['2026-01-02_9', '2026-01-02_10'],
      'totalFee': 700,
      'paymentMethod': 'ewallet',
      'status': 'payment_review',
      'createdAt': Timestamp.fromDate(createdAt),
      'holdExpiresAt': Timestamp.fromDate(holdExpiresAt),
      'paymentRef': 'GCASH-1234',
    });

    expect(booking.facilityName, 'Club');
    expect(booking.durationHours, 2);
    expect(booking.slotIds, ['2026-01-02_9', '2026-01-02_10']);
    expect(booking.totalFee, 700);
    expect(booking.paymentMethod, PaymentMethod.ewallet);
    expect(booking.status, BookingStatus.paymentReview);
    expect(booking.createdAt.toUtc(), createdAt);
    expect(booking.holdExpiresAt?.toUtc(), holdExpiresAt);
    expect(booking.paymentRef, 'GCASH-1234');
  });

  test('Slot.fromMap parses the deterministic document id', () {
    final hold = DateTime.utc(2026, 1, 2, 9, 15);
    final slot = Slot.fromMap('club', 'c1', '2026-01-02_9', {
      'status': 'held',
      'bookingId': 'bk_1',
      'holdExpiresAt': Timestamp.fromDate(hold),
    });

    expect(slot.date, '2026-01-02');
    expect(slot.startHour, 9);
    expect(slot.status, SlotStatus.held);
    expect(slot.bookingId, 'bk_1');
    expect(slot.holdExpiresAt?.toUtc(), hold);
  });

  test('Venue.fromMap reads hours, methods and courts', () {
    final venue = Venue.fromMap(
      'club',
      {
        'name': 'Davao Pickleball Club',
        'slug': 'davao',
        'location': 'Bajada',
        'operatingHours': {'open': '06:30', 'close': '22:00'},
        'acceptedPaymentMethods': ['online', 'cash'],
        'cashHoldMinutes': 90,
        'publicDirectoryVisible': true,
      },
      courts: [Court.fromMap('c1', {'name': 'Court 1', 'hourlyRate': 350})],
    );

    expect(venue.openHour, 6);
    expect(venue.closeHour, 22);
    expect(venue.acceptedPaymentMethods,
        [PaymentMethod.online, PaymentMethod.cash]);
    expect(venue.cashHoldMinutes, 90);
    expect(venue.publicDirectoryVisible, isTrue);
    expect(venue.courts.single.hourlyRate, 350);
  });

  test('OpenPlaySession.fromMap falls back to the facility id', () {
    final session = OpenPlaySession.fromMap('op_1', {
      'facilityId': 'club',
      'title': 'Sunset',
      'date': '2026-01-02',
      'entryFee': 250,
      'maxCapacity': 16,
      'participantIds': ['p1'],
    });

    expect(session.facilityName, 'club');
    expect(session.entryFee, 250);
    expect(session.maxCapacity, 16);
    expect(session.participantIds, ['p1']);
  });

  test('AppUser.fromMap reads roles and club access', () {
    final user = AppUser.fromMap('staff_1', {
      'name': 'Jamie',
      'email': 'staff@courtflow.demo',
      'role': 'staff',
      'clubRoles': {'club': 'staff'},
      'fcmTokens': ['token'],
    });

    expect(user.role, UserRole.staff);
    expect(user.clubRoles['club'], ClubRole.staff);
    expect(user.manages('club'), isTrue);
    expect(user.fcmTokens, ['token']);
  });
}
