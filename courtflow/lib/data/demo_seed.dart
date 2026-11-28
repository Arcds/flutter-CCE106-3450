import '../core/utils/demo_qr_token.dart';
import '../core/utils/formatters.dart';
import '../models/app_user_model.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';
import '../models/open_play_model.dart';
import '../models/slot_model.dart';
import '../models/venue_model.dart';

const demoPlayerUser = AppUser(
  uid: 'player-demo',
  name: 'Alex Cruz',
  email: 'alex@courtflow.demo',
  role: UserRole.player,
);

const demoStaffUser = AppUser(
  uid: 'staff-demo',
  name: 'Jamie Rivera',
  email: 'jamie@davaopickleball.demo',
  role: UserRole.staff,
  clubRoles: {'davao-pickleball-club': ClubRole.staff},
);

class DemoSeed {
  const DemoSeed({
    required this.venues,
    required this.slots,
    required this.bookings,
    required this.sessions,
  });

  final List<Venue> venues;
  final List<Slot> slots;
  final List<Booking> bookings;
  final List<OpenPlaySession> sessions;
}

/// Builds an in-memory dataset so Phase 1 UI can be exercised end-to-end
/// without Firestore. Replace with repositories in Phase 2.
DemoSeed buildDemoSeed(DateTime now) {
  final venues = <Venue>[
    const Venue(
      id: 'davao-pickleball-club',
      name: 'Davao Pickleball Club',
      slug: 'davao-pickleball-club',
      location: 'Bajada, Davao City',
      courts: [
        Court(id: 'c1', name: 'Court 1', hourlyRate: 350),
        Court(id: 'c2', name: 'Court 2', hourlyRate: 350),
        Court(id: 'c3', name: 'Center Court', hourlyRate: 450),
      ],
      openHour: 6,
      closeHour: 22,
      rules: 'Rubber-soled shoes only. 5-minute warm-up limit per court. '
          'No food on the playing surface.',
      announcements: 'Night league finals this Saturday — courts 1 and 2 close at 6 PM.',
      paymentInstructions: 'GCash: 0917 555 0100 (Davao Pickleball Club). '
          'Upload the reference number after sending.',
      cashHoldMinutes: 120,
      subscriptionTier: 'Pro',
    ),
    const Venue(
      id: 'matina-smash-courts',
      name: 'Matina Smash Courts',
      slug: 'matina-smash-courts',
      location: 'Matina, Davao City',
      courts: [
        Court(id: 'm1', name: 'Court A', hourlyRate: 300),
        Court(id: 'm2', name: 'Court B', hourlyRate: 300),
      ],
      openHour: 7,
      closeHour: 21,
      rules: 'Bring your own balls. Lights off at 9 PM sharp.',
      announcements: 'New LED lighting installed this week.',
      paymentInstructions: 'Maya: 0918 222 3344 (Matina Smash).',
      cashHoldMinutes: 60,
      subscriptionTier: 'Starter',
    ),
    const Venue(
      id: 'toril-indoor-courts',
      name: 'Toril Indoor Courts',
      slug: 'toril-indoor-courts',
      location: 'Toril, Davao City',
      courts: [Court(id: 't1', name: 'Indoor 1', hourlyRate: 400)],
      openHour: 8,
      closeHour: 20,
      publicDirectoryVisible: false,
      subscriptionTier: 'Starter',
    ),
  ];

  final slots = <Slot>[];
  for (final venue in venues) {
    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = dateKey(now.add(Duration(days: dayOffset)));
      for (final court in venue.courts) {
        for (var hour = venue.openHour; hour < venue.closeHour; hour++) {
          slots.add(Slot(
            facilityId: venue.id,
            courtId: court.id,
            date: date,
            startHour: hour,
          ));
        }
      }
    }
  }

  final today = dateKey(now);
  final tomorrow = dateKey(now.add(const Duration(days: 1)));
  final demoStartHour = now.hour.clamp(6, 20);
  final demoStart = slotStart(today, demoStartHour);

  final bookings = <Booking>[
    // Verified pre-paid pass for the demo player, valid right now for scanning.
    Booking(
      id: 'bk_demo_pass',
      facilityId: 'davao-pickleball-club',
      facilityName: 'Davao Pickleball Club',
      courtId: 'c1',
      courtName: 'Court 1',
      playerId: demoPlayerUser.uid,
      playerName: demoPlayerUser.name,
      date: today,
      startHour: demoStartHour,
      durationHours: 1,
      slotIds: ['${today}_$demoStartHour'],
      totalFee: 350,
      paymentMethod: PaymentMethod.online,
      status: BookingStatus.verified,
      createdAt: now.subtract(const Duration(days: 1)),
      verifiedBy: 'gateway (demo)',
      paidAt: now.subtract(const Duration(hours: 20)),
      qrToken: issueDemoQrToken(
        bookingId: 'bk_demo_pass',
        facilityId: 'davao-pickleball-club',
        startsAt: demoStart,
        duration: const Duration(hours: 1),
      ),
    ),
    // Awaiting staff review (e-wallet proof).
    Booking(
      id: 'bk_review',
      facilityId: 'davao-pickleball-club',
      facilityName: 'Davao Pickleball Club',
      courtId: 'c2',
      courtName: 'Court 2',
      playerId: 'player-mika',
      playerName: 'Mika Santos',
      date: tomorrow,
      startHour: 19,
      durationHours: 1,
      slotIds: ['${tomorrow}_19'],
      totalFee: 350,
      paymentMethod: PaymentMethod.ewallet,
      status: BookingStatus.paymentReview,
      createdAt: now.subtract(const Duration(hours: 2)),
      paymentRef: 'GCASH-884210',
      proofPath: 'proofs/davao-pickleball-club/bk_review.png',
    ),
    // Pay-at-desk hold.
    Booking(
      id: 'bk_cash',
      facilityId: 'davao-pickleball-club',
      facilityName: 'Davao Pickleball Club',
      courtId: 'c3',
      courtName: 'Center Court',
      playerId: 'player-paolo',
      playerName: 'Paolo Reyes',
      date: tomorrow,
      startHour: 17,
      durationHours: 2,
      slotIds: ['${tomorrow}_17', '${tomorrow}_18'],
      totalFee: 900,
      paymentMethod: PaymentMethod.cash,
      status: BookingStatus.pendingPayment,
      createdAt: now.subtract(const Duration(minutes: 10)),
      holdExpiresAt: now.add(const Duration(minutes: 90)),
    ),
    // Completed earlier today, for utilization numbers.
    Booking(
      id: 'bk_checked',
      facilityId: 'davao-pickleball-club',
      facilityName: 'Davao Pickleball Club',
      courtId: 'c2',
      courtName: 'Court 2',
      playerId: 'player-lena',
      playerName: 'Lena Dizon',
      date: today,
      startHour: 8,
      durationHours: 1,
      slotIds: ['${today}_8'],
      totalFee: 350,
      paymentMethod: PaymentMethod.online,
      status: BookingStatus.checkedIn,
      createdAt: now.subtract(const Duration(days: 1)),
      verifiedBy: 'staff-demo',
      checkedInAt: now.subtract(const Duration(hours: 4)),
      paidAt: now.subtract(const Duration(days: 1)),
    ),
    // Demo player's unpaid e-wallet hold.
    Booking(
      id: 'bk_player_ewallet',
      facilityId: 'matina-smash-courts',
      facilityName: 'Matina Smash Courts',
      courtId: 'm1',
      courtName: 'Court A',
      playerId: demoPlayerUser.uid,
      playerName: demoPlayerUser.name,
      date: tomorrow,
      startHour: 18,
      durationHours: 1,
      slotIds: ['${tomorrow}_18'],
      totalFee: 300,
      paymentMethod: PaymentMethod.ewallet,
      status: BookingStatus.pendingPayment,
      createdAt: now.subtract(const Duration(minutes: 4)),
      holdExpiresAt: now.add(const Duration(minutes: 11)),
    ),
  ];

  _lockSlots(
    slots,
    bookingId: 'bk_demo_pass',
    facilityId: 'davao-pickleball-club',
    courtId: 'c1',
    date: today,
    startHour: demoStartHour,
    durationHours: 1,
    status: SlotStatus.reserved,
  );
  _lockSlots(
    slots,
    bookingId: 'bk_review',
    facilityId: 'davao-pickleball-club',
    courtId: 'c2',
    date: tomorrow,
    startHour: 19,
    durationHours: 1,
    status: SlotStatus.held,
  );
  _lockSlots(
    slots,
    bookingId: 'bk_cash',
    facilityId: 'davao-pickleball-club',
    courtId: 'c3',
    date: tomorrow,
    startHour: 17,
    durationHours: 2,
    status: SlotStatus.held,
    holdExpiresAt: now.add(const Duration(minutes: 90)),
  );
  _lockSlots(
    slots,
    bookingId: 'bk_checked',
    facilityId: 'davao-pickleball-club',
    courtId: 'c2',
    date: today,
    startHour: 8,
    durationHours: 1,
    status: SlotStatus.reserved,
  );
  _lockSlots(
    slots,
    bookingId: 'bk_player_ewallet',
    facilityId: 'matina-smash-courts',
    courtId: 'm1',
    date: tomorrow,
    startHour: 18,
    durationHours: 1,
    status: SlotStatus.held,
    holdExpiresAt: now.add(const Duration(minutes: 11)),
  );

  final sessions = <OpenPlaySession>[
    OpenPlaySession(
      id: 'op_sunset',
      facilityId: 'davao-pickleball-club',
      facilityName: 'Davao Pickleball Club',
      title: 'Sunset Open Play',
      skillTier: 'Intermediate',
      date: today,
      timeWindow: '6:00 PM – 9:00 PM',
      entryFee: 250,
      maxCapacity: 16,
      participantIds: [
        demoPlayerUser.uid,
        for (var i = 1; i <= 12; i++) 'guest_$i',
      ],
    ),
    OpenPlaySession(
      id: 'op_beginner',
      facilityId: 'davao-pickleball-club',
      facilityName: 'Davao Pickleball Club',
      title: 'Beginner Foundations',
      skillTier: 'Beginner',
      date: tomorrow,
      timeWindow: '8:00 AM – 10:00 AM',
      entryFee: 200,
      maxCapacity: 12,
      participantIds: [for (var i = 1; i <= 12; i++) 'beginner_$i'],
    ),
    OpenPlaySession(
      id: 'op_weekend',
      facilityId: 'matina-smash-courts',
      facilityName: 'Matina Smash Courts',
      title: 'Weekend Rally',
      skillTier: 'All Levels',
      date: dateKey(now.add(const Duration(days: 2))),
      timeWindow: '3:00 PM – 6:00 PM',
      entryFee: 300,
      maxCapacity: 20,
      participantIds: [for (var i = 1; i <= 8; i++) 'rally_$i'],
    ),
  ];

  return DemoSeed(
    venues: venues,
    slots: slots,
    bookings: bookings,
    sessions: sessions,
  );
}

void _lockSlots(
  List<Slot> slots, {
  required String bookingId,
  required String facilityId,
  required String courtId,
  required String date,
  required int startHour,
  required int durationHours,
  required SlotStatus status,
  DateTime? holdExpiresAt,
}) {
  for (var i = 0; i < durationHours; i++) {
    final index = slots.indexWhere((s) =>
        s.facilityId == facilityId &&
        s.courtId == courtId &&
        s.date == date &&
        s.startHour == startHour + i);
    if (index == -1) continue;
    slots[index] = slots[index].copyWith(
      status: status,
      bookingId: bookingId,
      holdExpiresAt: holdExpiresAt,
      clearHold: holdExpiresAt == null,
    );
  }
}
