# CourtFlow seed

Seeds Auth + Firestore emulators with the demo venues, courts, slots, bookings
and open-play sessions used by the Flutter app.

```bash
cd tools/seed
npm install
npm run seed
```

Start the emulators first:

```bash
firebase emulators:start --only auth,firestore,functions,storage
```

Defaults to `127.0.0.1:9099` (Auth) and `127.0.0.1:8081` (Firestore). The script
refuses to write to a live project unless `ALLOW_PROD_SEED=1` is set.

Seeded accounts:

| Email | Password | Role |
| --- | --- | --- |
| `player@courtflow.demo` | `courtflow123` | player |
| `staff@courtflow.demo` | `courtflow123` | staff at Davao Pickleball Club |

Re-running is safe: fixed document ids are overwritten.
