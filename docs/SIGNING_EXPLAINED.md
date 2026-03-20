# What “signed build” means (saved for later)

## Plain language

When you install an app on a **phone**, the OS wants to know **who built it** and that the app **was not tampered with** after that. **Signing** is the cryptographic stamp that proves that.

- **Unsigned build** — Good for **testing on a simulator** or quick CI checks. You **cannot** ship this to the real App Store / Play Store as-is.
- **Signed build** — The app is stamped with **your** developer key (Apple or Google). Stores and users’ devices **trust** that stamp.

## Android (Google Play)

- You create an **upload keystore** (a file + passwords).
- **Release** builds are signed with that key before you upload an **AAB** or **APK**.
- Google may use **Play App Signing** so Google holds the final “store” key; you still sign the **upload** with your key.

## iOS (App Store / TestFlight)

- Apple issues **certificates** tied to your **Apple Developer** account.
- A **provisioning profile** ties your app ID + certificate + devices (or App Store distribution).
- **Xcode** or **CI** uses the certificate + profile to produce a **signed IPA** you can upload to App Store Connect.

## “Signed build” in GitHub Actions

In **iOS Build** workflow, **Signed IPA** means: the workflow uses secrets you stored in GitHub (`IOS_CERTIFICATE_P12_BASE64`, profile, etc.) to run `flutter build ipa` so the output **can** go to TestFlight/App Store.

**Mobile Release** builds **unsigned** iOS on purpose (no Apple secrets needed) so you always get a check that the project compiles; for store upload, use the **signed** path when your certificates are ready.

## What you should save for future updates

1. **Android:** Backup `upload-keystore.jks` and passwords in a **password manager** (and/or GitHub Secrets for CI). Losing them makes updates painful.
2. **iOS:** Keep **certificates and profiles** renewed in Apple Developer; store **App Store Connect API key** for CI uploads if you use it.

See also: **[RELEASE_PLAY_APPSTORE.md](RELEASE_PLAY_APPSTORE.md)** for secret names and steps.
