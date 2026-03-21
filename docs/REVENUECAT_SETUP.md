# RevenueCat + AI subscription (checklist)

The app uses **entitlement id:** `ai_access` (see `RevenueCatConfig` in `lib/services/subscription_service.dart`). Packages come from RevenueCat **Offerings** — prices are **not** hard-coded in the app.

## What you configure in RevenueCat (dashboard)

1. **Products** — Create subscription products in **Google Play Console** and **App Store Connect** first, then link the same product IDs in RevenueCat.
2. **Entitlement** — Name it exactly **`ai_access`** and attach your subscription products to it.
3. **Offering** — Set a **current offering** with at least one **package** (e.g. monthly). The paywall reads `offerings.current.availablePackages`.

## Suggested pricing mindset (Gemini 3.1 Flash Lite, no search)

Rough API order-of-magnitude (check Google’s current page for exact numbers):

- **Input:** ~\$0.25 / 1M tokens (text)  
- **Output:** ~\$1.50 / 1M tokens  

If a subscriber sends **~500k input tokens/month** and **~150k output tokens/month**:

- Input: 0.5 × \$0.25 ≈ **\$0.13**  
- Output: 0.15 × \$1.50 ≈ **\$0.23**  
- **~\$0.35/user/month** variable cost before overhead  

That suggests:

- **\$4.99–\$9.99/month** can be reasonable for “unlimited-ish” casual AI if usage is capped server-side (your function uses `maxOutputTokens: 250` per reply, which helps a lot).
- Add a **yearly** plan with ~2 months free for better LTV.

**Important:** We **removed Google Search grounding** in `appwrite_functions/chat_ai/index.js` so you are **not** billed **\$14 / 1k search queries** after the free tier.

## Flutter / keys

- Android: `--dart-define=REVENUECAT_ANDROID_API_KEY=...` (or replace default in code for local dev only).
- iOS: same pattern with `REVENUECAT_IOS_API_KEY`.
- After changing products, call **Restore purchases** on a test device.

There is **no RevenueCat MCP** in this workspace; verify everything in [app.revenuecat.com](https://app.revenuecat.com).
