import { HttpsError } from 'firebase-functions/v2/https';

export function requireString(data: unknown, key: string): string {
  const value = (data as Record<string, unknown> | null)?.[key];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }
  return value.trim();
}

export function optionalString(data: unknown, key: string): string | undefined {
  const value = (data as Record<string, unknown> | null)?.[key];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `${key} must be a string.`);
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

export function requireInt(
  data: unknown,
  key: string,
  min: number,
  max: number
): number {
  const value = (data as Record<string, unknown> | null)?.[key];
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw new HttpsError('invalid-argument', `${key} must be an integer.`);
  }
  if (value < min || value > max) {
    throw new HttpsError(
      'invalid-argument',
      `${key} must be between ${min} and ${max}.`
    );
  }
  return value;
}

export function requireUid(request: {
  auth?: { uid?: string } | null;
}): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }
  return uid;
}
