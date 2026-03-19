# pointchat

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS Build Automation (From Windows)

This repo now includes `.github/workflows/ios-build.yml` so iOS builds run on GitHub's macOS runners.

### What it does

- Push/PR to `main`: builds an unsigned iOS app bundle artifact (`Runner.app.zip`).
- Manual run (`workflow_dispatch`): can build a signed `.ipa` if signing secrets are configured.

### Required GitHub Secrets for signed IPA

Add these in `GitHub -> Settings -> Secrets and variables -> Actions`:

- `IOS_CERTIFICATE_P12_BASE64`: Base64 of your Apple distribution certificate `.p12`.
- `IOS_CERTIFICATE_P12_PASSWORD`: Password used when exporting the `.p12`.
- `IOS_PROVISIONING_PROFILE_BASE64`: Base64 of your `.mobileprovision` profile.
- `IOS_TEAM_ID`: Your Apple Developer Team ID.
- `IOS_BUNDLE_ID`: App bundle id, currently `com.amrosh.Pointchat`.
- `IOS_PROVISIONING_PROFILE_NAME`: Provisioning profile display name (exactly as in Apple Developer portal).

Optional (for Flutter dart-defines during CI):

- `REVENUECAT_ANDROID_API_KEY`
- `REVENUECAT_IOS_API_KEY`

### How to run a signed build

1. Open `Actions` tab in GitHub.
2. Select `iOS Build` workflow.
3. Click `Run workflow`.
4. Set `signed_build` to `true`.
5. Choose `export_method` (`app-store`, `ad-hoc`, or `development`).
6. Optional: set `upload_testflight` to `true` to push directly to TestFlight.
7. Run and download artifact `ios-signed-ipa` when complete.

### Additional secrets for TestFlight upload (optional)

- `APPSTORE_API_KEY_BASE64`: Base64 content of App Store Connect API key `.p8`.
- `APPSTORE_KEY_ID`: App Store Connect API key ID.
- `APPSTORE_ISSUER_ID`: App Store Connect issuer ID.

### Base64 helper commands

macOS/Linux:

```bash
base64 -i cert.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```

PowerShell (Windows):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision"))
```
