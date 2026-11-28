import 'package:courtflow/core/utils/demo_qr_token.dart';
import 'package:courtflow/core/utils/formatters.dart';
import 'package:courtflow/models/slot_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Slot availability (Hard Rule 3)', () {
    Slot slot({SlotStatus status = SlotStatus.held, DateTime? expiresAt}) {
      return Slot(
        facilityId: 'club',
        courtId: 'court',
        date: '2026-11-27',
        startHour: 18,
        status: status,
        holdExpiresAt: expiresAt,
      );
    }

    test('lapsed hold counts as available', () {
      final now = DateTime.now();
      final lapsed = slot(expiresAt: now.subtract(const Duration(minutes: 1)));
      expect(lapsed.effectiveStatus(now), SlotStatus.available);
      expect(lapsed.isAvailableAt(now), isTrue);
    });

    test('active hold stays blocked', () {
      final now = DateTime.now();
      final active = slot(expiresAt: now.add(const Duration(minutes: 5)));
      expect(active.effectiveStatus(now), SlotStatus.held);
      expect(active.isAvailableAt(now), isFalse);
    });

    test('paused review hold (null expiry) stays blocked', () {
      final now = DateTime.now();
      expect(slot().effectiveStatus(now), SlotStatus.held);
    });

    test('reserved stays reserved', () {
      final now = DateTime.now();
      expect(
        slot(status: SlotStatus.reserved).effectiveStatus(now),
        SlotStatus.reserved,
      );
    });
  });

  group('Demo QR token', () {
    test('round trips and respects the validity window', () {
      final startsAt = DateTime.now();
      final token = issueDemoQrToken(
        bookingId: 'bk_1',
        facilityId: 'davao-pickleball-club',
        startsAt: startsAt,
        duration: const Duration(hours: 1),
      );

      final payload = DemoQrPayload.tryParse(token);
      expect(payload, isNotNull);
      expect(payload!.bookingId, 'bk_1');
      expect(payload.facilityId, 'davao-pickleball-club');
      expect(payload.isInsideWindow(startsAt), isTrue);
      expect(
        payload.isInsideWindow(startsAt.subtract(const Duration(minutes: 31))),
        isFalse,
      );
      expect(
        payload.isInsideWindow(startsAt.add(const Duration(hours: 2))),
        isFalse,
      );
    });

    test('rejects malformed tokens', () {
      expect(DemoQrPayload.tryParse('CFDEMO.@@@'), isNull);
      expect(DemoQrPayload.tryParse('NOT-A-TOKEN'), isNull);
      expect(DemoQrPayload.tryParse(''), isNull);
    });
  });

  group('Formatters', () {
    test('time ranges cross noon correctly', () {
      expect(timeRangeLabel(11, 2), '11:00 AM – 1:00 PM');
      expect(timeRangeLabel(18, 1), '6:00 PM – 7:00 PM');
    });

    test('countdown label', () {
      expect(countdownLabel(const Duration(seconds: 65)), '1:05 left');
      expect(countdownLabel(const Duration(minutes: 75)), '1h 15m left');
      expect(countdownLabel(const Duration(seconds: -1)), 'Expired');
    });
  });
}
