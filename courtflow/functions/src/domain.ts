export const REGION = 'asia-southeast1';

export type PaymentMethod = 'online' | 'ewallet' | 'cash';

export const ONLINE_HOLD_MINUTES = 15;
export const DEFAULT_CASH_HOLD_MINUTES = 120;
export const MANILA_OFFSET_MINUTES = 8 * 60;

/**
 * Converts a venue-local date + hour (Asia/Manila, UTC+8, no DST) to a UTC
 * instant. Date strings are `YYYY-MM-DD`.
 */
export function manilaStart(date: string, hour: number): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!match) {
    throw new Error('Date must use YYYY-MM-DD.');
  }
  if (!Number.isInteger(hour) || hour < 0 || hour > 23) {
    throw new Error('Start hour must be an integer between 0 and 23.');
  }
  const [, year, month, day] = match;
  const utcLikeLocal = Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    hour,
    0,
    0,
    0
  );
  return new Date(utcLikeLocal - MANILA_OFFSET_MINUTES * 60 * 1000);
}

/**
 * Online and e-wallet holds last 15 minutes. Cash holds use the venue setting
 * (default 120 minutes). Every hold is capped at the slot start time.
 */
export function holdExpiryFor(
  method: PaymentMethod,
  now: Date,
  startAt: Date,
  cashHoldMinutes: number = DEFAULT_CASH_HOLD_MINUTES
): Date {
  const startMs = startAt.getTime();
  if (startMs <= now.getTime()) {
    throw new Error('Slot start time has passed.');
  }
  const minutes =
    method === 'cash'
      ? Math.max(1, Math.floor(cashHoldMinutes))
      : ONLINE_HOLD_MINUTES;
  return new Date(
    Math.min(now.getTime() + minutes * 60 * 1000, startMs)
  );
}

export function slotDocId(date: string, startHour: number): string {
  return `${date}_${startHour}`;
}

/** Money is always derived from the court rate on the server. */
export function bookingTotal(hourlyRate: number, durationHours: number): number {
  if (!Number.isFinite(hourlyRate) || hourlyRate < 0) {
    throw new Error('Invalid hourly rate.');
  }
  if (!Number.isInteger(durationHours) || durationHours < 1) {
    throw new Error('Duration must be a positive integer.');
  }
  return Math.round(hourlyRate * durationHours * 100) / 100;
}
