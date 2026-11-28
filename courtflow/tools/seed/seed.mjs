/**
 * Seeds the Firebase emulators with the CourtFlow demo dataset.
 *
 * Defaults to 127.0.0.1 emulators. Set ALLOW_PROD_SEED=1 to target the real
 * project (requires Application Default Credentials) — only do that on a
 * throwaway project.
 */
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const allowProd = process.env.ALLOW_PROD_SEED === '1';
if (!allowProd) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8081';
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
}

const projectId =
  process.env.GCLOUD_PROJECT ??
  process.env.FIREBASE_PROJECT_ID ??
  'cce106-finalproject-4c95e';

initializeApp({ projectId });
const db = getFirestore();
const auth = getAuth();

const now = new Date();
const today = dateKey(now);
const tomorrow = dateKey(addDays(now, 1));
const inTwoDays = dateKey(addDays(now, 2));
const demoStartHour = Math.min(Math.max(manilaHour(now), 6), 20);
const dayMs = 24 * 60 * 60 * 1000;

function addDays(date, days) {
  return new Date(date.getTime() + days * dayMs);
}

function dateKey(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

function manilaHour(date) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Manila',
    hour: '2-digit',
    hour12: false,
  }).formatToParts(date);
  return Number(parts.find((part) => part.type === 'hour')?.value ?? '0') % 24;
}

function timestamp(date) {
  return Timestamp.fromDate(date);
}

async function ensureUser(uid, email, password, profile) {
  let user = null;
  try {
    user = await auth.getUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }

  if (!user) {
    // Remove an older generated-uid demo account so the seeded uid matches
    // the Phase 1 demo ids used by the local dataset.
    try {
      const existing = await auth.getUserByEmail(email);
      await auth.deleteUser(existing.uid);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    user = await auth.createUser({
      uid,
      email,
      password,
      displayName: profile.name,
    });
  } else {
    await auth.updateUser(uid, {
      email,
      password,
      displayName: profile.name,
    });
  }

  await db.doc(`users/${uid}`).set(
    {
      ...profile,
      email,
      createdAt: timestamp(now),
      updatedAt: timestamp(now),
    },
    { merge: true }
  );
  return user;
}

const player = await ensureUser(
  'player-demo',
  'player@courtflow.demo',
  'courtflow123',
  {
    name: 'Alex Cruz',
    role: 'player',
    clubRoles: {},
    fcmTokens: [],
  }
);

const staff = await ensureUser(
  'staff-demo',
  'staff@courtflow.demo',
  'courtflow123',
  {
    name: 'Jamie Rivera',
    role: 'staff',
    clubRoles: { 'davao-pickleball-club': 'staff' },
    fcmTokens: [],
  }
);

const venues = [
  {
    id: 'davao-pickleball-club',
    name: 'Davao Pickleball Club',
    slug: 'davao-pickleball-club',
    location: 'Bajada, Davao City',
    openHour: 6,
    closeHour: 22,
    rules:
      'Rubber-soled shoes only. 5-minute warm-up limit per court. No food on the playing surface.',
    announcements:
      'Night league finals this Saturday — courts 1 and 2 close at 6 PM.',
    paymentInstructions:
      'GCash: 0917 555 0100 (Davao Pickleball Club). Upload the reference number after sending.',
    cashHoldMinutes: 120,
    publicDirectoryVisible: true,
    subscriptionTier: 'Pro',
    courts: [
      { id: 'c1', name: 'Court 1', hourlyRate: 350 },
      { id: 'c2', name: 'Court 2', hourlyRate: 350 },
      { id: 'c3', name: 'Center Court', hourlyRate: 450 },
    ],
  },
  {
    id: 'matina-smash-courts',
    name: 'Matina Smash Courts',
    slug: 'matina-smash-courts',
    location: 'Matina, Davao City',
    openHour: 7,
    closeHour: 21,
    rules: 'Bring your own balls. Lights off at 9 PM sharp.',
    announcements: 'New LED lighting installed this week.',
    paymentInstructions: 'Maya: 0918 222 3344 (Matina Smash).',
    cashHoldMinutes: 60,
    publicDirectoryVisible: true,
    subscriptionTier: 'Starter',
    courts: [
      { id: 'm1', name: 'Court A', hourlyRate: 300 },
      { id: 'm2', name: 'Court B', hourlyRate: 300 },
    ],
  },
  {
    id: 'toril-indoor-courts',
    name: 'Toril Indoor Courts',
    slug: 'toril-indoor-courts',
    location: 'Toril, Davao City',
    openHour: 8,
    closeHour: 20,
    rules: '',
    announcements: '',
    paymentInstructions: '',
    cashHoldMinutes: 120,
    publicDirectoryVisible: false,
    subscriptionTier: 'Starter',
    courts: [{ id: 't1', name: 'Indoor 1', hourlyRate: 400 }],
  },
];

const bookings = [
  {
    id: 'bk_demo_pass',
    facilityId: 'davao-pickleball-club',
    facilityName: 'Davao Pickleball Club',
    courtId: 'c1',
    courtName: 'Court 1',
    playerId: player.uid,
    playerName: 'Alex Cruz',
    date: today,
    startHour: demoStartHour,
    durationHours: 1,
    slotIds: [`${today}_${demoStartHour}`],
    totalFee: 350,
    paymentMethod: 'online',
    status: 'verified',
    createdAt: timestamp(addDays(now, -1)),
    holdExpiresAt: null,
    paymentRef: null,
    proofPath: null,
    qrToken: null,
    verifiedBy: 'demo-online',
    checkedInAt: null,
    paidAt: timestamp(new Date(now.getTime() - 20 * 60 * 60 * 1000)),
  },
  {
    id: 'bk_review',
    facilityId: 'davao-pickleball-club',
    facilityName: 'Davao Pickleball Club',
    courtId: 'c2',
    courtName: 'Court 2',
    playerId: 'player-mika',
    playerName: 'Mika Santos',
    date: tomorrow,
    startHour: 19,
    durationHours: 1,
    slotIds: [`${tomorrow}_19`],
    totalFee: 350,
    paymentMethod: 'ewallet',
    status: 'payment_review',
    createdAt: timestamp(new Date(now.getTime() - 2 * 60 * 60 * 1000)),
    holdExpiresAt: null,
    paymentRef: 'GCASH-884210',
    proofPath: null,
    qrToken: null,
    verifiedBy: null,
    checkedInAt: null,
    paidAt: null,
  },
  {
    id: 'bk_cash',
    facilityId: 'davao-pickleball-club',
    facilityName: 'Davao Pickleball Club',
    courtId: 'c3',
    courtName: 'Center Court',
    playerId: 'player-paolo',
    playerName: 'Paolo Reyes',
    date: tomorrow,
    startHour: 17,
    durationHours: 2,
    slotIds: [`${tomorrow}_17`, `${tomorrow}_18`],
    totalFee: 900,
    paymentMethod: 'cash',
    status: 'pending_payment',
    createdAt: timestamp(new Date(now.getTime() - 10 * 60 * 1000)),
    holdExpiresAt: timestamp(new Date(now.getTime() + 90 * 60 * 1000)),
    paymentRef: null,
    proofPath: null,
    qrToken: null,
    verifiedBy: null,
    checkedInAt: null,
    paidAt: null,
  },
  {
    id: 'bk_checked',
    facilityId: 'davao-pickleball-club',
    facilityName: 'Davao Pickleball Club',
    courtId: 'c2',
    courtName: 'Court 2',
    playerId: 'player-lena',
    playerName: 'Lena Dizon',
    date: today,
    startHour: 8,
    durationHours: 1,
    slotIds: [`${today}_8`],
    totalFee: 350,
    paymentMethod: 'online',
    status: 'checked_in',
    createdAt: timestamp(addDays(now, -1)),
    holdExpiresAt: null,
    paymentRef: null,
    proofPath: null,
    qrToken: null,
    verifiedBy: staff.uid,
    checkedInAt: timestamp(new Date(now.getTime() - 4 * 60 * 60 * 1000)),
    paidAt: timestamp(addDays(now, -1)),
  },
  {
    id: 'bk_player_ewallet',
    facilityId: 'matina-smash-courts',
    facilityName: 'Matina Smash Courts',
    courtId: 'm1',
    courtName: 'Court A',
    playerId: player.uid,
    playerName: 'Alex Cruz',
    date: tomorrow,
    startHour: 18,
    durationHours: 1,
    slotIds: [`${tomorrow}_18`],
    totalFee: 300,
    paymentMethod: 'ewallet',
    status: 'pending_payment',
    createdAt: timestamp(new Date(now.getTime() - 4 * 60 * 1000)),
    holdExpiresAt: timestamp(new Date(now.getTime() + 11 * 60 * 1000)),
    paymentRef: null,
    proofPath: null,
    qrToken: null,
    verifiedBy: null,
    checkedInAt: null,
    paidAt: null,
  },
];

const locks = [
  {
    bookingId: 'bk_demo_pass',
    facilityId: 'davao-pickleball-club',
    courtId: 'c1',
    date: today,
    startHour: demoStartHour,
    durationHours: 1,
    status: 'reserved',
    holdExpiresAt: null,
  },
  {
    bookingId: 'bk_review',
    facilityId: 'davao-pickleball-club',
    courtId: 'c2',
    date: tomorrow,
    startHour: 19,
    durationHours: 1,
    status: 'held',
    holdExpiresAt: null,
  },
  {
    bookingId: 'bk_cash',
    facilityId: 'davao-pickleball-club',
    courtId: 'c3',
    date: tomorrow,
    startHour: 17,
    durationHours: 2,
    status: 'held',
    holdExpiresAt: timestamp(new Date(now.getTime() + 90 * 60 * 1000)),
  },
  {
    bookingId: 'bk_checked',
    facilityId: 'davao-pickleball-club',
    courtId: 'c2',
    date: today,
    startHour: 8,
    durationHours: 1,
    status: 'reserved',
    holdExpiresAt: null,
  },
  {
    bookingId: 'bk_player_ewallet',
    facilityId: 'matina-smash-courts',
    courtId: 'm1',
    date: tomorrow,
    startHour: 18,
    durationHours: 1,
    status: 'held',
    holdExpiresAt: timestamp(new Date(now.getTime() + 11 * 60 * 1000)),
  },
];

const sessions = [
  {
    id: 'op_sunset',
    facilityId: 'davao-pickleball-club',
    facilityName: 'Davao Pickleball Club',
    title: 'Sunset Open Play',
    skillTier: 'Intermediate',
    date: today,
    timeWindow: '6:00 PM – 9:00 PM',
    entryFee: 250,
    maxCapacity: 16,
    participantIds: [player.uid, ...Array.from({ length: 12 }, (_, i) => `guest_${i + 1}`)],
  },
  {
    id: 'op_beginner',
    facilityId: 'davao-pickleball-club',
    facilityName: 'Davao Pickleball Club',
    title: 'Beginner Foundations',
    skillTier: 'Beginner',
    date: tomorrow,
    timeWindow: '8:00 AM – 10:00 AM',
    entryFee: 200,
    maxCapacity: 12,
    participantIds: Array.from({ length: 12 }, (_, i) => `beginner_${i + 1}`),
  },
  {
    id: 'op_weekend',
    facilityId: 'matina-smash-courts',
    facilityName: 'Matina Smash Courts',
    title: 'Weekend Rally',
    skillTier: 'All Levels',
    date: inTwoDays,
    timeWindow: '3:00 PM – 6:00 PM',
    entryFee: 300,
    maxCapacity: 20,
    participantIds: Array.from({ length: 8 }, (_, i) => `rally_${i + 1}`),
  },
];

const batch = db.batch();
const batchTimestamp = timestamp(now);

for (const venue of venues) {
  const { id, courts, openHour, closeHour, ...rest } = venue;
  const venueRef = db.doc(`venues/${id}`);
  batch.set(
    venueRef,
    {
      ...rest,
      operatingHours: {
        open: `${String(openHour).padStart(2, '0')}:00`,
        close: `${String(closeHour).padStart(2, '0')}:00`,
      },
      acceptedPaymentMethods: ['online', 'ewallet', 'cash'],
      createdAt: batchTimestamp,
      updatedAt: batchTimestamp,
    },
    { merge: true }
  );
  for (const court of courts) {
    batch.set(venueRef.collection('courts').doc(court.id), {
      ...court,
      isActive: true,
      createdAt: batchTimestamp,
      updatedAt: batchTimestamp,
    });
  }
}

for (const booking of bookings) {
  const { facilityId, id, ...rest } = booking;
  batch.set(db.doc(`venues/${facilityId}/bookings/${id}`), {
    ...rest,
    facilityId,
    updatedAt: batchTimestamp,
  });
}

for (const lock of locks) {
  const { facilityId, courtId, date, startHour, ...rest } = lock;
  for (let offset = 0; offset < lock.durationHours; offset += 1) {
    const hour = startHour + offset;
    batch.set(
      db.doc(
        `venues/${facilityId}/courts/${courtId}/slots/${date}_${hour}`
      ),
      {
        facilityId,
        courtId,
        date,
        startHour: hour,
        status: rest.status,
        bookingId: rest.bookingId,
        holdExpiresAt: rest.holdExpiresAt,
      }
    );
  }
}

for (const session of sessions) {
  const { facilityId, id, ...rest } = session;
  batch.set(
    db.doc(`venues/${facilityId}/openPlaySessions/${id}`),
    { ...rest, facilityId, updatedAt: batchTimestamp }
  );
}

batch.set(
  db.doc('config/app'),
  {
    demoMode: true,
    functionsRegion: 'asia-southeast1',
    updatedAt: batchTimestamp,
  },
  { merge: true }
);

await batch.commit();

console.log(
  `Seeded CourtFlow${allowProd ? '' : ' emulators'} for project ${projectId}.`
);
console.log(`Player: player@courtflow.demo / courtflow123 (${player.uid})`);
console.log(`Staff:  staff@courtflow.demo / courtflow123 (${staff.uid})`);
console.log(
  `Venues: ${venues.length}, bookings: ${bookings.length}, open play: ${sessions.length}.`
);
