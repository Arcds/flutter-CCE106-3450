import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  bookingTotal,
  holdExpiryFor,
  manilaStart,
  slotDocId,
} from './domain';

test('manilaStart converts venue-local time to UTC', () => {
  assert.equal(
    manilaStart('2026-01-01', 0).toISOString(),
    '2025-12-31T16:00:00.000Z'
  );
  assert.equal(
    manilaStart('2026-01-01', 18).toISOString(),
    '2026-01-01T10:00:00.000Z'
  );
});

test('manilaStart rejects malformed dates and hours', () => {
  assert.throws(() => manilaStart('01-01-2026', 8));
  assert.throws(() => manilaStart('2026-01-01', 24));
  assert.throws(() => manilaStart('2026-01-01', 8.5));
});

test('online holds last 15 minutes', () => {
  const now = new Date('2026-01-01T00:00:00.000Z');
  const start = new Date('2026-01-01T02:00:00.000Z');
  assert.equal(
    holdExpiryFor('online', now, start).toISOString(),
    '2026-01-01T00:15:00.000Z'
  );
});

test('cash holds use the venue window and cap at slot start', () => {
  const now = new Date('2026-01-01T00:00:00.000Z');
  const later = new Date('2026-01-01T05:00:00.000Z');
  const soon = new Date('2026-01-01T00:30:00.000Z');

  assert.equal(
    holdExpiryFor('cash', now, later, 120).toISOString(),
    '2026-01-01T02:00:00.000Z'
  );
  assert.equal(
    holdExpiryFor('cash', now, soon, 120).toISOString(),
    '2026-01-01T00:30:00.000Z'
  );
});

test('hold expiry rejects slots that already started', () => {
  const now = new Date('2026-01-01T00:00:00.000Z');
  assert.throws(() => holdExpiryFor('online', now, now));
});

test('slot ids and totals are deterministic', () => {
  assert.equal(slotDocId('2026-01-01', 9), '2026-01-01_9');
  assert.equal(bookingTotal(350, 2), 700);
  assert.equal(bookingTotal(333.33, 3), 999.99);
});
