import 'package:courtflow/core/utils/formatters.dart';
import 'package:courtflow/data/demo_store.dart';
import 'package:courtflow/models/booking_model.dart';
import 'package:courtflow/models/slot_model.dart';
import 'package:courtflow/models/venue_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late DemoStore store;

  setUp(() {
    container = ProviderContainer();
    store = container.read(demoStoreProvider.notifier);
    store.signInAsPlayer();
  });

  tearDown(() => container.dispose());

  test('reserve locks every overlapping slot and rejects a second attempt', () {
    final state = container.read(demoStoreProvider);
    final venue = state.venues.first;
    final court = venue.courts.first;
    final date = dateKey(DateTime.now().add(const Duration(days: 2)));

    final booking = store.reserveSlot(
      venue: venue,
      court: court,
      date: date,
      startHour: 10,
      durationHours: 2,
      paymentMethod: PaymentMethod.online,
    );

    expect(booking.status, BookingStatus.pendingPayment);
    expect(booking.slotIds, ['${date}_10', '${date}_11']);
    expect(booking.totalFee, court.hourlyRate * 2);
    expect(booking.holdExpiresAt, isNotNull);

    final slots = container
        .read(demoStoreProvider)
        .slots
        .where((slot) =>
            slot.facilityId == venue.id &&
            slot.courtId == court.id &&
            slot.date == date &&
            (slot.startHour == 10 || slot.startHour == 11))
        .toList();
    expect(slots, hasLength(2));
    expect(slots.every((slot) => slot.status == SlotStatus.held), isTrue);
    expect(slots.every((slot) => slot.bookingId == booking.id), isTrue);

    expect(
      () => store.reserveSlot(
        venue: venue,
        court: court,
        date: date,
        startHour: 11,
        durationHours: 1,
        paymentMethod: PaymentMethod.cash,
      ),
      throwsA(isA<SlotConflictException>()),
    );
  });

  test('online payment verifies, issues a token and reserves slots', () {
    final state = container.read(demoStoreProvider);
    final venue = state.venues.first;
    final date = dateKey(DateTime.now().add(const Duration(days: 3)));
    final booking = store.reserveSlot(
      venue: venue,
      court: venue.courts.first,
      date: date,
      startHour: 9,
      durationHours: 1,
      paymentMethod: PaymentMethod.online,
    );

    store.completeOnlinePayment(booking.id);

    final updated = container
        .read(demoStoreProvider)
        .bookings
        .firstWhere((candidate) => candidate.id == booking.id);
    expect(updated.status, BookingStatus.verified);
    expect(updated.qrToken, isNotNull);
    expect(updated.holdExpiresAt, isNull);

    final slot = container
        .read(demoStoreProvider)
        .slots
        .firstWhere((candidate) =>
            candidate.facilityId == venue.id &&
            candidate.courtId == venue.courts.first.id &&
            candidate.date == date &&
            candidate.startHour == 9);
    expect(slot.status, SlotStatus.reserved);
    expect(slot.holdExpiresAt, isNull);
  });

  test('staff approval unlocks the pass; rejection restarts a hold', () {
    final review = container
        .read(demoStoreProvider)
        .bookings
        .firstWhere((booking) => booking.id == 'bk_review');

    store.approvePayment(review.id);
    var updated = container
        .read(demoStoreProvider)
        .bookings
        .firstWhere((booking) => booking.id == review.id);
    expect(updated.status, BookingStatus.verified);
    expect(updated.qrToken, isNotNull);

    store.rejectPayment(review.id);
    updated = container
        .read(demoStoreProvider)
        .bookings
        .firstWhere((booking) => booking.id == review.id);
    expect(updated.status, BookingStatus.pendingPayment);
    expect(updated.holdExpiresAt, isNotNull);
    expect(
      updated.holdExpiresAt!.difference(DateTime.now()).inMinutes,
      inInclusiveRange(13, 15),
    );
  });

  test('open play rejects joins once capacity is reached', () {
    final full = container
        .read(demoStoreProvider)
        .sessions
        .firstWhere((session) => session.isFull);

    expect(
      () => store.joinOpenPlay(full.id),
      throwsA(isA<SlotConflictException>()),
    );
  });

  test('sign out returns to guest and blocks reservations', () {
    final venue = container.read(demoStoreProvider).venues.first;
    store.signOut();

    expect(container.read(demoStoreProvider).user, isNull);
    expect(
      () => store.reserveSlot(
        venue: venue,
        court: venue.courts.first,
        date: dateKey(DateTime.now().add(const Duration(days: 1))),
        startHour: 12,
        durationHours: 1,
        paymentMethod: PaymentMethod.cash,
      ),
      throwsA(isA<SlotConflictException>()),
    );
  });
}
