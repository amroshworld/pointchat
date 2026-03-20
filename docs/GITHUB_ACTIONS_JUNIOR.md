# GitHub Actions — simple guide

**What it is:** When you push code to GitHub, **Actions** can run scripts on GitHub’s computers (build your app, run tests). You define those scripts in **YAML files** under `.github/workflows/`.

## How you use it (day to day)

1. Open your repo on **github.com**.
2. Click the **Actions** tab.
3. In the left list, pick a workflow (e.g. **Android Release (AAB)** or **iOS Build**).
4. Click **Run workflow** (if it says *workflow_dispatch*) and confirm.
5. Wait for the green check or red X. Open the run to see **logs** if something failed.
6. If the workflow **uploads artifacts**, open the run → scroll to **Artifacts** → download the `.aab` or `.ipa`.

**Tags:** Some workflows also run when you push a **git tag** like `v1.0.0`:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Secrets (passwords / keys)

Workflows must **not** hard-code passwords. In the repo: **Settings → Secrets and variables → Actions → New repository secret**.

Your project expects names such as `ANDROID_KEYSTORE_BASE64`, `IOS_CERTIFICATE_P12_BASE64`, etc. — see `docs/RELEASE_PLAY_APPSTORE.md`.

## What’s already in this repo

| File | Purpose |
|------|--------|
| `.github/workflows/android-release.yml` | Build signed Android **AAB** for Play Store |
| `.github/workflows/ios-build.yml` | Build iOS (unsigned always; signed IPA when you configure secrets) |

If a workflow fails, read the **red error lines** in the log; often it’s a missing secret or wrong branch name.
