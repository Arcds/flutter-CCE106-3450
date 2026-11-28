import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/demo_qr_token.dart';
import '../core/utils/formatters.dart';
import '../models/app_user_model.dart';
import '../models/booking_model.dart';
import '../models/court_model.dart';
import '../models/open_play_model.dart';
import '../models/slot_model.dart';
import '../models/venue_model.dart';
import 'demo_seed.dart';

const _unset = Object();

class DemoState {
  const DemoState({
    required this.user,
    required this.venues,
    required this.slots,
    required this.bookings,
    required this.sessions,
  });

  final AppUser? user;
  final List<Venue> venues;
  final List<Slot> slots;
  final List<Booking> bookings;
  final List<OpenPlaySession> sessions;

  DemoState copyWith({
    Object? user = _unset,
    List<Venue>? venues,
    List<Slot>? slots,
    List<Booking>? bookings,
    List<OpenPlaySession>? sessions,
  }) {
    return DemoState(
      user: identical(user, _unset) ? this.user : user as AppUser?,
      venues: venues ?? this.venues,
      slots: slots ?? this.slots,
      bookings: bookings ?? this.bookings,
      sessions: sessions ?? this.sessions,
    );
  }
}

class SlotConflictException implements Exception {
  const SlotConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DemoStore extends Notifier<DemoState> {
  var _sequence = 1000;

  @override
  DemoState build() {
    final seed = buildDemoSeed(DateTime.now());
    return DemoState(
      user: null,
      venues: seed.venues,
      slots: seed.slots,
      bookings: seed.bookings,
      sessions: seed.sessions,
    );
  }

  // ---------------------------------------------------------------------------
  // Auth (demo only)
  // ---------------------------------------------------------------------------

  void signInAsPlayer() => state = state.copyWith(user: demoPlayerUser);

  void signInAsStaff() => state = state.copyWith(user: demoStaffUser);

  void signOut() => state = state.copyWith(user: null);

  /// Mirrors a Firebase Auth session into the local store while the UI is
  /// still backed by demo data (Phase 2 bridge, removed in Phase 3).
  void setUser(AppUser? user) {
    if (state.user?.uid == user?.uid) return;
    state = state.copyWith(user: user);
  }

  // ---------------------------------------------------------------------------
  // Reservations
  // ---------------------------------------------------------------------------

  Booking reserveSlot({
    required Venue venue,
    required Court court,
    required String date,
    required int startHour,
    required int durationHours,
    required PaymentMethod paymentMethod,
  }) {
    final player = state.user;
    if (player == null) {
      throw const SlotConflictException('Sign in to reserve a court.');
    }

    final now = DateTime.now();
    final startsAt = slotStart(date, startHour);
    if (!startsAt.isAfter(now)) {
      throw const SlotConflictException('That slot has already started.');
    }

    final updatedSlots = [...state.slots];
    final slotIds = <String>[];
    final slotKeys = <String>[];

    for (var i = 0; i < durationHours; i++) {
      final hour = startHour + i;
      final index = updatedSlots.indexWhere((slot) =>
          slot.facilityId == venue.id &&
          slot.courtId == court.id &&
          slot.date == date &&
          slot.startHour == hour);
      if (index == -1) {
        throw const SlotConflictException('That time is outside operating hours.');
      }
      final slot = updatedSlots[index];
      if (!slot.isAvailableAt(now)) {
        throw SlotConflictException(
          '${court.name} at ${hourLabel(hour)} was just taken. Pick another slot.',
        );
      }
      slotIds.add(slot.id);
      slotKeys.add(slot.key);
    }

    final holdExpiresAt = _holdExpiry(
      method: paymentMethod,
      now: now,
      startsAt: startsAt,
      cashHoldMinutes: venue.cashHoldMinutes,
    );

    final bookingId = 'bk_${_sequence++}';
    for (final slotKey in slotKeys) {
      final index = updatedSlots.indexWhere((slot) => slot.key == slotKey);
      updatedSlots[index] = updatedSlots[index].copyWith(
        status: SlotStatus.held,
        bookingId: bookingId,
        holdExpiresAt: holdExpiresAt,
      );
    }

    final booking = Booking(
      id: bookingId,
      facilityId: venue.id,
      facilityName: venue.name,
      courtId: court.id,
      courtName: court.name,
      playerId: player.uid,
      playerName: player.name,
      date: date,
      startHour: startHour,
      durationHours: durationHours,
      slotIds: slotIds,
      totalFee: court.hourlyRate * durationHours,
      paymentMethod: paymentMethod,
      status: BookingStatus.pendingPayment,
      createdAt: now,
      holdExpiresAt: holdExpiresAt,
    );

    state = state.copyWith(
      slots: updatedSlots,
      bookings: [booking, ...state.bookings],
    );
    return booking;
  }

  DateTime _holdExpiry({
    required PaymentMethod method,
    required DateTime now,
    required DateTime startsAt,
    required int cashHoldMinutes,
  }) {
    final window = method == PaymentMethod.cash
        ? Duration(minutes: math.max(15, cashHoldMinutes))
        : const Duration(minutes: 15);
    final candidate = now.add(window);
    // Cash holds are capped at the slot start.
    if (method == PaymentMethod.cash && candidate.isAfter(startsAt)) {
      return startsAt;
    }
    return candidate;
  }

  /// Simulated gateway success. In production only the webhook may do this.
  void completeOnlinePayment(String bookingId) {
    _updateBooking(bookingId, (booking) {
      return booking.copyWith(
        status: BookingStatus.verified,
        qrToken: issueDemoQrToken(
          bookingId: booking.id,
          facilityId: booking.facilityId,
          startsAt: booking.startsAt,
          duration: Duration(hours: booking.durationHours),
        ),
        verifiedBy: 'gateway (demo)',
        paidAt: DateTime.now(),
        clearHold: true,
      );
    });
    _reserveSlotsFor(bookingId);
  }

  void submitPaymentProof(String bookingId, String reference) {
    _updateBooking(bookingId, (booking) {
      return booking.copyWith(
        status: BookingStatus.paymentReview,
        paymentRef: reference,
        proofPath: 'proofs/${booking.facilityId}/${booking.id}.png',
        clearHold: true,
      );
    });
  }

  void approvePayment(String bookingId) {
    final staffId = state.user?.uid ?? 'staff-demo';
    _updateBooking(bookingId, (booking) {
      return booking.copyWith(
        status: BookingStatus.verified,
        qrToken: issueDemoQrToken(
          bookingId: booking.id,
          facilityId: booking.facilityId,
          startsAt: booking.startsAt,
          duration: Duration(hours: booking.durationHours),
        ),
        verifiedBy: staffId,
        paidAt: DateTime.now(),
        clearHold: true,
      );
    });
    _reserveSlotsFor(bookingId);
  }

  void rejectPayment(String bookingId) {
    final now = DateTime.now();
    final expiry = now.add(const Duration(minutes: 15));
    _updateBooking(bookingId, (booking) {
      return booking.copyWith(
        status: BookingStatus.pendingPayment,
        holdExpiresAt: expiry,
      );
    });
    _setHoldExpiry(bookingId, expiry);
  }

  void verifyAndCheckIn(String bookingId) {
    final staffId = state.user?.uid ?? 'staff-demo';
    _updateBooking(bookingId, (booking) {
      return booking.copyWith(
        status: BookingStatus.checkedIn,
        verifiedBy: staffId,
        checkedInAt: DateTime.now(),
        paidAt: booking.paidAt ?? DateTime.now(),
        clearHold: true,
      );
    });
    _reserveSlotsFor(bookingId);
  }

  // ---------------------------------------------------------------------------
  // Open play
  // ---------------------------------------------------------------------------

  void joinOpenPlay(String sessionId) {
    final player = state.user;
    if (player == null) {
      throw const SlotConflictException('Sign in to join open play.');
    }
    state = state.copyWith(
      sessions: [
        for (final session in state.sessions)
          if (session.id == sessionId)
            _joinedSession(session, player.uid)
          else
            session,
      ],
    );
  }

  OpenPlaySession _joinedSession(OpenPlaySession session, String uid) {
    if (session.hasParticipant(uid)) return session;
    if (session.isFull) {
      throw const SlotConflictException('This session is already full.');
    }
    return session.copyWith(participantIds: [...session.participantIds, uid]);
  }

  void leaveOpenPlay(String sessionId) {
    final uid = state.user?.uid;
    if (uid == null) return;
    state = state.copyWith(
      sessions: [
        for (final session in state.sessions)
          if (session.id == sessionId)
            session.copyWith(
              participantIds:
                  session.participantIds.where((id) => id != uid).toList(),
            )
          else
            session,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hold expiry (Hard Rule 3 — cleanup is not required for correctness)
  // ---------------------------------------------------------------------------

  void expireStaleHolds() {
    final now = DateTime.now();
    final expiredIds = <String>{};
    final updatedBookings = <Booking>[];

    for (final booking in state.bookings) {
      final lapsed = booking.status == BookingStatus.pendingPayment &&
          booking.holdExpiresAt != null &&
          !booking.holdExpiresAt!.isAfter(now);
      if (lapsed) {
        expiredIds.add(booking.id);
        updatedBookings.add(
          booking.copyWith(status: BookingStatus.expired, clearHold: true),
        );
      } else {
        updatedBookings.add(booking);
      }
    }

    if (expiredIds.isEmpty) return;

    final updatedSlots = [
      for (final slot in state.slots)
        if (slot.bookingId != null && expiredIds.contains(slot.bookingId))
          slot.copyWith(
            status: SlotStatus.available,
            clearBooking: true,
            clearHold: true,
          )
        else
          slot,
    ];

    state = state.copyWith(bookings: updatedBookings, slots: updatedSlots);
  }

  // ---------------------------------------------------------------------------
  // QR check-in (demo token verification)
  // ---------------------------------------------------------------------------

  ScanResult scanToken({required String token, required String facilityId}) {
    final payload = DemoQrPayload.tryParse(token.trim());
    if (payload == null) {
      return const ScanResult(
        outcome: ScanOutcome.invalidToken,
        message: 'Invalid token. Signature could not be verified.',
      );
    }
    if (payload.facilityId != facilityId) {
      return const ScanResult(
        outcome: ScanOutcome.wrongFacility,
        message: 'This pass belongs to another club.',
      );
    }
    final booking = _bookingById(payload.bookingId);
    if (booking == null) {
      return const ScanResult(
        outcome: ScanOutcome.unknownBooking,
        message: 'Booking not found in the offline roster.',
      );
    }
    if (booking.status == BookingStatus.checkedIn) {
      return ScanResult(
        outcome: ScanOutcome.alreadyCheckedIn,
        message: '${booking.playerName} is already checked in.',
      );
    }
    if (booking.status != BookingStatus.verified) {
      return ScanResult(
        outcome: ScanOutcome.unverified,
        message: 'Payment is not verified for ${booking.playerName}.',
      );
    }
    if (!payload.isInsideWindow(DateTime.now())) {
      return const ScanResult(
        outcome: ScanOutcome.outsideWindow,
        message: 'Outside the validity window (opens 30 min before play).',
      );
    }

    _updateBooking(booking.id, (current) {
      return current.copyWith(
        status: BookingStatus.checkedIn,
        checkedInAt: DateTime.now(),
        verifiedBy: state.user?.uid ?? 'staff-demo',
      );
    });
    _reserveSlotsFor(booking.id);
    return ScanResult(
      outcome: ScanOutcome.valid,
      message: '${booking.playerName} · ${booking.courtName} · ${booking.timeLabel}',
      bookingId: booking.id,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Booking? _bookingById(String id) {
    for (final booking in state.bookings) {
      if (booking.id == id) return booking;
    }
    return null;
  }

  void _updateBooking(String id, Booking Function(Booking) update) {
    state = state.copyWith(
      bookings: [
        for (final booking in state.bookings)
          if (booking.id == id) update(booking) else booking,
      ],
    );
  }

  void _reserveSlotsFor(String bookingId) {
    state = state.copyWith(
      slots: [
        for (final slot in state.slots)
          if (slot.bookingId == bookingId)
            slot.copyWith(
              status: SlotStatus.reserved,
              clearHold: true,
            )
          else
            slot,
      ],
    );
  }

  void _setHoldExpiry(String bookingId, DateTime expiry) {
    state = state.copyWith(
      slots: [
        for (final slot in state.slots)
          if (slot.bookingId == bookingId)
            slot.copyWith(
              status: SlotStatus.held,
              holdExpiresAt: expiry,
            )
          else
            slot,
      ],
    );
  }
}

enum ScanOutcome {
  valid,
  invalidToken,
  wrongFacility,
  outsideWindow,
  unverified,
  alreadyCheckedIn,
  unknownBooking,
}

class ScanResult {
  const ScanResult({
    required this.outcome,
    required this.message,
    this.bookingId,
  });

  final ScanOutcome outcome;
  final String message;
  final String? bookingId;

  bool get isSuccess => outcome == ScanOutcome.valid;
}

final demoStoreProvider = NotifierProvider<DemoStore, DemoState>(DemoStore.new);
