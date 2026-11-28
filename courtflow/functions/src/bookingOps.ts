import {
  DocumentData,
  DocumentReference,
  DocumentSnapshot,
  Timestamp,
  Transaction,
} from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { db } from './admin';

export interface BookingData {
  facilityId?: string;
  courtId: string;
  playerId: string;
  date: string;
  startHour: number;
  durationHours: number;
  slotIds?: string[];
  paymentMethod: string;
  status: string;
  holdExpiresAt?: Timestamp | null;
  paymentRef?: string | null;
  proofPath?: string | null;
}

export function bookingDoc(
  facilityId: string,
  bookingId: string
): DocumentReference<DocumentData> {
  return db.doc(`venues/${facilityId}/bookings/${bookingId}`);
}

export function slotRefsFor(
  facilityId: string,
  booking: BookingData
): DocumentReference<DocumentData>[] {
  const courtRef = db.doc(`venues/${facilityId}/courts/${booking.courtId}`);
  return (booking.slotIds ?? []).map((slotId) =>
    courtRef.collection('slots').doc(slotId)
  );
}

export async function loadBookingInTransaction(
  transaction: Transaction,
  facilityId: string,
  bookingId: string
): Promise<{
  ref: DocumentReference<DocumentData>;
  booking: BookingData;
}> {
  const ref = bookingDoc(facilityId, bookingId);
  const snapshot = await transaction.get(ref);
  if (!snapshot.exists) {
    throw new HttpsError('not-found', 'Booking was not found.');
  }
  return { ref, booking: snapshot.data() as BookingData };
}

/**
 * Every payment transition must still own the exact slots it reserved.
 * Missing slots or a changed bookingId mean the hold was released.
 */
export async function assertSlotsOwned(
  transaction: Transaction,
  refs: DocumentReference<DocumentData>[],
  bookingId: string
): Promise<DocumentSnapshot<DocumentData>[]> {
  if (refs.length === 0) {
    throw new HttpsError('failed-precondition', 'Booking has no slots.');
  }
  const snapshots = await transaction.getAll(...refs);
  for (const snapshot of snapshots) {
    if (
      !snapshot.exists ||
      snapshot.get('bookingId') !== bookingId ||
      snapshot.get('status') === 'available'
    ) {
      throw new HttpsError(
        'failed-precondition',
        'This hold is no longer active. Start a new booking.'
      );
    }
  }
  return snapshots;
}

export function setSlotsReserved(
  transaction: Transaction,
  refs: DocumentReference<DocumentData>[]
): void {
  for (const ref of refs) {
    transaction.set(
      ref,
      { status: 'reserved', holdExpiresAt: null },
      { merge: true }
    );
  }
}

export function setSlotsHeld(
  transaction: Transaction,
  refs: DocumentReference<DocumentData>[],
  bookingId: string,
  holdAt: Date | null
): void {
  for (const ref of refs) {
    transaction.set(
      ref,
      {
        status: 'held',
        bookingId,
        holdExpiresAt: holdAt ? Timestamp.fromDate(holdAt) : null,
      },
      { merge: true }
    );
  }
}

export function setSlotsAvailable(
  transaction: Transaction,
  refs: DocumentReference<DocumentData>[]
): void {
  for (const ref of refs) {
    transaction.set(
      ref,
      { status: 'available', bookingId: null, holdExpiresAt: null },
      { merge: true }
    );
  }
}
