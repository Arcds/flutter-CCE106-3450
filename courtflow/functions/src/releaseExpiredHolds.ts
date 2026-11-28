import { Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db } from './admin';
import {
  bookingDoc,
  BookingData,
  slotRefsFor,
} from './bookingOps';
import { REGION } from './domain';

/**
 * Expires lapsed holds and returns their slots to the public inventory.
 * Review holds have a null expiry and are never selected here.
 */
export const releaseExpiredHolds = onSchedule(
  {
    region: REGION,
    schedule: 'every 1 minutes',
    timeZone: 'Asia/Manila',
    retryCount: 0,
  },
  async () => {
    const expired = await db
      .collectionGroup('bookings')
      .where('status', '==', 'pending_payment')
      .where('holdExpiresAt', '<=', Timestamp.now())
      .limit(100)
      .get();

    for (const doc of expired.docs) {
      const pathSegments = doc.ref.path.split('/');
      const facilityId =
        (doc.get('facilityId') as string | undefined) ?? pathSegments[1];
      if (!facilityId) {
        logger.warn('Skipping booking without facilityId', doc.ref.path);
        continue;
      }

      try {
        await db.runTransaction(async (transaction) => {
          const ref = bookingDoc(facilityId, doc.id);
          const snapshot = await transaction.get(ref);
          if (!snapshot.exists) return;

          const booking = snapshot.data() as BookingData;
          if (booking.status !== 'pending_payment') return;
          const hold = booking.holdExpiresAt;
          if (!(hold instanceof Timestamp) || hold.toMillis() > Date.now()) {
            return;
          }

          const refs = slotRefsFor(facilityId, booking);
          const slots = refs.length
            ? await transaction.getAll(...refs)
            : [];

          transaction.update(ref, {
            status: 'expired',
            holdExpiresAt: null,
          });

          for (const slot of slots) {
            if (
              slot.exists &&
              slot.get('bookingId') === doc.id &&
              slot.get('status') === 'held'
            ) {
              transaction.set(
                slot.ref,
                { status: 'available', bookingId: null, holdExpiresAt: null },
                { merge: true }
              );
            }
          }
        });
      } catch (error) {
        logger.error('Failed to release expired hold', {
          bookingPath: doc.ref.path,
          error,
        });
      }
    }

    if (expired.size === 100) {
      logger.warn('Released 100 holds; more may remain for the next run.');
    }
  }
);
