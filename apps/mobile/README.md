# Voffer mobile app

Flutter app where firms publish offers and customers reserve them, then pay
and redeem at the firm with a six-character code.

- **Customers** browse and search live offers, filter by category, buy one or
  more units and see their orders and codes.
- **Firms** publish offers (price, usual price, stock, expiry, image), pause
  them, and mark customer orders as redeemed.

## Run it

```sh
flutter pub get
flutter run                     # demo mode, in-memory data
```

Demo accounts (password `demo1234`): `customer@demo.voffer`,
`cafe@demo.voffer`, `store@demo.voffer`.

To use a real backend, apply `supabase/migrations` (repo root) to a Supabase
project and pass its keys:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

`CURRENCY` (default `INR`) sets the currency shown.

## Code layout

| Path | What |
| --- | --- |
| `lib/data/voffer_repository.dart` | Backend interface |
| `lib/data/mock_repository.dart` | In-memory demo backend, used in tests |
| `lib/data/supabase_repository.dart` | Supabase backend |
| `lib/screens/customer/` | Feed, offer detail, my orders |
| `lib/screens/firm/` | Firm dashboard and new-offer form |

## Checks

```sh
dart format lib test && flutter analyze && flutter test
```

Releasing to Google Play is covered in [RELEASE.md](RELEASE.md).
