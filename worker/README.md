# PocketPlan AI proxy (free, Cloudflare Workers)

Keeps the Gemini API key out of the app. Requires a valid Firebase login and
limits each user to `DAILY_LIMIT` chats per day (default 30).

## One-time setup (free plan, no card needed)
```
cd worker
npx wrangler login
npx wrangler kv namespace create RATE_KV      # copy the id into wrangler.toml
npx wrangler secret put GEMINI_API_KEY        # paste a NEW Gemini key
npx wrangler deploy                           # prints https://pocketplan-ai.<you>.workers.dev
```
Then in the app's `.env`: `GEMINI_PROXY_URL=<that url>` and delete `GEMINI_API_KEY`.

Afterwards:
- Create a **new** Gemini key for the Worker and delete the old one (the old
  key was shipped in the app).
- Put your Firebase Hosting URL in `ALLOWED_ORIGINS` and set
  `ALLOW_LOCALHOST = "false"` in `wrangler.toml` before going live.

## Tests
`npm test` (Node 20+; no dependencies).

## Free-tier limits to know
Workers: 100k requests/day. KV: 1,000 writes/day, and every chat is one write,
so about 1,000 AI chats/day across all users. Past that, move the counter to a
Durable Object or upgrade.
