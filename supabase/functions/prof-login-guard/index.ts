import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin ?? "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
  "Content-Type": "application/json",
});

function json(origin: string | null, status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders(origin) });
}

// ✅ Binago para gamitin ang Brevo Templates (ID #4)
async function sendBrevoTemplate(args: {
  to: string;
  templateId: number;
  params: Record<string, any>;
  apiKey: string;
}) {
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": args.apiKey,
      "content-type": "application/json",
      "accept": "application/json",
    },
    body: JSON.stringify({
      to: [{ email: args.to }],
      templateId: args.templateId, // Template ID #4 para sa Fraudulent Check
      params: args.params,         // Dito ipapasa ang login attempts data
    }),
  });

  const text = await r.text().catch(() => "");
  let parsed: unknown = text;
  try { parsed = text ? JSON.parse(text) : text; } catch {}
  return { ok: r.ok, status: r.status, body: parsed };
}

serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL") ?? Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");

  if (!PROJECT_URL || !SERVICE_ROLE_KEY || !BREVO_API_KEY) {
    return json(origin, 500, { success: false, message: "Missing env variables" });
  }

  const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  const LOCK_AFTER = 3;
  const LOCK_SECONDS = 60;
  const EMAIL_COOLDOWN_SECONDS = 1800;

  try {
    const body = await req.json().catch(() => ({}));
    const email = String(body.email ?? "").trim().toLowerCase();

    if (!email) return json(origin, 400, { success: false, message: "email is required" });

    const { data: prof, error: profErr } = await admin
      .from("professors")
      .select("id,email,login_attempts,last_failed_login_at,last_login_alert_at")
      .eq("email", email)
      .maybeSingle();

    if (profErr || !prof?.id || !prof?.email) return json(origin, 200, { success: true });

    const now = new Date();
    const attempts0 = Number(prof.login_attempts ?? 0);
    const lastFailed = prof.last_failed_login_at ? new Date(prof.last_failed_login_at) : null;

    if (attempts0 >= LOCK_AFTER && lastFailed) {
      const elapsedSec = Math.floor((now.getTime() - lastFailed.getTime()) / 1000);
      const remaining = LOCK_SECONDS - elapsedSec;
      if (remaining > 0) {
        return json(origin, 200, { success: true, attempts: attempts0, locked: true, lock_seconds: remaining });
      } else {
        await admin.from("professors").update({ login_attempts: 0 }).eq("id", prof.id);
      }
    }

    const nextAttempts = attempts0 + 1;
    await admin.from("professors").update({ login_attempts: nextAttempts, last_failed_login_at: now.toISOString() }).eq("id", prof.id);

    const shouldLock = nextAttempts >= LOCK_AFTER;
    let emailed = false;

    if (shouldLock) {
      const lastAlert = prof.last_login_alert_at ? new Date(prof.last_login_alert_at) : null;
      const canEmail = !lastAlert || now.getTime() - lastAlert.getTime() > EMAIL_COOLDOWN_SECONDS * 1000;

      if (canEmail) {
        // ✅ PAG-SEND GAMIT ANG TEMPLATE ID #4
        const r = await sendBrevoTemplate({
          to: String(prof.email).trim().toLowerCase(),
          templateId: 4, // "FRAUDULENT CHECK" ID
          params: {
            attempts: nextAttempts, // Gamitin sa UI: {{ params.attempts }}
            lock_duration: LOCK_SECONDS, // Gamitin sa UI: {{ params.lock_duration }}
          },
          apiKey: BREVO_API_KEY,
        });

        if (r.ok) {
          emailed = true;
          await admin.from("professors").update({ last_login_alert_at: now.toISOString() }).eq("id", prof.id);
        }
      }
    }

    return json(origin, 200, {
      success: true,
      attempts: nextAttempts,
      locked: shouldLock,
      lock_seconds: shouldLock ? LOCK_SECONDS : 0,
      emailed,
    });
  } catch {
    return json(origin, 200, { success: true });
  }
});