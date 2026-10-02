# Releasing to Google Play

Application ID: `com.voffer.voffer` (permanent once published).

The **Mobile app** GitHub Actions workflow builds a release App Bundle on
every PR and push to `main` and stores it as a run artifact. Run it manually
(Actions → Mobile app → Run workflow) and pick a Play track to upload it.

## 1. Create the upload key (once, on your own machine)

```sh
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Back up the file and both passwords somewhere safe. Google Play App Signing
holds the real app signing key; this is only the upload key, and Google can
reset it if it is lost.

## 2. Add repository secrets

Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `VOFFER_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `VOFFER_KEYSTORE_PASSWORD` | keystore password |
| `VOFFER_KEY_ALIAS` | `upload` |
| `VOFFER_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | service account JSON key (step 4) |

Variables (not secrets, the publishable key is public): `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY`. Without them the build ships demo mode.

## 3. First release in the Play Console (manual, once)

1. Create the app in the Play Console with package `com.voffer.voffer`.
2. Download the signed `app-release.aab` from a workflow run and upload it
   by hand to the **Internal testing** track. The Play API cannot create
   the first release, so this one is always manual.
3. Fill in the store listing, content rating, target audience, data safety
   form and a privacy policy URL (the app collects email, name and order
   history).
4. Personal developer accounts created after November 2023 must run a
   closed test with at least 12 testers for 14 days before production.

## 4. Automated uploads

1. In Google Cloud, create a service account and a JSON key for it.
2. In the Play Console, Users and permissions → invite the service account
   email and grant it release permissions for Voffer.
3. Save the JSON as `PLAY_SERVICE_ACCOUNT_JSON`, then run the workflow with
   a track. `draft` leaves the release for you to roll out in the Console.

## Building locally

Create `android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

then `flutter build appbundle --release`. Bump `version` in `pubspec.yaml`
for user-visible version names; CI sets the version code from the run number.
