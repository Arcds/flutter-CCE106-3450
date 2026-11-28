# CourtFlow — Implementation Plan

Companion plan for [`agent_context.md`](./agent_context.md) (copy of the project spec).
The root `courtflow_agent_context.md` remains the original source of truth; this plan records
approved deviations and build progress.

Scope reference: `CourtFlow_Chapters_1_and_2_Final-v7.docx`.

---

## 0. Approved Amendments

### 2026-11-26 — No payment gateway (Phase 1)

The hosted gateway (PayMongo/Xendit), checkout redirect, webhook and Secret Manager keys are
**out of scope for now**. Payment is simplified to a demo flow:

| Method | Phase 1 behavior | Phase 2 behavior |
|---|---|---|
| `online` | "Pay now" instantly marks the booking `verified` and issues a demo QR token | Callable `completeMockPayment` verifies the hold and marks the booking `verified`; still no gateway |
| `ewallet` | Player submits a reference number → `payment_review`; staff Approve/Reject | `submitPaymentProof` / `approvePayment` / `rejectPayment` callables; screenshot upload still Phase 3 |
| `cash` | Hold with `cashHoldMinutes` capped at slot start; staff Verify & Check In | `verifyAndCheckIn` callable; unchanged business rule |

Consequences:

- No `createCheckout`, no `paymentWebhook`, no gateway secret, no `/pay/return` route.
- Server-authoritative rule still applies in Phase 2: a callable (not the client) must flip
  payment status once Firestore is wired. Phase 1 keeps it in memory.
- QR tokens are `CFDEMO.<base64url(payload)>`, unsigned, and clearly labelled as demo.
  Real Ed25519 signing/verification remains Phase 4 work.
- `online` is auto-verified; e-wallet review and cash check-in still exercise the staff queue.

---

## 1. Current Repository State

| Area | Status |
|---|---|
| Flutter scaffold | ✅ present |
| Dependencies | ✅ `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `flutter_riverpod 3.5`, `go_router 18.1`, `qr_flutter 4.1`, `intl` |
| `lib/main.dart` | ✅ `ProviderScope` + Firebase init + optional emulator wiring |
| Theme / router / models / providers | ✅ Phase 1 UI + Phase 2 auth/session bridge |
| Screens (player, auth, staff, scanner, notifications) | ✅ Phase 1 UI; auth screen now supports Firebase Auth behind a flag |
| Data | ⚠️ default remains in-memory `DemoStore`; Firestore repositories are built but screens are not migrated yet |
| Firebase Auth | ✅ email/password + `users/{uid}` bootstrap, `USE_FIREBASE` flag |
| Firestore repositories | ✅ venue/court/slot/booking/open-play reads + callable wrappers |
| Cloud Functions | ✅ `reserveSlot`, `releaseExpiredHolds`, payment review/check-in callables |
| `firestore.rules` / `storage.rules` / indexes | ✅ created; not deployed |
| Emulator + seed | ✅ config + `tools/seed`; not run here because Java/JDK is missing |
| Tests | ✅ 28 Flutter tests + 6 Functions domain tests |
| `flutter analyze` | ✅ no issues |

### Phase 1 delivered

```
lib/
├── main.dart / app.dart
├── core/
│   ├── router/app_router.dart          # go_router + /staff guard, deep link /club/:id
│   ├── theme/app_theme.dart            # evergreen palette
│   ├── utils/formatters.dart           # dates, peso, countdown
│   ├── utils/demo_qr_token.dart        # CFDEMO issue/parse (unsigned)
│   ├── utils/iterables.dart
│   └── widgets/                        # HoldCountdown, StatusPill
├── models/                             # venue, court, slot, booking, open play, user
├── data/
│   ├── demo_seed.dart                  # 3 clubs, slots, bookings, sessions
│   └── demo_store.dart                 # Riverpod notifier: reserve, pay, review, scan
├── providers/app_providers.dart        # selected date/court, pending booking intent
└── screens/
    ├── auth/auth_screen.dart           # demo player/staff login, guest exit
    ├── shell/app_shell.dart            # bottom nav + hold sweeper
    ├── player/
    │   ├── club_discovery_screen.dart
    │   ├── club_storefront_screen.dart # date strip, court chips, slot cards
    │   ├── booking_confirmation_sheet.dart
    │   ├── my_passes_screen.dart       # QR pass, pay/proof actions
    │   ├── open_play_screen.dart
    │   ├── notifications_screen.dart
    │   └── profile_settings_screen.dart
    └── staff/
        ├── staff_control_center_screen.dart
        └── qr_scanner_screen.dart      # manual token + demo validation
```

### Demo flows to try

1. **Guest → auth gate:** open a club → Reserve → Confirm → routed to `/auth` → player login →
   sheet reopens with the same slot → confirm → pass issued.
2. **Online:** pay online → booking verified → QR visible in My Passes → open QR full screen.
3. **E-wallet:** upload a reference → appears in Staff → For Review → Approve → player pass
   unlocks (switch to the staff demo account from Profile).
4. **Cash:** pay at desk → Staff → Verify & Check In → no QR.
5. **QR scan:** Staff → scan icon → "Use demo pass" → Validate → checked in; validate again →
   "Already checked in". Seeded pass is valid around the current hour.
6. **Capacity:** Open Play shows 13/16 and a full 12/12 session.
7. **Hold expiry:** a pending booking's countdown runs; `expireStaleHolds` frees the slot and
   marks the booking expired. Slots also treat lapsed holds as available independently.

### Known Phase 1 limitations

- All state is in memory; restarting the app resets data.
- No real auth, no Firestore, no Cloud Functions, no push notifications.
- E-wallet screenshot upload is a reference-number field only.
- QR tokens are unsigned demo strings; scanner is manual-entry (no camera).
- Brightness boost, offline roster cache and FCM are not implemented.
- `online` verification is a client-side demo action; it must move server-side in Phase 2.

### Verification

```bash
flutter analyze   # no issues
flutter test      # 23 tests pass
flutter run -d chrome
```

The booking-flow test drives the real app: discovery → storefront → Reserve → guest auth gate →
demo sign-in → resumed confirmation → simulated online payment → QR pass. Slots that already
started are rendered as `Past` and cannot be reserved.

### Phase 2 delivered (2026-11-28)

**Backend**

```
functions/
├── src/
│   ├── reserveSlot.ts          # atomic slot hold + server-computed total
│   ├── releaseExpiredHolds.ts  # scheduled hold sweeper
│   ├── payments.ts             # completeMockPayment, proof, approve/reject, check-in
│   ├── bookingOps.ts           # slot ownership + hold transitions
│   ├── domain.ts               # Manila time, hold windows, money
│   ├── staff.ts / validation.ts
│   └── index.ts
├── package.json / tsconfig.json
firestore.rules                 # public reads, staff writes, no client booking/slot writes
storage.rules                   # e-wallet proof uploads (owner) + staff reads
firestore.indexes.json          # collection-group booking/slot/open-play indexes
tools/seed/seed.mjs             # Auth + Firestore emulator seed (player + staff)
```

**Flutter**

```
lib/core/config/app_config.dart          # USE_FIREBASE / USE_EMULATORS flags
lib/core/firebase/firebase_bootstrap.dart# Auth/Firestore/Functions emulators
lib/services/auth_service.dart           # email/password + users/{uid} bootstrap
lib/services/firestore_paths.dart
lib/services/venue_repository.dart       # venues, courts, synthesized free slots
lib/services/booking_repository.dart     # player/staff streams + callable wrappers
lib/services/open_play_repository.dart
lib/services/functions_service.dart
lib/providers/backend_providers.dart     # auth controller, repositories, auth readiness
```

`Venue`, `Court`, `Slot`, `Booking`, `OpenPlaySession` and `AppUser` now have Firestore
`fromMap` mappers. The auth screen and profile use `AuthController`, which delegates to the
demo store by default and to Firebase Auth when `USE_FIREBASE=true`.

**Run the backend locally**

```bash
# Requires JDK 17+ for the Auth/Firestore emulators
firebase emulators:start --only auth,firestore,functions,storage

cd tools/seed && npm install && npm run seed
cd functions && npm install && npm run build && npm test

flutter run -d chrome --dart-define=USE_FIREBASE=true
```

Demo remains the default (`USE_FIREBASE=false`) so the app still runs with no emulator. In
Firebase mode the Firebase session is mirrored into `DemoStore`; venue/slot/booking screens
still read demo data until Phase 3.

**Phase 2 limitations**

- No Java/JDK on this machine, so the emulators, rules and callables were compiled/tested but
  not exercised end-to-end. `npm run build` and the domain tests pass.
- Screens are not yet migrated to the Firestore repositories; that is the Phase 3 stream work.
- `completeMockPayment` leaves `qrToken` null; signed QR issuance remains Phase 4.
- E-wallet proof upload is still reference-only (`submitPaymentProof` accepts an optional path).
- Open-play joining is still client/demo logic; the capacity callable lands with Phase 3.

### Verification (current)

```bash
flutter analyze                 # no issues
flutter test                    # 28 tests pass
flutter build web --release     # succeeds
cd functions && npm test        # 6 domain tests pass
firebase emulators:start --only functions
# loaded reserveSlot, completeMockPayment, submitPaymentProof,
# approvePayment, rejectPayment, verifyAndCheckIn, releaseExpiredHolds
```

---

## 2. Next Build Order

### Phase 2 — Architecture, auth, security (Days 3–4) — started

- [x] Firebase Auth (email/password), auth state provider, user doc bootstrap.
- [x] Firestore repositories for venues, courts, slots, bookings and open play.
- [x] `firestore.rules` / `storage.rules` per context §4; emulator config + seed script.
- [x] Cloud Functions project (TypeScript) with `reserveSlot`, `releaseExpiredHolds`,
      `submitPaymentProof`, `approvePayment`, `rejectPayment`, `verifyAndCheckIn`,
      `completeMockPayment` (replaces gateway checkout).
- [x] Keep `online` verification server-side; no client writes to payment/QR fields.
- [x] Move the demo seed into `tools/seed/` (Admin SDK; refuses live projects by default).
- [ ] Migrate screens from `DemoStore` to repository streams (moved to Phase 3).
- [ ] Run the emulator suite, rules tests and concurrent `reserveSlot` tests (needs JDK).

### Phase 3 — Firestore UI + payments (simplified) + open play (Days 8–10)

- [ ] Wire real booking/slot streams and hold countdowns to Firestore.
- [ ] Flip `USE_FIREBASE` to the default once the streams replace `DemoStore`.
- [ ] E-wallet proof upload (`image_picker` → Storage `paymentProofs/{facilityId}/{bookingId}`).
- [ ] Staff queue actions through callables; reject resets a fresh 15-minute hold.
- [ ] Open-play join transaction with `maxCapacity`; roster management.
- [ ] FCM + `flutter_local_notifications` for confirmations, review, expiry, roster updates.

### Phase 4 — QR + offline (Days 11–13)

- [ ] `qrToken.ts`: Ed25519 sign `{bookingId, facilityId, nbf, exp, nonce}`; private key in
      Secret Manager; issue on verification.
- [ ] Bundle the public key; replace `DemoQrPayload` with offline signature verification.
- [ ] `mobile_scanner` camera + reticle + torch + lifecycle handling.
- [ ] Check-in writes `venues/{facilityId}/checkIns/{bookingId}_{deviceId}`; trigger picks the
      earliest `scannedAt` and flags conflicts; Firestore offline persistence for the roster.
- [ ] `screen_brightness` boost on the pass screen.

### Phase 5 — Testing & pilot (Days 14–16)

- [ ] Unit tests: hold windows, slot keys, QR verify, expired-hold availability.
- [ ] Emulator tests: concurrent `reserveSlot`, reject → new hold, duplicate scans.
- [ ] Execute TC-01 … TC-11 (TC-08…11 first time); re-run TC-05/06 against the new flow.
- [ ] Device tests: QR lighting, offline sync, push foreground/background.
- [ ] Seed the pilot club, deploy rules/functions/indexes.

---

## 3. Definition of Done (per pillar)

**Pillar 1** — Guests browse and pick a slot without logging in; confirming redirects to auth
and resumes; two devices racing one slot produce exactly one success; a lapsed hold is
re-reservable without the cleanup job.

**Pillar 2** — A session never exceeds `maxCapacity` under concurrent joins; roster streams
live; full sessions disable joining.

**Pillar 3** — Verified passes are server-issued, offline-verifiable, single-use; forged,
out-of-window and duplicate scans are rejected with no write; cash check-in works without QR.

---

## 4. Non-Negotiables

1. Client never writes slots or booking status/payment/QR fields — callables only.
2. Secrets only in Secret Manager / Functions config (once functions exist).
3. Expired holds are treated as available inside the transaction itself.
4. Payment success is decided by the server (mock callable now, gateway later), never by a
   return deep link.
5. All time math is server-side `Asia/Manila`.
6. No unspecified features (cancellation/refund, staff-created bookings, dynamic pricing,
   recurring bookings, waitlist, open-play payments).

---

## 5. Open Decisions

1. **Auth methods:** email/password is implemented; add Google sign-in for players?
2. **Seeding:** Admin SDK script chosen (`tools/seed`); pilot club still needs a curated seed.
3. **Public key distribution:** bundled asset vs Firestore config doc (bundling is simplest
   offline but requires an app update on key rotation).
4. **Open-play payments:** still out of scope unless requested.

---

## 6. Suggested Next Commits

1. `feat: phase 1 demo UI (discovery, storefront, passes, staff, scanner)` (done)
2. `chore: firebase auth + firestore repositories behind existing providers` (done)
3. `feat: rules + emulator + seed script` (done)
4. `feat: reserveSlot + releaseExpiredHolds + completeMockPayment` (done)
5. `feat: e-wallet proof upload + staff review callables` (backend done, upload UI pending)
6. `feat: migrate screens to Firestore streams` (Phase 3)
7. `feat: open play capacity transaction + notifications`
8. `feat: signed QR + scanner + offline check-in`
9. `test: TC-01…TC-11`
