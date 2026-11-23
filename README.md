# PocketPlan

Cross-platform personal finance & monthly budgeting app built with **Flutter**, **Firebase**, **OpenStreetMap**, and a **Cloudflare Workers + Gemini** AI Financial Advisor proxy.

## Core Features
- **Monthly Income & Flexible Split Budgeting:** Start with 50/30/20 or customize splits (e.g., 60/20/20, 70/20/10, or custom percentages) across **Essential Needs**, **Lifestyle & Wants**, and **Savings & Goals**, with optional monthly carry-forward and customizable payday cycle start day (`1st–28th`).
- **Recurring Bills & Income:** Schedule monthly rent, salaries, utilities, and subscriptions once (`1st–28th`); PocketPlan posts due items idempotently per budget cycle or on demand.
- **Transaction Tracking & Export:** Record income and expenses with integer-cent input validation, edit/delete atomically via Firestore transactions, filter by bucket/type, and export to **PDF** or **CSV**.
- **Multi-Currency & All-Ages Profiles:** Supports 10 currencies (`MYR`, `USD`, `SGD`, `GBP`, `EUR`, `AUD`, `IDR`, `THB`, `PHP`, `JPY`), life-stage personalization (`Student`, `Young Adult`, `Working Adult`, `Family / Household`, `Retiree / Senior`), and System/Light/Dark themes.
- **Analytics & Fuzzy-Logic Spending Forecast:** 7-day trend chart, month-over-month comparison, category breakdown, and Mamdani fuzzy inference 1-month and 6-month forecasts.
- **AI Financial Advisor:** Authenticated Cloudflare Worker proxy (`worker/`) enforcing Firebase ID tokens, per-user daily limits, server-side system prompts, and persistent per-user conversation history.
- **Budget-Aware Food Nearby:** Interactive `flutter_map` + OpenStreetMap Overpass query within 5km featuring a live daily lifestyle budget banner, **"Fits Budget"** filter, Google Maps **Directions**, 1-tap **"Log Meal"** prefill, and community cheap-dish price tips (`dish_tips`).

## Local Development
```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Configure local AI proxy URL in .env (or pass --dart-define)
# .env:
# GEMINI_PROXY_URL=https://pocketplan-ai.<your-subdomain>.workers.dev

# 3. Run static analysis and tests
flutter analyze --no-fatal-infos
flutter test

# 4. Run Cloudflare Worker tests
cd worker && npm test
```

## Production & Store Release Checklist
1. **Deploy hardened AI proxy Worker** (activates server-side system prompt & timeout handling):
   ```bash
   cd worker
   npx wrangler deploy
   ```
2. **Deploy updated Firestore rules** (owner-only rules):
   ```bash
   firebase deploy --only firestore:rules
   ```
3. **Android Release Signing:** Create an upload keystore and `android/key.properties` (gitignored):
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=upload
   storeFile=<path-to-upload-keystore.jks>
   ```
   Then build:
   ```bash
   flutter build appbundle --release --dart-define=GEMINI_PROXY_URL=https://pocketplan-ai.<your-subdomain>.workers.dev
   ```
4. **Web Build & Hosting:**
   ```bash
   flutter build web --release --dart-define=GEMINI_PROXY_URL=https://pocketplan-ai.<your-subdomain>.workers.dev
   firebase deploy --only hosting
   ```
5. **Privacy Policy:** Host `docs/PRIVACY_POLICY.md` at a public URL and link it in Google Play Console and App Store Connect.
