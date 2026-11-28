import 'package:cloud_functions/cloud_functions.dart';

import '../core/config/app_config.dart';
import '../models/venue_model.dart';

class ReserveSlotResult {
  const ReserveSlotResult({
    required this.bookingId,
    required this.holdExpiresAt,
    required this.totalFee,
  });

  factory ReserveSlotResult.fromMap(Map<String, dynamic> data) {
    final rawHold = data['holdExpiresAt'];
    final hold = switch (rawHold) {
      num millis => DateTime.fromMillisecondsSinceEpoch(millis.toInt()),
      String value => DateTime.tryParse(value) ?? DateTime.now(),
      _ => DateTime.now(),
    };
    return ReserveSlotResult(
      bookingId: data['bookingId'] as String? ?? '',
      holdExpiresAt: hold,
      totalFee: (data['totalFee'] as num?)?.toDouble() ?? 0,
    );
  }

  final String bookingId;
  final DateTime holdExpiresAt;
  final double totalFee;
}

/// Typed wrappers for every callable Cloud Function.
class FunctionsService {
  FunctionsService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final FirebaseFunctions _functions;

  HttpsCallable _callable(String name) => _functions.httpsCallable(name);

  Future<ReserveSlotResult> reserveSlot({
    required String facilityId,
    required String courtId,
    required String date,
    required int startHour,
    required int durationHours,
    required PaymentMethod paymentMethod,
  }) async {
    final result = await _callable('reserveSlot').call<Map<String, dynamic>>({
      'facilityId': facilityId,
      'courtId': courtId,
      'date': date,
      'startHour': startHour,
      'durationHours': durationHours,
      'paymentMethod': paymentMethod.name,
    });
    return ReserveSlotResult.fromMap(result.data);
  }

  Future<void> completeMockPayment({
    required String facilityId,
    required String bookingId,
  }) async {
    await _callable('completeMockPayment').call<void>({
      'facilityId': facilityId,
      'bookingId': bookingId,
    });
  }

  Future<void> submitPaymentProof({
    required String facilityId,
    required String bookingId,
    required String reference,
    String? proofPath,
  }) async {
    await _callable('submitPaymentProof').call<void>({
      'facilityId': facilityId,
      'bookingId': bookingId,
      'reference': reference,
      'proofPath': ?proofPath,
    });
  }

  Future<void> approvePayment({
    required String facilityId,
    required String bookingId,
  }) async {
    await _callable('approvePayment').call<void>({
      'facilityId': facilityId,
      'bookingId': bookingId,
    });
  }

  Future<void> rejectPayment({
    required String facilityId,
    required String bookingId,
  }) async {
    await _callable('rejectPayment').call<void>({
      'facilityId': facilityId,
      'bookingId': bookingId,
    });
  }

  Future<void> verifyAndCheckIn({
    required String facilityId,
    required String bookingId,
  }) async {
    await _callable('verifyAndCheckIn').call<void>({
      'facilityId': facilityId,
      'bookingId': bookingId,
    });
  }
}
