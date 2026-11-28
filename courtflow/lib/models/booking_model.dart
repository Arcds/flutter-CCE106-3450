import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';
import 'venue_model.dart';

enum BookingStatus {
  pendingPayment,
  paymentReview,
  verified,
  checkedIn,
  cancelled,
  expired,
}

extension BookingStatusX on BookingStatus {
  String get label => switch (this) {
        BookingStatus.pendingPayment => 'Pending Payment',
        BookingStatus.paymentReview => 'For Review',
        BookingStatus.verified => 'Verified',
        BookingStatus.checkedIn => 'Checked In',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.expired => 'Expired',
      };

  bool get isActive =>
      this == BookingStatus.pendingPayment ||
      this == BookingStatus.paymentReview ||
      this == BookingStatus.verified;
}

class Booking {
  const Booking({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.courtId,
    required this.courtName,
    required this.playerId,
    required this.playerName,
    required this.date,
    required this.startHour,
    required this.durationHours,
    required this.slotIds,
    required this.totalFee,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.holdExpiresAt,
    this.paymentRef,
    this.proofPath,
    this.qrToken,
    this.verifiedBy,
    this.checkedInAt,
    this.paidAt,
  });

  factory Booking.fromMap(String id, Map<String, dynamic> data) {
    return Booking(
      id: id,
      facilityId: data['facilityId'] as String? ?? '',
      facilityName: data['facilityName'] as String? ?? '',
      courtId: data['courtId'] as String? ?? '',
      courtName: data['courtName'] as String? ?? '',
      playerId: data['playerId'] as String? ?? '',
      playerName: data['playerName'] as String? ?? '',
      date: data['date'] as String? ?? '',
      startHour: (data['startHour'] as num?)?.toInt() ?? 0,
      durationHours: (data['durationHours'] as num?)?.toInt() ?? 1,
      slotIds: [
        for (final slot in (data['slotIds'] as List<dynamic>? ?? const []))
          '$slot',
      ],
      totalFee: (data['totalFee'] as num?)?.toDouble() ?? 0,
      paymentMethod: switch (data['paymentMethod']) {
        'ewallet' => PaymentMethod.ewallet,
        'cash' => PaymentMethod.cash,
        _ => PaymentMethod.online,
      },
      status: switch (data['status']) {
        'payment_review' => BookingStatus.paymentReview,
        'verified' => BookingStatus.verified,
        'checked_in' => BookingStatus.checkedIn,
        'cancelled' => BookingStatus.cancelled,
        'expired' => BookingStatus.expired,
        _ => BookingStatus.pendingPayment,
      },
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      holdExpiresAt: _date(data['holdExpiresAt']),
      paymentRef: data['paymentRef'] as String?,
      proofPath: data['proofPath'] as String?,
      qrToken: data['qrToken'] as String?,
      verifiedBy: data['verifiedBy'] as String?,
      checkedInAt: _date(data['checkedInAt']),
      paidAt: _date(data['paidAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  final String id;
  final String facilityId;
  final String facilityName;
  final String courtId;
  final String courtName;
  final String playerId;
  final String playerName;
  final String date;
  final int startHour;
  final int durationHours;
  final List<String> slotIds;
  final double totalFee;
  final PaymentMethod paymentMethod;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime? holdExpiresAt;
  final String? paymentRef;
  final String? proofPath;
  final String? qrToken;
  final String? verifiedBy;
  final DateTime? checkedInAt;
  final DateTime? paidAt;

  DateTime get startsAt => slotStart(date, startHour);
  DateTime get endsAt => startsAt.add(Duration(hours: durationHours));

  String get timeLabel => timeRangeLabel(startHour, durationHours);
  String get feeLabel => peso(totalFee);

  Duration remainingHold(DateTime now) =>
      holdExpiresAt == null ? Duration.zero : holdExpiresAt!.difference(now);

  bool get needsPayment =>
      status == BookingStatus.pendingPayment || status == BookingStatus.paymentReview;

  Booking copyWith({
    BookingStatus? status,
    DateTime? holdExpiresAt,
    bool clearHold = false,
    String? paymentRef,
    String? proofPath,
    String? qrToken,
    String? verifiedBy,
    DateTime? checkedInAt,
    DateTime? paidAt,
    int? durationHours,
    double? totalFee,
    List<String>? slotIds,
  }) {
    return Booking(
      id: id,
      facilityId: facilityId,
      facilityName: facilityName,
      courtId: courtId,
      courtName: courtName,
      playerId: playerId,
      playerName: playerName,
      date: date,
      startHour: startHour,
      durationHours: durationHours ?? this.durationHours,
      slotIds: slotIds ?? this.slotIds,
      totalFee: totalFee ?? this.totalFee,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt,
      holdExpiresAt: clearHold ? null : (holdExpiresAt ?? this.holdExpiresAt),
      paymentRef: paymentRef ?? this.paymentRef,
      proofPath: proofPath ?? this.proofPath,
      qrToken: qrToken ?? this.qrToken,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
