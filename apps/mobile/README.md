# Voffer mobile app

Flutter app where firms publish offers and customers reserve them, then pay
and redeem at the firm with a six-character code.

- **Customers** see live offers near them (or near a city they pick) sorted by
  distance, search and filter by category, open a shop's profile, buy one or
  more units and see their orders and codes.
- **Firms** set up a shop (address, map pin, hours, phone) on first sign-in,
  publish offers (price, usual price, stock, start and expiry, photo), pause
  them, and mark customer orders as redeemed.

## Run it

```sh
flutter pub get
flutter run                     # demo mode, in-memory data
```

Demo accounts (password `demo1234`): `customer@demo.voffer`,
`cafe@demo.voffer`, `store@demo.voffer`. The demo shops are in Kochi, so pick
Kochi from the location chip if your device is elsewhere.

## Photos

- Firms take or choose a photo for each offer and a logo for their shop.
  `image_picker` resizes to 1280 px and re-encodes as JPEG on the device.
- Uploads go to the public `voffer-images` Storage bucket under the firm's
  user id; the bucket policy stops anyone writing outside their own folder
  and caps files at 1 MB.
- Demo mode keeps photos in memory as `data:` URIs, so no server is needed.

## Redeeming orders

- Each order has a short code and a QR code (`voffer:order:<code>`) that the
  customer opens from My orders and shows at the counter.
- The shop taps the scanner icon, or "Scan to redeem" on Orders, and scans it
  with `mobile_scanner`, or types the code.
- `redeem_order` marks the order fulfilled only at the shop that sold it, and
  only once. Firms can no longer change order status directly.

## Follows and alerts

- Customers tap Follow on a shop's page. When that shop publishes, a database
  trigger adds an alert for each follower, shown in the Alerts tab with an
  unread badge. A scheduled offer's alert appears when the offer starts.
- Firms see their follower count on My offers.
- Android phones also get a push notification for each alert, through
  Firebase project `voffer-185f0` (`lib/firebase_options.dart`). iOS push
  needs the iOS app added to that Firebase project first.

### Turning on push in Supabase

1. In the Firebase console, Project settings > Service accounts > Generate new
   private key.
2. `supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat key.json)"`, then
   `supabase functions deploy push-alerts`.
3. Store `project_url` and `service_role_key` in Vault and run
   `supabase/push_cron.sql` once. It calls the function every minute.

## India and USA

- Each shop picks India or USA. Its offers and orders carry its currency
  (INR or USD), set by the database.
- The city list covers both countries, and the feed uses miles and US cities
  first when the device's region is the USA.

## Location and maps

- Device location comes from `geolocator`. If the customer refuses, the feed
  shows offers from everywhere and asks them to pick a city.
- Nearby search runs in the database (`offers_nearby` RPC, PostGIS), so the
  app only receives offers inside the chosen radius.
- Maps use OpenStreetMap tiles through `flutter_map`, so no API key is needed.
  OSM's [tile usage policy](https://operations.osmfoundation.org/policies/tiles/)
  doesn't allow heavy app traffic; switch `urlTemplate` in
  `lib/widgets/shop_map.dart` to a hosted provider (MapTiler, Stadia, etc.)
  before a wide launch.
- The app asks for location permission, so the Play Console data safety form
  must declare approximate and precise location, used for app functionality.

To use a real backend, apply `supabase/migrations` (repo root) to a Supabase
project and pass its keys:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

Prices show in each shop's currency: rupees for shops in India, dollars in
the USA. Distances show in miles when the device's region is the USA.

## Code layout

| Path | What |
| --- | --- |
| `lib/data/voffer_repository.dart` | Backend interface |
| `lib/data/mock_repository.dart` | In-memory demo backend, used in tests |
| `lib/data/supabase_repository.dart` | Supabase backend |
| `lib/screens/customer/` | Feed, offer detail, my orders |
| `lib/screens/firm/` | Firm dashboard, new-offer form, redeem screen |
| `lib/scanning/` | QR scanner (camera, or none in tests) |
| `lib/screens/shop/` | Shop setup form and the customer-facing shop profile |
| `lib/location/` | Device location, with fakes for tests |
| `lib/photos/` | Camera and gallery picker, with fakes for tests |
| `lib/widgets/shop_map.dart` | Map pin picker and shop map |

## Checks

```sh
dart format lib test && flutter analyze && flutter test
```

Releasing to Google Play is covered in [RELEASE.md](RELEASE.md).
