# PointChat Store Signing Keys & Deployment Assets

This directory contains all store keys, certificates, API tokens, and credentials for automated and manual releases to both **Google Play Console** and **Apple App Store Connect / TestFlight**.

---

## 🤖 Google Play Console (Android)

| File | Purpose | Notes |
| :--- | :--- | :--- |
| [`upload-keystore.jks`](file:///Users/amrosh/antigravity/pointchat/signing/upload-keystore.jks) | Android release keystore | Used to sign Android App Bundles (`.aab`) and APKs |
| [`key.properties`](file:///Users/amrosh/antigravity/pointchat/signing/key.properties) | Keystore configuration | Contains `keyAlias`, `storePassword`, and `keyPassword` |
| [`google-play-api-key.json`](file:///Users/amrosh/antigravity/pointchat/signing/google-play-api-key.json) | Google Play Console API Key | Service Account key for publishing to Internal/Beta/Production tracks |

Also mirrored at:
- `android/upload-keystore.jks` & `android/key.properties` (used directly by Gradle)
- `android/google-play-api-key.json` & `fastlane/google-play-api-key.json` (used by Fastlane)

---

## 🍏 Apple App Store / TestFlight (iOS)

| File | Purpose | Notes |
| :--- | :--- | :--- |
| [`AuthKey_J34F5SH629.p8`](file:///Users/amrosh/antigravity/pointchat/signing/AuthKey_J34F5SH629.p8) | App Store Connect API Key | Bypasses 2FA / SMS for Fastlane & CI deployments |
| [`certificate.p12`](file:///Users/amrosh/antigravity/pointchat/signing/certificate.p12) | Apple Distribution Identity | Contains Apple Distribution certificate and private key |
| [`PointChat_AppStore.mobileprovision`](file:///Users/amrosh/antigravity/pointchat/signing/PointChat_AppStore.mobileprovision) | App Store Provisioning Profile | Target Bundle ID: `com.amrosh.Pointchat` |
| [`credentials.env`](file:///Users/amrosh/antigravity/pointchat/signing/credentials.env) | Deployment Environment Variables | Key IDs, Team IDs, and Issuer IDs |

Also mirrored at:
- `ios/ci/AuthKey.p8`
- `ios/ci/certificate.p12`
- `ios/ci/profile.mobileprovision`
- `ios/ci/signing.env`
