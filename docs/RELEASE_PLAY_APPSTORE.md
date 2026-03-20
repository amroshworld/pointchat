# Google Play & App Store release checklist

## Google Play (Android)

1. **Play Console** — Create the app listing, privacy policy URL, content rating, and target audience.
2. **Signing** — Use an upload key; Play App Signing holds the app signing key.
3. **Local release build** — Copy `android/key.properties.example` to `android/key.properties` and point `storeFile` at your keystore.
4. **CI** — Workflow: `.github/workflows/android-release.yml`  
   Add repository **Secrets**:
   - `ANDROID_KEYSTORE_BASE64` — `base64 -w0 upload-keystore.jks` (Linux) or `certutil -encode` (Windows) output without headers, or use GitHub UI to store raw base64.
   - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`
   - `REVENUECAT_ANDROID_API_KEY`, `REVENUECAT_IOS_API_KEY` (if used in `pubspec` / defines)
5. Run **Actions → Android Release (AAB)** or push a tag `v1.0.0`.
6. Download the **artifact** `.aab` and upload in Play Console (Testing → Internal testing first).

## App Store (iOS)

1. **Apple Developer** — App ID, certificates, App Store Connect app record.
2. **Provisioning** — Distribution profile for your bundle ID (`com.amrosh.Pointchat` or as configured in Xcode).
3. **CI** — Workflow: `.github/workflows/ios-build.yml` (triggers on `main` / `master`).  
   Secrets (names already referenced in the workflow):
   - `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_P12_PASSWORD`
   - `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_PROVISIONING_PROFILE_NAME`
   - `IOS_TEAM_ID`, `IOS_BUNDLE_ID`
   - For TestFlight upload: `APPSTORE_API_KEY_BASE64`, `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`
4. **Manual dispatch** — Enable signed build + optional TestFlight upload.

## App tips & AI context

Edit `assets/pointchat_tips.json`:

- `rotating_tips` — Shown in the composer (cycles like CLI hints).
- `ai_knowledge` — Appended to AI system prompts so `@bot` / bots stay aligned with real features.

Run `flutter pub get` after asset changes.

## Version bumps

Update `pubspec.yaml` `version: x.y.z+build` before store submissions.
