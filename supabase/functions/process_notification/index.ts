import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type QueueRow = {
  id: number;
  target_role: "professor" | "student" | "all";
  target_user_id: string | null;
  type: string;
  title: string | null;
  body: string | null;
  data: Record<string, unknown>;
  attempts: number;
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

/**
 * Get OAuth2 access token for FCM HTTP v1 using service account JSON.
 * Env: FIREBASE_SERVICE_ACCOUNT_JSON (full JSON string)
 */
async function getFcmAccessToken(): Promise<string> {
  const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!saRaw) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON env");

  const sa = JSON.parse(saRaw);
  const clientEmail: string = sa.client_email;
  const privateKey: string = sa.private_key;

  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 60 * 50;

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp,
  };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replaceAll("+", "-")
      .replaceAll("/", "_")
      .replaceAll("=", "");

  const unsigned = `${enc(header)}.${enc(claimSet)}`;

  // RS256 sign
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");

  const assertion = `${unsigned}.${sig}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const data = await resp.json();
  if (!resp.ok) throw new Error(`Token error: ${JSON.stringify(data)}`);
  return data.access_token as string;
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\n", "")
    .trim();
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

async function sendFcm(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, unknown>,
) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  // data values must be strings in FCM
  const dataStr: Record<string, string> = {};
  for (const [k, v] of Object.entries(data ?? {})) {
    dataStr[k] = typeof v === "string" ? v : JSON.stringify(v);
  }

  const payload = {
    message: {
      token,
      notification: { title, body },
      data: dataStr,
      android: {
        priority: "HIGH",
        notification: {
          channel_id: "high_importance_channel", // must match your local channel id
        },
      },
    },
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const out = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(`FCM send failed: ${JSON.stringify(out)}`);
  return out;
}

serve(async (req) => {
  // Optional: protect endpoint with shared secret
  const secret = Deno.env.get("WORKER_SECRET");
  if (secret) {
    const got = req.headers.get("x-worker-secret");
    if (got !== secret) return json(401, { error: "Unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID")!;
  const batchSize = Number(new URL(req.url).searchParams.get("batch") ?? "50");

  const sb = createClient(supabaseUrl, serviceKey);

  // 1) claim jobs
  const { data: jobs, error: claimErr } = await sb
    .rpc("claim_notification_jobs", { batch_size: batchSize });

  if (claimErr) return json(500, { error: "claim_failed", details: claimErr });

  if (!jobs || jobs.length === 0) return json(200, { ok: true, processed: 0 });

  // 2) get FCM access token once
  let accessToken = "";
  try {
    accessToken = await getFcmAccessToken();
  } catch (e) {
    // mark all claimed jobs as failed
    await Promise.all(jobs.map((j: QueueRow) =>
      sb.from("notification_queue").update({
        status: "failed",
        attempts: (j.attempts ?? 0) + 1,
        last_error: String(e),
      }).eq("id", j.id)
    ));
    return json(500, { error: "fcm_token_failed", details: String(e) });
  }

  let ok = 0;
  let failed = 0;

  for (const j of jobs as QueueRow[]) {
    try {
      if (!j.target_user_id) throw new Error("Missing target_user_id");

      // 3) get target tokens
      const { data: tokens, error: tokErr } = await sb
        .from("device_tokens")
        .select("token")
        .eq("user_id", j.target_user_id);

      if (tokErr) throw tokErr;
      if (!tokens || tokens.length === 0) throw new Error("No device token");

      const title = j.title ?? "Attendly";
      const body = j.body ?? "You have a notification.";

      // 4) send to ALL tokens of that user (or just first if you enforce single token)
      for (const t of tokens) {
        await sendFcm(accessToken, projectId, t.token, title, body, j.data ?? {});
      }

      // 5) mark sent
      await sb.from("notification_queue").update({
        status: "sent",
        sent_at: new Date().toISOString(),
        last_error: null,
      }).eq("id", j.id);

      ok++;
    } catch (e) {
      failed++;
      await sb.from("notification_queue").update({
        status: "failed",
        attempts: (j.attempts ?? 0) + 1,
        last_error: String(e),
      }).eq("id", j.id);
    }
  }

  return json(200, { ok: true, processed: jobs.length, sent: ok, failed });
});
