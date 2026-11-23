# PocketPlan Privacy Policy & Financial Disclaimer

_Last updated: November 23, 2026_

## 1. Information We Collect
PocketPlan collects only the information needed to run your personal budget:
- **Account Information:** Name, email address, currency preference, and optional life stage.
- **Financial Entries:** Monthly income, budget limits, tracked budget items, and transaction records you enter manually.
- **Device Preferences:** Theme mode, accent color, notification preference, and local biometric unlock toggle (stored on your device).
- **Location Data (On Demand):** Your approximate/precise GPS coordinates are requested **only** when you open the Food Nearby feature to query nearby restaurants, food courts, cafes, bakeries, and grocery stores. Coordinates are not stored in our database.

## 2. How Your Data Is Processed & Stored
- **Firebase (Authentication & Cloud Firestore):** Stores your account and financial entries privately under owner-only security rules (`users/{uid}`, `budgets/{uid}`, `transactions`).
- **AI Financial Advisor (Cloudflare Worker + Google Gemini):** When you send a message in the AI Advisor, your chat message and a summary of your current monthly budget (income, bucket totals, top categories, and recent transactions) are sent through PocketPlan's authenticated Cloudflare Worker proxy to Google Gemini to generate a response.

## 3. Data Deletion
You can permanently delete your PocketPlan account and all associated Firestore records at any time in the app via **Settings → Security → Delete Account**.

## 4. Financial Disclaimer
PocketPlan's AI Financial Advisor, budget splits, and fuzzy-logic spending forecasts are provided for **informational and educational purposes only**. They do not constitute licensed financial, tax, investment, or legal advice.
