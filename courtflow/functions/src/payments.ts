import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './admin';
import {
  assertSlotsOwned,
  loadBookingInTransaction,
  setSlotsAvailable,
  setSlotsHeld,
  setSlotsReserved,
  slotRefsFor,
} from './bookingOps';
import { holdExpiryFor, manilaStart, REGION } from './domain';
import { assertStaff } from './staff';
import { optionalString, requireString, requireUid } from './validation';

function assertOwner(bookingPlayerId: string, uid: string): void {
  if (bookingPlayerId !== uid) {
    throw new HttpsError('permission-denied', 'This is not your booking.');
  }
}

function holdIsExpired(hold: Timestamp | null | undefined): boolean {
  return hold instanceof Timestamp && hold.toMillis() <= Date.now();
}

/**
 * Simulated online payment. No payment provider is contacted; the server
 * verifies the hold and marks the booking verified.
 */
export const completeMockPayment = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const facilityId = requireString(request.data, 'facilityId');
  const bookingId = requireString(request.data, 'bookingId');

  await db.runTransaction(async (transaction) => {
    const { ref, booking } = await loadBookingInTransaction(
      transaction,
      facilityId,
      bookingId
    );
    assertOwner(booking.playerId, uid);
    if (booking.paymentMethod !== 'online') {
      throw new HttpsError(
        'failed-precondition',
        'This booking is not an online payment.'
      );
    }
    if (booking.status !== 'pending_payment') {
      throw new HttpsError(
        'failed-precondition',
        'This booking is not awaiting payment.'
      );
    }
    if (holdIsExpired(booking.holdExpiresAt)) {
      throw new HttpsError(
        'failed-precondition',
        'The payment hold expired. Start a new booking.'
      );
    }

    const refs = slotRefsFor(facilityId, booking);
    await assertSlotsOwned(transaction, refs, bookingId);
    transaction.update(ref, {
      status: 'verified',
      paidAt: Timestamp.now(),
      verifiedBy: 'demo-online',
      holdExpiresAt: null,
    });
    setSlotsReserved(transaction, refs);
  });

  return { ok: true };
});

/**
 * E-wallet proof submission. The player only supplies a reference (and an
 * optional Storage path); staff approval is still required.
 */
export const submitPaymentProof = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const facilityId = requireString(request.data, 'facilityId');
  const bookingId = requireString(request.data, 'bookingId');
  const reference = requireString(request.data, 'reference');
  const proofPath = optionalString(request.data, 'proofPath');
  if (reference.length < 4 || reference.length > 120) {
    throw new HttpsError(
      'invalid-argument',
      'Reference must be between 4 and 120 characters.'
    );
  }

  await db.runTransaction(async (transaction) => {
    const { ref, booking } = await loadBookingInTransaction(
      transaction,
      facilityId,
      bookingId
    );
    assertOwner(booking.playerId, uid);
    if (booking.paymentMethod !== 'ewallet') {
      throw new HttpsError(
        'failed-precondition',
        'This booking is not an e-wallet payment.'
      );
    }
    if (booking.status !== 'pending_payment') {
      throw new HttpsError(
        'failed-precondition',
        'This booking is not awaiting payment.'
      );
    }
    if (holdIsExpired(booking.holdExpiresAt)) {
      throw new HttpsError(
        'failed-precondition',
        'The payment hold expired. Start a new booking.'
      );
    }

    const refs = slotRefsFor(facilityId, booking);
    await assertSlotsOwned(transaction, refs, bookingId);
    transaction.update(ref, {
      status: 'payment_review',
      paymentRef: reference,
      proofPath: proofPath ?? null,
      holdExpiresAt: null,
    });
    // Review holds stay blocked with no expiry until staff decide.
    setSlotsHeld(transaction, refs, bookingId, null);
  });

  return { ok: true };
});

export const approvePayment = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const facilityId = requireString(request.data, 'facilityId');
  const bookingId = requireString(request.data, 'bookingId');
  await assertStaff(uid, facilityId);

  await db.runTransaction(async (transaction) => {
    const { ref, booking } = await loadBookingInTransaction(
      transaction,
      facilityId,
      bookingId
    );
    if (booking.status !== 'payment_review') {
      throw new HttpsError(
        'failed-precondition',
        'This booking is not waiting for payment review.'
      );
    }
    const refs = slotRefsFor(facilityId, booking);
    await assertSlotsOwned(transaction, refs, bookingId);
    transaction.update(ref, {
      status: 'verified',
      paidAt: Timestamp.now(),
      verifiedBy: uid,
      holdExpiresAt: null,
    });
    setSlotsReserved(transaction, refs);
  });

  return { ok: true };
});

export const rejectPayment = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const facilityId = requireString(request.data, 'facilityId');
  const bookingId = requireString(request.data, 'bookingId');
  await assertStaff(uid, facilityId);

  await db.runTransaction(async (transaction) => {
    const { ref, booking } = await loadBookingInTransaction(
      transaction,
      facilityId,
      bookingId
    );
    if (booking.status !== 'payment_review') {
      throw new HttpsError(
        'failed-precondition',
        'This booking is not waiting for payment review.'
      );
    }

    const refs = slotRefsFor(facilityId, booking);
    await assertSlotsOwned(transaction, refs, bookingId);

    const now = new Date();
    const startAt = manilaStart(booking.date, booking.startHour);
    if (startAt.getTime() <= now.getTime()) {
      transaction.update(ref, {
        status: 'expired',
        paymentRef: null,
        proofPath: null,
        holdExpiresAt: null,
      });
      setSlotsAvailable(transaction, refs);
      return;
    }

    const holdAt = holdExpiryFor('ewallet', now, startAt);
    transaction.update(ref, {
      status: 'pending_payment',
      paymentRef: null,
      proofPath: null,
      holdExpiresAt: Timestamp.fromDate(holdAt),
    });
    setSlotsHeld(transaction, refs, bookingId, holdAt);
  });

  return { ok: true };
});

/**
 * Cash flow: staff verify payment and check the player in. The booking must
 * still own its slots; an expired hold cannot be checked in.
 */
export const verifyAndCheckIn = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const facilityId = requireString(request.data, 'facilityId');
  const bookingId = requireString(request.data, 'bookingId');
  await assertStaff(uid, facilityId);

  await db.runTransaction(async (transaction) => {
    const { ref, booking } = await loadBookingInTransaction(
      transaction,
      facilityId,
      bookingId
    );
    if (booking.paymentMethod !== 'cash') {
      throw new HttpsError(
        'failed-precondition',
        'Only cash bookings are verified at the desk.'
      );
    }
    if (booking.status !== 'pending_payment') {
      throw new HttpsError(
        'failed-precondition',
        'This booking is not awaiting cash verification.'
      );
    }

    const refs = slotRefsFor(facilityId, booking);
    await assertSlotsOwned(transaction, refs, bookingId);
    const now = Timestamp.now();
    transaction.update(ref, {
      status: 'checked_in',
      paidAt: now,
      checkedInAt: now,
      verifiedBy: uid,
      holdExpiresAt: null,
    });
    setSlotsReserved(transaction, refs);

    const checkInRef = db.doc(
      `venues/${facilityId}/checkIns/${bookingId}_staff_${uid}`
    );
    transaction.set(checkInRef, {
      bookingId,
      staffId: uid,
      deviceId: 'staff-manual',
      scannedAt: now,
      result: 'valid',
    });
  });

  return { ok: true };
});
