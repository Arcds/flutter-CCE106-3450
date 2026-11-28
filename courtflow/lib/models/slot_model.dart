import 'package:cloud_firestore/cloud_firestore.dart';

enum SlotStatus { available, held, reserved }

class Slot {
  const Slot({
    required this.facilityId,
    required this.courtId,
    required this.date,
    required this.startHour,
    this.status = SlotStatus.available,
    this.bookingId,
    this.holdExpiresAt,
  });

  factory Slot.fromMap(
    String facilityId,
    String courtId,
    String docId,
    Map<String, dynamic> data,
  ) {
    final parts = docId.split('_');
    final rawHold = data['holdExpiresAt'];
    return Slot(
      facilityId: facilityId,
      courtId: courtId,
      date: data['date'] as String? ?? (parts.isNotEmpty ? parts.first : docId),
      startHour: (data['startHour'] as num?)?.toInt() ??
          int.tryParse(parts.length > 1 ? parts.last : '') ??
          0,
      status: switch (data['status']) {
        'held' => SlotStatus.held,
        'reserved' => SlotStatus.reserved,
        _ => SlotStatus.available,
      },
      bookingId: data['bookingId'] as String?,
      holdExpiresAt: rawHold is Timestamp ? rawHold.toDate() : null,
    );
  }

  final String facilityId;
  final String courtId;

  /// `YYYY-MM-DD` in venue-local time.
  final String date;
  final int startHour;
  final SlotStatus status;
  final String? bookingId;
  final DateTime? holdExpiresAt;

  /// Firestore document id inside the court subcollection.
  String get id => '${date}_$startHour';

  /// App-local unique key (slot ids repeat across courts).
  String get key => '${facilityId}_${courtId}_$id';

  /// Hard Rule 3: a lapsed hold counts as available. A `held` slot with a null
  /// expiry is a paused review hold and stays blocked.
  SlotStatus effectiveStatus(DateTime now) {
    if (status == SlotStatus.held &&
        holdExpiresAt != null &&
        !holdExpiresAt!.isAfter(now)) {
      return SlotStatus.available;
    }
    return status;
  }

  bool isAvailableAt(DateTime now) => effectiveStatus(now) == SlotStatus.available;

  Slot copyWith({
    SlotStatus? status,
    String? bookingId,
    DateTime? holdExpiresAt,
    bool clearBooking = false,
    bool clearHold = false,
  }) {
    return Slot(
      facilityId: facilityId,
      courtId: courtId,
      date: date,
      startHour: startHour,
      status: status ?? this.status,
      bookingId: clearBooking ? null : (bookingId ?? this.bookingId),
      holdExpiresAt: clearHold ? null : (holdExpiresAt ?? this.holdExpiresAt),
    );
  }
}
