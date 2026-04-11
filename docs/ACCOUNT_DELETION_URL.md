# PointChat Account Deletion URL (Appwrite)

This project now includes an Appwrite Function at:

- `appwrite_functions/account_deletion/index.js`
- Function ID in `appwrite.json`: `account_deletion`

It also includes an Appwrite Site at:

- `appwrite_sites/account_deletion/index.html`
- Site ID in `appwrite.json`: `account-deletion-site`

## Live URL

Use this URL in Google Play Console "Delete account URL":

- `https://69d90bb2700499328634.appwrite.network`

## What this URL does

- Serves a public account deletion information page for Play Console policy
- Shows users how to delete the account from inside the app
- Lists what data is deleted and what may be retained
- Provides support contact for users who cannot access the app

Actual deletion is done in-app only (authenticated user flow) through the Appwrite function.

## Required function variables

Configure these in Appwrite Console -> Functions -> Account Deletion -> Variables:

- `DELETION_SUPPORT_EMAIL` (optional, defaults to `amrosh.world@gmail.com`)

The function uses standard Appwrite runtime variables automatically:

- `APPWRITE_FUNCTION_API_ENDPOINT`
- `APPWRITE_FUNCTION_PROJECT_ID`
- `APPWRITE_FUNCTION_API_KEY`

Function execute role should be:

- `users` (not `any`)

## Deploy

From repo root:

```bash
appwrite push functions
appwrite push sites
```

## Get URL for Play Console

1. Open Appwrite Console -> Sites -> PointChat Account Deletion.
2. Confirm latest deployment status is `ready`.
3. Use the generated appwrite.network URL in Google Play Console.

## Suggested Play Console text

Use this URL in the Delete account URL field.

For optional text in your policy page:

- "Users can permanently delete their PointChat account in-app from Settings -> Delete account."
- "Some security/legal backup logs may be retained for up to 90 days."
