# RevenueCat + AI subscription (checklist)

The app uses **entitlement id:** `ai_access` (see `RevenueCatConfig` in `lib/services/subscription_service.dart`). Packages come from RevenueCat **Offerings** — prices are **not** hard-coded in the app.

## What you configure in RevenueCat (dashboard)

1. **Products** — The RevenueCat project now has these product identifiers ready:
   - Android monthly: `pointchat_ai:monthly`
   - Android annual: `pointchat_ai:annual`
   - iOS monthly: `com.amrosh.Pointchat.ai.monthly`
   - iOS annual: `com.amrosh.Pointchat.ai.annual`
   - Test Store monthly: `pointchat_ai_monthly_test`
   - Test Store annual: `pointchat_ai_annual_test`
2. **Entitlement** — `ai_access` exists and is attached to all monthly/annual products.
3. **Offering** — Current offering `ai_access` now has packages `$rc_monthly` and `$rc_annual`. The paywall reads `offerings.current.availablePackages`.
4. **Test Store prices** — Configured for development/testing:
   - Monthly: `USD 4.99`
   - Annual: `USD 39.99`
5. **Store consoles still matter** — For real purchases, create the same IDs in **Google Play Console** and **App Store Connect** and set their live prices there. RevenueCat does not replace those store-side records.

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

- Android default key in code matches RevenueCat: `goog_TERmGBEENicfFTgbipVDDIItzWL`.
- iOS default key in code is now set too: `appl_ADugYdOCqeDqvVufcLTapimDzGx`.
- You can still override either one with `--dart-define`.
- After changing products, call **Restore purchases** on a test device.

This setup was created directly through the RevenueCat MCP and can also be verified in [app.revenuecat.com](https://app.revenuecat.com).
