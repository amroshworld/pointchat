# iOS CI signing files

This workflow is now **repo-first**. If these files exist in `ios/ci/`, GitHub Actions uses them directly and does not need GitHub secrets.

## Preferred files in the repo

Commit these files directly:

- `ios/ci/certificate.p12`
- `ios/ci/profile.mobileprovision`
- `ios/ci/AuthKey.p8`
- `ios/ci/signing.env`

`signing.env` should look like this:

```env
CERTIFICATE_PASSWORD=your-p12-export-password
APP_STORE_CONNECT_KEY_ID=ABCDE12345
APP_STORE_CONNECT_ISSUER_ID=00000000-0000-0000-0000-000000000000
```

If you prefer text-safe storage in git, these base64 files also work:

- `ios/ci/certificate.p12.b64`
- `ios/ci/profile.mobileprovision.b64`
- `ios/ci/AuthKey.p8.b64`

## Important limitation

GitHub Actions cannot magically create a valid Apple signing identity from nothing.

You still need to obtain these inputs once from Apple:

- a `.p12` that contains your **certificate + private key**
- the matching `.mobileprovision`
- the App Store Connect API key `.p8`

Those are **inputs** to the build, not outputs from the build.

## If you only have Windows

You do **not** need a Mac just to store the files in the repo. Once you have the actual files, place them in `ios/ci/` and push.

If you only have `.b64` text versions, the workflow can decode them automatically.

## Common mistakes

- Using a `.cer` instead of a `.p12` → `security import` fails with `Unknown format in import`.
- Committing the wrong provisioning profile for the bundle id.
- Using a `.p12` password that does not match the exported file.
- Double-encoding base64.

## Security

This works in a private repo, but anyone with repository access can read the signing material. If the repo is exposed, revoke and recreate the Apple signing assets.
