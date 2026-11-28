# CourtFlow — Engineering & Product Agent Context (AGENT_CONTEXT.md)

> **AMENDMENT 2026-11-26 — Phase 1 scope change (approved):** no hosted payment gateway.
> `online` payments use a simulated success (demo only). The gateway, webhook, `/pay/return`
> deep link, `createCheckout` and Secret Manager payment keys described below are deferred.
> E-wallet review and pay-at-desk flows are unchanged. Server-authoritative writes remain the
> target once Cloud Functions exist. See `foragent/plan.md` for the revised build order.

Source of truth for scope: `CourtFlow_Chapters_1_and_2_Final-v7.docx`. If this file and the doc disagree, flag it instead of guessing.

## 1. Project Identity & B2B2C Business Model

**Application Name:** CourtFlow

**Platform & Stack:** Cross-platform mobile app built with Flutter (Dart) for iOS and Android, backed by Firebase (`cloud_firestore`, `firebase_auth`, `firebase_messaging`, `firebase_storage`) plus **Cloud Functions** (Blaze plan) for all server-side logic. A hosted payment gateway (PayMongo, or Xendit as the alternative) handles online payments. Supabase equivalents (Edge Functions) are acceptable only if the whole backend is switched.

**Architecture & Business Model:** Multi-tenant B2B2C platform for pickleball facilities and players.

- **B2B (Facility Owners & Managers):** Tiered SaaS subscription scaled by court count (plus one-time onboarding fee and optional per-booking convenience fee). Each club gets a dedicated branded Club Storefront (`venues/{facilityId}`), shareable deep link / QR poster entry (`courtflow.app/club/{facilityId}`), optional public directory listing, and a Staff Control Center.
- **B2C (Recreational & Competitive Players):** Free unified player experience supporting guest browsing without an upfront login wall, club discovery, direct club portal access, private court reservations, capacity-capped open-play sessions, and a unified My Passes digital QR wallet across all visited clubs.

**Resource & Timeline Constraints:** ₱50,000 initial budget allocation; 16-day build and venue pilot validation (Days 1–16, Weeks 1–3). Build order:

| Phase | Days | Work |
|---|---|---|
| 1. Planning & UI/UX | 1–2 | Requirements, roles, payment flows, Firestore schema (slot docs with `holdExpiresAt`), wireframes |
| 2. Core architecture & auth | 3–4 | Flutter + Riverpod + go_router role guards, Firebase Auth, Cloud Functions setup, security rules, models |
| 3. Discovery, booking, payments, open play | 5–10 | Discovery/storefront/slot list (5–6), auth gate + server-side slot locking with hold expiry (6–7), gateway checkout + webhook + proof upload + hold-expiry scheduler (8–9), open play (9–10) |
| 4. Staff, QR, offline | 11–13 | Staff Control Center + For Review queue (11), signed QR pass + scanner with offline signature validation (12–13), FCM + offline roster (13) |
| 5. Testing & pilot | 14–16 | Unit, concurrency, hold-expiry, webhook, QR lighting/offline tests (14–15); venue pilot, fixes, deployment (15–16) |

## 2. Hard Rules (read before writing any code)

1. **The client never decides reservation or payment outcomes.** Slot locks, booking status changes, payment verification, QR token issuance, and check-in status are written only by Cloud Functions (Admin SDK). Firestore rules deny client writes to `slots`, and to `bookings` status/payment/QR fields.
2. **The gateway secret, webhook secret, and QR signing private key live only in Secret Manager / Functions config.** Never in the app, Firestore, or the repo.
3. **A lapsed hold counts as available.** Every slot-locking transaction treats a `held` slot with `holdExpiresAt < now` as free. Correctness must never depend on the cleanup job running on time.
4. **Never trust the payment return deep link.** Payment is confirmed only by the signature-verified webhook. The app reads booking status from the Firestore stream.
5. **Slot dates/hours are venue-local time (Asia/Manila).** Compute `holdExpiresAt` and QR validity windows on the server.
6. **Do not build unspecified features.** Not yet in scope (ask first): cancellation/refund/reschedule policy, staff-created bookings (phone-ins/walk-ins), peak/off-peak pricing, recurring bookings, waitlist, open-play payments/QR.

## 3. Three Core Functional Pillars (Strict Scope)

### Pillar 1: Club Discovery & Conflict-Free Court Reservation Engine

**Player Discovery & Guest Browsing**
- App launches directly into `ClubDiscoveryScreen` in guest mode (no upfront auth barrier).
- Players search participating clubs (`publicDirectoryVisible == true`) by name or location via `ClubSummaryCard` widgets, or jump directly into a club's branded `ClubStorefrontScreen` via deep link / QR code.

**Vertical Single-Axis Schedule UI (No 2D Grid Panning on Mobile)**
- Inside `ClubStorefrontScreen`, players use a `CustomScrollView` with a pinned horizontal date strip, `ChoiceChip` court filters (All Courts, Court 1..Court N), and a vertical `ListView.builder` of `AnimatedContainer` hourly slot cards (**Available, Pending Payment with live countdown, Reserved**).
- Slot cards stream from `venues/{facilityId}/courts/{courtId}/slots`. Guests can read slots, so slot docs contain no personal data.

**Checkout Auth Gate & Payment Method**
- Tapping an Available slot opens a `showModalBottomSheet` (`BookingConfirmationSheet`) showing club name, court, date/time, fee breakdown, and a **payment method selector**: **Pay Online** (GCash / Maya / card), **E-Wallet Transfer**, or **Pay at Desk**. The hold duration for the chosen method is shown before confirming.
- **Auth Gate:** If the user is unauthenticated (guest), tapping Confirm Reservation redirects to `AuthScreen` (Login / Quick Sign-Up) and automatically resumes the pending booking confirmation upon sign-in.

**Server-Side Atomic Slot Locking with Expiring Holds**
- Confirm Reservation calls the callable Cloud Function `reserveSlot` (never writes slots/bookings directly).
- `reserveSlot` runs a Firestore transaction (Admin SDK) over the deterministic slot docs `venues/{facilityId}/courts/{courtId}/slots/{date}_{startHour}` (e.g. `2026-11-27_18`). Multi-hour bookings lock **every** overlapping slot doc in the same transaction. If any slot is `reserved`, or `held` and not yet expired, the whole request is rejected with a conflict error and the client shows the slot-taken prompt.
- On success it writes the slot docs (`status: "held"`, `bookingId`, `holdExpiresAt`) and the booking (`status: "pending_payment"`, `paymentMethod`, `holdExpiresAt`).
- **Hold windows:** 15 minutes for `online` and `ewallet`. For `cash`, the venue's `cashHoldMinutes` (default 120), capped at the slot start time.
- Scheduled function `releaseExpiredHolds` (every minute) cancels expired `pending_payment` bookings (`status: "expired"`), frees their slot docs, and notifies the player. This is cleanup only (see Hard Rule 3).

### Pillar 2: Capacity-Controlled Open-Play Management & Automated Alerts

**Live Participant Caps**
- Facility managers/organizers publish open-play blocks under `venues/{facilityId}/openPlaySessions` with a strict `maxCapacity` cap and skill-tier tags.
- Bound via Riverpod `StreamProvider` / `StreamBuilder` with `LinearProgressIndicator` fill bars and `FilterChip` / `Badge` status indicators.
- Joining executes a Firestore transaction incrementing `currentCount`; once `currentCount >= maxCapacity`, the session locks as Full and disables registration.

**Organizer Roster & Automated Notifications**
- Organizers view live participant rosters and manage entries (including `Dismissible` list tiles for rapid adjustments).
- `firebase_messaging` + `flutter_local_notifications` deliver foreground and background push/in-app alerts for booking confirmations, payment verifications, hold expiry, open-play roster updates, and schedule changes. Pushes are triggered by Cloud Functions.

### Pillar 3: Payment-Linked QR Pass & Staff Check-In Control

Verification is matched to the payment method:

| Path | Player action | Verification | Result |
|---|---|---|---|
| **Online** | Callable `createCheckout(bookingId)` returns a hosted checkout URL (opened with `url_launcher`); return via go_router deep link | Gateway webhook `paymentWebhook` verifies the signature header against the webhook secret, then marks the booking `verified` (`verifiedBy: "gateway"`) | QR pass issued automatically, push sent, **no staff action** |
| **E-wallet transfer** | Sends transfer, then submits reference number + screenshot (`image_picker` → Storage `proofs/{facilityId}/{bookingId}`) via callable `submitPaymentProof` | Booking moves to `payment_review` (hold expiry paused). Staff compare against the facility's e-wallet record in the **For Review** queue and call `approvePayment` or `rejectPayment` | Approve: `verified` + QR pass issued. Reject: back to `pending_payment` with a fresh 15-minute hold, player notified |
| **Cash (pay at desk)** | Pays on arrival | Staff tap **Verify & Check In** (callable `verifyAndCheckIn`) | Booking goes straight to `checked_in` (`verifiedBy`, `checkedInAt` set). **No QR, no scan** |

Gateway amounts come from the booking's `totalFee` on the server, never from the client.

**Role-Guarded Staff Control Center (`StaffControlCenterScreen`)**
- Accessible via the Club / Staff Portal login option on `AuthScreen` and guarded by go_router role checks scoped to the staff member's assigned `facilityId`.
- Features a daily court utilization summary, `PageView` snapped multi-court schedule overview, `SegmentedButton` filters (**All, Unpaid, For Review, Verified, Checked In**).
- **For Review** rows show the reference number and proof screenshot with Approve / Reject. Cash rows show **Verify & Check In**. Online payments appear as Verified automatically.

**Payment-Gated, Signed QR Pass (`MyPassesScreen`)**
- Unpaid bookings show a locked placeholder with the remaining hold time and **Pay Now** / **Upload Proof** actions. Pay-at-desk bookings show a "Present at Front Desk" card instead of a QR pass.
- Verified pre-paid bookings show a QR pass rendered with `qr_flutter` (`QrImageView`) inside a high-contrast `Card` (Hero transition from booking receipt).
- **`qrToken` is a server-signed token** (`base64url(payload).base64url(signature)`, Ed25519 or ECDSA). Payload: `bookingId`, `facilityId`, `nbf` (slot start − 30 min), `exp` (slot end), `nonce`. Signed by a Cloud Function with the private key in Secret Manager. The matching **public key** ships to staff devices for offline verification.
- Opening a verified pass boosts display luminance using `screen_brightness`.

**Optical QR Check-In & Offline Roster Persistence (`QrScannerScreen`)**
- Uses `mobile_scanner` (`MobileScanner`) with a `CustomPaint` corner reticle overlay, flashlight toggle, and `WidgetsBindingObserver` lifecycle hooks (pausing/disposing the camera stream when leaving the tab).
- Each scan is validated on-device: (1) signature against the cached public key, (2) `facilityId` matches the staff member's club, (3) current time inside `nbf`..`exp`, (4) booking in the cached roster is `verified` and not already `checked_in`. Banners: valid, unverified payment, invalid signature, outside validity window, Already Checked In.
- The daily roster of verified bookings is kept by Firestore offline persistence; the public key is bundled/cached.
- **Check-in writes:** staff devices create `venues/{facilityId}/checkIns/{bookingId}_{deviceId}` (`scannedAt`, `deviceId`, `staffId`) through the Firestore SDK so writes queue offline. Trigger function `onCheckInCreated` sets the booking to `checked_in` with the **earliest** `scannedAt` across devices and flags any conflicting scans for review.

## 4. Multi-Tenant Firestore Data Model (`venues/{facilityId}`)

Design all collections from Day 1 with multi-tenant `facilityId` isolation (seed 1 primary demo club for the pilot so zero refactoring is needed when onboarding additional clubs):

```
users/{uid}
  ├── name: string
  ├── email: string
  ├── role: "player" | "staff" | "owner"
  ├── clubRoles: { "{facilityId}": "owner" | "staff" }   // Scopes staff access per club
  ├── fcmTokens: string[]
  └── createdAt: timestamp

venues/{facilityId}
  ├── name: string
  ├── slug: string                                      // e.g., "davao-pickleball-club"
  ├── location: string
  ├── bannerUrl: string
  ├── rules: string
  ├── announcements: string
  ├── paymentInstructions: string                       // E-wallet account details shown to players
  ├── acceptedPaymentMethods: ("online"|"ewallet"|"cash")[]
  ├── cashHoldMinutes: number                           // default 120, capped at slot start
  ├── operatingHours: { open: "06:00", close: "22:00" }
  ├── publicDirectoryVisible: boolean                   // Controls visibility in Club Discovery
  ├── subscriptionTier: string                          // B2B SaaS tier by court count
  │
  ├── courts/{courtId}
  │     ├── name: string                                // "Court 1", "Court 2"...
  │     ├── hourlyRate: number
  │     ├── isActive: boolean
  │     └── slots/{date}_{startHour}                    // e.g. "2026-11-27_18" — no doc = available
  │           ├── status: "held" | "reserved"
  │           ├── bookingId: string
  │           └── holdExpiresAt: timestamp?             // null once reserved
  │
  ├── bookings/{bookingId}
  │     ├── facilityId: string
  │     ├── courtId: string
  │     ├── courtName: string
  │     ├── playerId: string
  │     ├── playerName: string
  │     ├── date: string                                // "YYYY-MM-DD" (Asia/Manila)
  │     ├── startHour: number                           // e.g., 18 for 6:00 PM
  │     ├── durationHours: number
  │     ├── slotIds: string[]                           // every slot doc locked by this booking
  │     ├── totalFee: number
  │     ├── paymentMethod: "online" | "ewallet" | "cash"
  │     ├── status: "pending_payment" | "payment_review" | "verified" | "checked_in" | "cancelled" | "expired"
  │     ├── holdExpiresAt: timestamp?                   // null while payment_review, verified, checked_in
  │     ├── paymentRef: string?                         // e-wallet reference number
  │     ├── proofPath: string?                          // Storage path of e-wallet screenshot
  │     ├── gatewayPaymentId: string?                   // online payments
  │     ├── paidAt: timestamp?
  │     ├── qrToken: string?                            // server-signed; pre-paid bookings only
  │     ├── verifiedBy: string?                         // staff uid, or "gateway"
  │     ├── checkedInAt: timestamp?
  │     └── createdAt: timestamp
  │
  ├── checkIns/{bookingId}_{deviceId}
  │     ├── bookingId: string
  │     ├── deviceId: string
  │     ├── staffId: string
  │     └── scannedAt: timestamp
  │
  └── openPlaySessions/{sessionId}
        ├── facilityId: string
        ├── title: string
        ├── skillTier: "All Levels" | "Beginner" | "Intermediate" | "Advanced"
        ├── date: string
        ├── timeWindow: string
        ├── entryFee: number
        ├── maxCapacity: number
        ├── currentCount: number
        └── participantIds: string[]
```

`slotKey` from the earlier schema is replaced by `slotIds` plus the deterministic slot doc IDs.

**Security rules summary**
- `slots`: public read, no client writes.
- `bookings`: read by the owning player and by staff/owner of that `facilityId`; no client writes to status, payment, hold, or QR fields (all via callables/webhook).
- `checkIns`: create-only by staff of that `facilityId`.
- Storage `proofs/{facilityId}/{bookingId}`: write by the booking's player, read by that facility's staff.
- `clubRoles` scopes every staff/owner permission to a `facilityId`.

## 5. Recommended Flutter Architecture & Folder Structure

**State Management:** `flutter_riverpod` (`StreamProvider` for real-time courts, slots, open-play sessions, bookings, and passes; `StateProvider` / `NotifierProvider` for `selectedFacilityId`, `selectedDate`, `selectedCourtFilter`, and pending guest checkout intent).

**Routing:** `go_router` with deep-link support (`/club/:facilityId`, payment return `/pay/return`) and redirect guards protecting `/staff/*` routes while keeping `/`, `/club/:facilityId`, and `/open-play` open to guests.

**Folder Layout:**

```
lib/
├── main.dart
├── core/
│   ├── router/app_router.dart              # go_router + guest & staff role guards
│   ├── theme/app_theme.dart                # Evergreen & high-contrast court palette
│   └── utils/
│       ├── brightness_helper.dart          # screen_brightness wrapper for QR passes
│       └── qr_token_verifier.dart          # Offline signature + validity-window check
├── models/
│   ├── venue_model.dart
│   ├── court_model.dart
│   ├── slot_model.dart                     # held/reserved + holdExpiresAt
│   ├── booking_model.dart
│   ├── open_play_model.dart
│   └── app_user_model.dart
├── services/
│   └── functions_service.dart              # Typed wrappers for callable Cloud Functions
├── providers/
│   ├── auth_provider.dart
│   ├── venue_provider.dart                 # Directory stream & active facilityId
│   ├── booking_provider.dart               # Live slot stream + reserveSlot call (no direct writes)
│   ├── payment_provider.dart               # createCheckout, submitPaymentProof, hold countdown
│   ├── open_play_provider.dart             # Live session stream & capacity-capped join
│   └── staff_provider.dart                 # approve/reject/verifyAndCheckIn + check-in queue
└── screens/
    ├── auth/
    │   └── auth_screen.dart                # Checkout auth gate + Club/Staff Portal login
    ├── player/
    │   ├── club_discovery_screen.dart      # Default guest entry + club search
    │   ├── club_storefront_screen.dart     # Branded club page + vertical slot booking + hold countdown
    │   ├── booking_confirmation_sheet.dart # Payment method selector + auth-at-checkout trigger
    │   ├── payment_proof_sheet.dart        # E-wallet reference number + screenshot upload
    │   ├── open_play_screen.dart           # Live capacity bars + 1-tap join/leave
    │   ├── my_passes_screen.dart           # Active/Past passes, locked placeholders, QrImageView + brightness boost
    │   ├── notifications_screen.dart       # Chronological alert feed
    │   └── profile_settings_screen.dart    # Player profile & Owner facility toggles + hold windows
    └── staff/
        ├── staff_control_center_screen.dart # PageView courts + filters + For Review queue + Verify & Check In
        └── qr_scanner_screen.dart          # MobileScanner + CustomPaint reticle + offline signature check

functions/                                   # Cloud Functions (TypeScript)
├── src/index.ts
├── src/reserveSlot.ts                      # Callable: server-side slot-locking transaction
├── src/payments.ts                         # createCheckout, paymentWebhook, submitPaymentProof
├── src/staffActions.ts                     # approvePayment, rejectPayment, verifyAndCheckIn
├── src/qrToken.ts                          # Sign/verify QR tokens (private key from Secret Manager)
├── src/releaseExpiredHolds.ts              # Scheduled, every minute
└── src/onCheckInCreated.ts                 # Firestore trigger: earliest scannedAt wins, flag conflicts
firestore.rules
storage.rules
```

## 6. Verification Checklist (Test Cases TC-01 to TC-11)

- **TC-01 (Guest Browsing & Auth Gate):** Launch unauthenticated → browse `ClubDiscoveryScreen` & `ClubStorefrontScreen` → tap Confirm Reservation → verify redirect to `AuthScreen` and seamless return to booking; verify Staff Portal login routes exclusively to the assigned facility's `StaffControlCenterScreen`.
- **TC-02 (Real-Time Reservation):** Select date/court → tap Available slot → confirm modal → verify slot transitions to Pending Payment (with countdown) in < 1s across active clients.
- **TC-03 (Atomic Peak-Hour Conflict):** Trigger simultaneous Confirm Reservation taps on identical slot across two devices → verify the `reserveSlot` transaction commits the first write and rejects the second with a conflict alert.
- **TC-04 (Open-Play Capacity Cap):** Fill session to `maxCapacity` → verify progress bar reaches 100%, status badge switches to Full, and join button disables for additional players.
- **TC-05 (Payment Verification & QR Unlock):** Approve an e-wallet booking in the For Review queue (Verify Payment) → verify the `QrImageView` pass unlocks on the player's `MyPassesScreen` and push notification fires.
- **TC-06 (Optical QR Scan & Duplicate Block):** Open verified QR pass (verify `screen_brightness` boost) → scan via `MobileScanner` → verify Checked In status → scan same pass again → verify "Already Checked In" duplicate block.
- **TC-07 (Offline Wi-Fi Check-In Sync):** Load daily roster on staff device → disable network → scan valid QR pass against local cache and cached public key → re-enable network and verify automatic timestamp sync.
- **TC-08 (Hold Expiry & Slot Release):** Reserve a slot as Player A with E-Wallet Transfer (test hold = 1 minute), submit no payment → verify live countdown, then booking `expired`, player notified, slot Available on all devices; Player B can reserve it **even if `releaseExpiredHolds` has not yet run**.
- **TC-09 (Online Payment Auto-Verification):** Reserve with Pay Online → pay in gateway test mode → verify booking becomes Verified with no staff action, QR pass unlocks, push fires. Send a webhook with an invalid signature → verify it is rejected and changes nothing.
- **TC-10 (Cash Verify & Check In):** Reserve with Pay at Desk → open in Staff Control Center → tap Verify & Check In → verify `pending_payment` → `checked_in` in one step with no QR scan. If the cash window lapses first, verify the hold is released instead.
- **TC-11 (Forged / Out-of-Window QR):** Scan an altered or externally generated token; scan a valid pass more than 30 minutes before slot start; scan a screenshot of an already-used pass → verify each is rejected (invalid signature / outside window / Already Checked In) and no check-in is logged.

TC-08 to TC-11 are new and unexecuted. TC-05 and TC-06 predate the new flow and should be re-run against it.