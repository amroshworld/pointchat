# Signing assets (private repo)

**Security:** Even in a private repository, anyone with clone access sees committed keystores. Prefer [GitHub Actions encrypted secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions) and keep the keystore only in CI (see `docs/RELEASE_PLAY_APPSTORE.md`).

If you still want a backup in git:

1. Place `upload-keystore.jks` in this folder.
2. Never commit `android/key.properties` (passwords) — keep that file local or use CI secrets.
3. Document your key alias locally (password manager).

To force-add a file that your global gitignore might catch, use `git add -f signing/upload-keystore.jks` only after you understand the exposure risk.
