// Supabase Edge Function: send-push
//
// Sends an APNs remote push to every device registered for a user.
// Token-based auth (.p8 key) — no certificates.
//
// Trigger it either:
//   1) From a Database Webhook on INSERT into `notifications` (payload has `.record`), or
//   2) Directly:  POST { "user_id": "...", "title": "...", "body": "...", "data": {...} }
//
// Required function secrets (supabase secrets set ...):
//   APNS_KEY_ID         e.g. ABC123DEFG          (the .p8 Key ID)
//   APNS_TEAM_ID        AXK73U74AC               (Apple Developer Team ID)
//   APNS_BUNDLE_ID      idanidev.RentalMngr      (apns-topic)
//   APNS_PRIVATE_KEY    -----BEGIN PRIVATE KEY-----\n...   (.p8 contents, newlines as \n)
//   APNS_HOST           api.sandbox.push.apple.com  (dev) | api.push.apple.com (prod)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;
const PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_HOST = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ---- APNs auth token (ES256 JWT, cached ~50 min) ------------------------------

let cachedJWT: { token: string; iat: number } | null = null;

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const buf = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i);
  return buf.buffer;
}

async function apnsToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.iat < 3000) return cachedJWT.token;

  const header = base64url(JSON.stringify({ alg: "ES256", kid: KEY_ID }));
  const payload = base64url(JSON.stringify({ iss: TEAM_ID, iat: now }));
  const unsigned = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(PRIVATE_KEY.replace(/\\n/g, "\n")),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(unsigned),
  );

  const token = `${unsigned}.${base64url(sig)}`;
  cachedJWT = { token, iat: now };
  return token;
}

// ---- Send to one device -------------------------------------------------------

async function sendToDevice(
  deviceToken: string,
  title: string,
  body: string,
  data: Record<string, unknown>,
): Promise<{ token: string; status: number; reason?: string }> {
  const jwt = await apnsToken();
  const res = await fetch(`https://${APNS_HOST}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: { alert: { title, body }, sound: "default", badge: 1 },
      // Nest caller data under a non-reserved key so it can't override `aps`.
      data,
    }),
  });
  let reason: string | undefined;
  if (res.status !== 200) reason = (await res.json().catch(() => ({})))?.reason;
  return { token: deviceToken, status: res.status, reason };
}

// ---- HTTP entry ---------------------------------------------------------------

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";

Deno.serve(async (req) => {
  // Require a shared secret so an unauthenticated caller can't push to arbitrary users.
  // Set it on the function (supabase secrets set PUSH_WEBHOOK_SECRET=...) and send it as
  // the `x-webhook-secret` header from the Database Webhook.
  if (!WEBHOOK_SECRET || req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }
  try {
    const payload = await req.json();
    const record = payload.record ?? payload; // DB-webhook row or direct body
    const userId: string | undefined = record.user_id;
    const title: string = String(record.title ?? "RentalMngr").slice(0, 120);
    const body: string = String(record.body ?? record.message ?? "").slice(0, 300);
    const data: Record<string, unknown> = record.data ?? record.metadata ?? {};

    if (!userId || !UUID_RE.test(userId)) {
      return new Response(JSON.stringify({ error: "valid user_id required" }), { status: 400 });
    }

    const { data: tokens, error } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", userId);
    if (error) throw error;
    if (!tokens?.length) {
      return new Response(JSON.stringify({ sent: 0, note: "no devices" }), { status: 200 });
    }

    const results = await Promise.all(
      tokens.map((t) => sendToDevice(t.token, title, body, data)),
    );

    // Prune tokens APNs rejected as gone (410 / BadDeviceToken / Unregistered).
    const dead = results
      .filter((r) => r.status === 410 || r.reason === "BadDeviceToken" || r.reason === "Unregistered")
      .map((r) => r.token);
    if (dead.length) {
      await supabase.from("device_tokens").delete().in("token", dead);
    }

    // Don't leak device tokens / per-device results back to the caller.
    return new Response(
      JSON.stringify({ ok: true, sent: results.filter((r) => r.status === 200).length }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    console.error("send-push error:", e);
    return new Response(JSON.stringify({ error: "internal error" }), { status: 500 });
  }
});
