// PocketPlan AI proxy (Cloudflare Workers, free plan).
// Keeps the Gemini API key off the client, requires a valid Firebase login,
// and enforces a per-user daily limit.

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const MAX_BODY_BYTES = 64 * 1024;
const MAX_MESSAGES = 40;
const MAX_OUTPUT_TOKENS = 1024;

let jwksCache = { keys: null, fetchedAt: 0 };

function b64urlToBytes(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  s += '='.repeat((4 - (s.length % 4)) % 4);
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

function decodeJson(part) {
  return JSON.parse(new TextDecoder().decode(b64urlToBytes(part)));
}

async function getJwks(force = false) {
  const fresh = Date.now() - jwksCache.fetchedAt < 60 * 60 * 1000;
  if (!force && jwksCache.keys && fresh) return jwksCache.keys;
  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new Error('jwks fetch failed');
  const { keys } = await res.json();
  jwksCache = { keys, fetchedAt: Date.now() };
  return keys;
}

// Returns the Firebase uid, or throws.
export async function verifyFirebaseToken(token, projectId) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('malformed token');

  const header = decodeJson(parts[0]);
  if (header.alg !== 'RS256' || !header.kid) throw new Error('bad header');

  let jwk = (await getJwks()).find((k) => k.kid === header.kid);
  if (!jwk) jwk = (await getJwks(true)).find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('unknown key');

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    b64urlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) throw new Error('bad signature');

  const p = decodeJson(parts[1]);
  const now = Math.floor(Date.now() / 1000);
  if (typeof p.exp !== 'number' || p.exp <= now) throw new Error('expired');
  if (typeof p.iat !== 'number' || p.iat > now + 60) throw new Error('bad iat');
  if (p.aud !== projectId) throw new Error('bad audience');
  if (p.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error('bad issuer');
  }
  if (typeof p.sub !== 'string' || !p.sub) throw new Error('no subject');
  return p.sub;
}

function corsHeaders(request, env) {
  const origin = request.headers.get('Origin');
  const allowed = (env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const h = {
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
  const localDev =
    env.ALLOW_LOCALHOST === 'true' && /^http:\/\/localhost:\d+$/.test(origin || '');
  if (origin && (allowed.includes(origin) || localDev)) {
    h['Access-Control-Allow-Origin'] = origin;
  }
  return h;
}

function json(body, status, extra) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...extra },
  });
}

export default {
  async fetch(request, env) {
    const cors = corsHeaders(request, env);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405, cors);
    }

    // Browsers send Origin; block other websites. (Mobile apps send none.)
    const origin = request.headers.get('Origin');
    if (origin && !cors['Access-Control-Allow-Origin']) {
      return json({ error: 'Origin not allowed' }, 403, cors);
    }

    // 1) Must be a signed-in PocketPlan user.
    const auth = request.headers.get('Authorization') || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    let uid;
    try {
      uid = await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
    } catch (_) {
      return json({ error: 'Unauthorized' }, 401, cors);
    }

    // 2) Validate the request before spending any quota.
    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) {
      return json({ error: 'Request too large' }, 413, cors);
    }
    let body;
    try {
      body = JSON.parse(raw);
    } catch (_) {
      return json({ error: 'Invalid JSON' }, 400, cors);
    }
    if (
      !Array.isArray(body.contents) ||
      body.contents.length === 0 ||
      body.contents.length > MAX_MESSAGES
    ) {
      return json({ error: 'Invalid contents' }, 400, cors);
    }

    // 3) Per-user daily limit (resets at 00:00 UTC).
    const limit = parseInt(env.DAILY_LIMIT || '30', 10);
    const day = new Date().toISOString().slice(0, 10);
    const counterKey = `u:${uid}:${day}`;
    const used = parseInt((await env.RATE_KV.get(counterKey)) || '0', 10);
    if (used >= limit) {
      return json(
        { error: `Daily AI limit reached (${limit}). Try again tomorrow.` },
        429,
        cors,
      );
    }
    await env.RATE_KV.put(counterKey, String(used + 1), {
      expirationTtl: 172800,
    });

    // 4) Forward only the fields we allow; model and key are ours.
    const upstreamBody = {
      contents: body.contents,
      generationConfig: {
        maxOutputTokens: Math.min(
          Number(body.generationConfig?.maxOutputTokens) || MAX_OUTPUT_TOKENS,
          MAX_OUTPUT_TOKENS,
        ),
      },
    };
    if (body.systemInstruction) {
      upstreamBody.systemInstruction = body.systemInstruction;
    }

    const upstream = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': env.GEMINI_API_KEY,
      },
      body: JSON.stringify(upstreamBody),
    });

    return new Response(await upstream.text(), {
      status: upstream.status,
      headers: { 'Content-Type': 'application/json', ...cors },
    });
  },
};
