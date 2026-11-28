import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/demo_store.dart';
import '../models/app_user_model.dart';
import '../models/venue_model.dart';
import 'backend_providers.dart';

/// A booking the player started before signing in. Resumed after auth.
class BookingIntent {
  const BookingIntent({
    required this.facilityId,
    required this.courtId,
    required this.date,
    required this.startHour,
    required this.durationHours,
    required this.paymentMethod,
  });

  final String facilityId;
  final String courtId;
  final String date;
  final int startHour;
  final int durationHours;
  final PaymentMethod paymentMethod;
}

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateUtils.dateOnly(DateTime.now());

  void select(DateTime date) => state = DateUtils.dateOnly(date);

  void resetToToday() => state = DateUtils.dateOnly(DateTime.now());
}

class SelectedCourtNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? courtId) => state = courtId;

  void clear() => state = null;
}

class PendingBookingNotifier extends Notifier<BookingIntent?> {
  @override
  BookingIntent? build() => null;

  void set(BookingIntent intent) => state = intent;

  void clear() => state = null;
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

final selectedCourtProvider =
    NotifierProvider<SelectedCourtNotifier, String?>(SelectedCourtNotifier.new);

final pendingBookingProvider =
    NotifierProvider<PendingBookingNotifier, BookingIntent?>(PendingBookingNotifier.new);

final currentUserProvider = Provider<AppUser?>((ref) {
  if (!AppConfig.useFirebase) {
    return ref.watch(demoStoreProvider.select((state) => state.user));
  }
  return ref.watch(firebaseAuthUserProvider).value;
});

final venuesProvider = Provider<List<Venue>>(
  (ref) => ref.watch(demoStoreProvider.select((state) => state.venues)),
);

final visibleVenuesProvider = Provider<List<Venue>>(
  (ref) => ref.watch(demoStoreProvider.select(
        (state) => state.venues.where((venue) => venue.publicDirectoryVisible).toList(),
      )),
);
