import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './admin';
import {
  bookingTotal,
  holdExpiryFor,
  manilaStart,
  PaymentMethod,
  REGION,
  slotDocId,
} from './domain';
import { requireProfile } from './staff';
import { requireInt, requireString, requireUid } from './validation';

function parseOperatingHour(value: unknown, fallback: number): number {
  if (typeof value !== 'string') return fallback;
  const parsed = Number.parseInt(value.split(':')[0] ?? '', 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * Creates a booking and holds every requested slot atomically. The client
 * never supplies the price, hold expiry, status or slot ids.
 */
export const reserveSlot = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const data = request.data;
  const facilityId = requireString(data, 'facilityId');
  const courtId = requireString(data, 'courtId');
  const date = requireString(data, 'date');
  const startHour = requireInt(data, 'startHour', 0, 23);
  const durationHours = requireInt(data, 'durationHours', 1, 8);
  const rawMethod = requireString(data, 'paymentMethod');
  if (rawMethod !== 'online' && rawMethod !== 'ewallet' && rawMethod !== 'cash') {
    throw new HttpsError('invalid-argument', 'Unsupported payment method.');
  }
  const paymentMethod = rawMethod as PaymentMethod;

  let startAt: Date;
  try {
    startAt = manilaStart(date, startHour);
  } catch (error) {
    throw new HttpsError('invalid-argument', (error as Error).message);
  }
  if (startAt.getTime() <= Date.now()) {
    throw new HttpsError('failed-precondition', 'That slot has already started.');
  }

  const profile = await requireProfile(uid);
  const venueRef = db.doc(`venues/${facilityId}`);
  const courtRef = venueRef.collection('courts').doc(courtId);

  const result = await db.runTransaction(async (transaction) => {
    const venueSnapshot = await transaction.get(venueRef);
    const courtSnapshot = await transaction.get(courtRef);
    if (!venueSnapshot.exists || !courtSnapshot.exists) {
      throw new HttpsError('not-found', 'Venue or court was not found.');
    }

    const venue = venueSnapshot.data() ?? {};
    const court = courtSnapshot.data() ?? {};
    if (court.isActive === false) {
      throw new HttpsError('failed-precondition', 'That court is inactive.');
    }

    const acceptedMethods = venue.acceptedPaymentMethods;
    if (
      !Array.isArray(acceptedMethods) ||
      !acceptedMethods.includes(paymentMethod)
    ) {
      throw new HttpsError(
        'failed-precondition',
        'This venue does not accept that payment method.'
      );
    }

    const hours = venue.operatingHours as
      | { open?: unknown; close?: unknown }
      | undefined;
    const openHour = parseOperatingHour(hours?.open, 6);
    const closeHour = parseOperatingHour(hours?.close, 22);
    if (startHour < openHour || startHour + durationHours > closeHour) {
      throw new HttpsError(
        'failed-precondition',
        'The requested time is outside the venue operating hours.'
      );
    }

    const hourlyRate = Number(court.hourlyRate);
    let totalFee: number;
    let holdAt: Date;
    try {
      totalFee = bookingTotal(hourlyRate, durationHours);
      holdAt = holdExpiryFor(
        paymentMethod,
        new Date(),
        startAt,
        Number(venue.cashHoldMinutes) || undefined
      );
    } catch (error) {
      throw new HttpsError('failed-precondition', (error as Error).message);
    }

    const slotRefs = Array.from({ length: durationHours }, (_, offset) => {
      const hour = startHour + offset;
      return courtRef.collection('slots').doc(slotDocId(date, hour));
    });
    const slotSnapshots = await transaction.getAll(...slotRefs);
    const nowMs = Date.now();
    for (const slot of slotSnapshots) {
      const slotData = slot.data();
      if (!slotData) continue;
      const hold = slotData.holdExpiresAt;
      const activeHold =
        slotData.status === 'held' &&
        (!(hold instanceof Timestamp) || hold.toMillis() > nowMs);
      if (slotData.status === 'reserved' || activeHold) {
        throw new HttpsError(
          'already-exists',
          'One or more of those slots were just taken.'
        );
      }
    }

    const bookingRef = venueRef.collection('bookings').doc();
    const slotIds = slotRefs.map((ref) => ref.id);
    const holdTimestamp = Timestamp.fromDate(holdAt);

    transaction.set(bookingRef, {
      facilityId,
      facilityName: venue.name ?? facilityId,
      courtId,
      courtName: court.name ?? courtId,
      playerId: uid,
      playerName: profile.name ?? 'CourtFlow Player',
      date,
      startHour,
      durationHours,
      slotIds,
      totalFee,
      paymentMethod,
      status: 'pending_payment',
      createdAt: Timestamp.now(),
      holdExpiresAt: holdTimestamp,
      paymentRef: null,
      proofPath: null,
      qrToken: null,
      verifiedBy: null,
      checkedInAt: null,
      paidAt: null,
    });

    slotRefs.forEach((slotRef, offset) => {
      transaction.set(slotRef, {
        facilityId,
        courtId,
        date,
        startHour: startHour + offset,
        status: 'held',
        bookingId: bookingRef.id,
        holdExpiresAt: holdTimestamp,
      });
    });

    return {
      bookingId: bookingRef.id,
      holdExpiresAt: holdAt.getTime(),
      totalFee,
    };
  });

  return result;
});
