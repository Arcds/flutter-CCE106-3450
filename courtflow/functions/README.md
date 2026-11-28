# CourtFlow Cloud Functions

Server-side authority for reservations, holds, payments and check-in.

## Local setup

```bash
cd functions
npm install
npm run build
npm test
```

## Emulators

The Firestore and Auth emulators require a Java runtime (JDK 17+). Install it,
then from the repository root:

```bash
firebase emulators:start --only auth,firestore,functions,storage
```

The Flutter app connects to these ports when run with:

```bash
flutter run --dart-define=USE_FIREBASE=true
```

Use `--dart-define=USE_EMULATORS=false` to point at the real project instead.

## Seed data

```bash
cd tools/seed
npm install
npm run seed
```

Demo accounts created by the seed script:

- `player@courtflow.demo` / `courtflow123` (player)
- `staff@courtflow.demo` / `courtflow123` (staff at `davao-pickleball-club`)

## Callables

| Callable | Auth | Purpose |
| --- | --- | --- |
| `reserveSlot` | player | Validates venue/court/slots, computes price and hold, writes booking + slot holds atomically. |
| `completeMockPayment` | booking owner | Simulated online success. Verifies the hold server-side and marks the booking verified. |
| `submitPaymentProof` | booking owner | Moves an e-wallet booking into staff review. |
| `approvePayment` | venue staff | Verifies an e-wallet booking and converts holds to reservations. |
| `rejectPayment` | venue staff | Returns the booking to pending payment with a fresh hold (or expires it). |
| `verifyAndCheckIn` | venue staff | Cash flow: verifies payment and checks the player in. |

`releaseExpiredHolds` is a scheduled function that expires lapsed holds and
frees their slots. Scheduled functions require the Blaze plan when deployed.

## Payment rules

- The client never sends the price, total, hold expiry or booking status.
- `reserveSlot` reads the court hourly rate and recomputes the total.
- Online is a simulated success only for the demo; no payment provider is called.
- E-wallet is reference + staff review; no client-side approval.
- Cash holds the slot until staff use Verify & Check In.

## Deploy

```bash
npm run build
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

Set `QR_PRIVATE_KEY` in Secret Manager before Phase 4 (signed QR passes).
