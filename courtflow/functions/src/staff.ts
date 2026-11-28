import { HttpsError } from 'firebase-functions/v2/https';

import { db } from './admin';

export interface UserProfile {
  name?: string;
  email?: string;
  role?: string;
  clubRoles?: Record<string, string>;
  fcmTokens?: string[];
}

export async function requireProfile(uid: string): Promise<UserProfile> {
  const snapshot = await db.doc(`users/${uid}`).get();
  if (!snapshot.exists) {
    throw new HttpsError(
      'failed-precondition',
      'Complete your CourtFlow profile first.'
    );
  }
  return snapshot.data() as UserProfile;
}

export function profileManagesFacility(
  profile: UserProfile,
  facilityId: string
): boolean {
  if (profile.role === 'owner') return true;
  const role = profile.clubRoles?.[facilityId];
  return role === 'owner' || role === 'staff';
}

export async function assertStaff(
  uid: string,
  facilityId: string
): Promise<UserProfile> {
  const profile = await requireProfile(uid);
  if (!profileManagesFacility(profile, facilityId)) {
    throw new HttpsError(
      'permission-denied',
      'You do not manage this facility.'
    );
  }
  return profile;
}
