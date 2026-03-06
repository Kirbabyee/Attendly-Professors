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

function genOtp6() {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return String(n).padStart(6, "0");
}

async function sha256(text: string) {
  const enc = new TextEncoder().encode(text);
  const buf = await crypto.subtle.digest("SHA-256", enc);
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ✅ Binago para gamitin ang Brevo Template ID #5
async function sendBrevoTemplate(args: {
  to: string;
  templateId: number;
  params: Record<string, string>;
  apiKey: string;
}) {
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "api-key": args.apiKey,
    },
    body: JSON.stringify({
      to: [{ email: args.to }],
      templateId: args.templateId, // Template ID #5 para sa Email Change
      params: args.params,         // Dito ipapasa ang OTP code
    }),
  });
  const data = await r.json().catch(() => ({}));
  return { ok: r.ok, status: r.status, data };
}

serve(async (req) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, step: "method", message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL") ?? Deno.env.get("SUPABASE_URL");
  const ANON_KEY = Deno.env.get("ANON_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");

  if (!PROJECT_URL || !ANON_KEY || !SERVICE_ROLE_KEY || !BREVO_API_KEY) {
    return json(origin, 500, { success: false, step: "env", message: "Missing environment variables" });
  }

  const authed = createClient(PROJECT_URL, ANON_KEY, {
    global: { headers: { Authorization: req.headers.get("authorization") ?? "" } },
    auth: { persistSession: false },
  });
  const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    const body = await req.json();
    const professor_id = String(body.professor_id ?? "").trim();
    const current_password = String(body.current_password ?? "").trim();
    const new_email = String(body.new_email ?? "").trim().toLowerCase();

    if (!professor_id || !current_password || !new_email) {
      return json(origin, 400, { success: false, step: "validate", message: "Missing fields" });
    }

    // 1) Auth and current password check
    const { data: u, error: uErr } = await authed.auth.getUser();
    if (uErr || !u?.user || u.user.id !== professor_id) return json(origin, 401, { success: false, message: "Unauthorized" });

    const { error: signErr } = await createClient(PROJECT_URL, ANON_KEY, { auth: { persistSession: false } })
      .auth.signInWithPassword({ email: u.user.email!, password: current_password });

    if (signErr) return json(origin, 400, { success: false, message: "Incorrect current password" });

    // 2) Duplicate email check
    const { data: existing } = await admin.from("professors").select("id").eq("email", new_email).maybeSingle();
    if (existing) return json(origin, 400, { success: false, message: "Email already taken" });

    // 3) OTP Generation and DB Save
    const otp = genOtp6();
    const otpHash = await sha256(`${professor_id}|${new_email}|${otp}`);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: dbErr } = await admin.from("password_reset_otps").upsert({
      user_id: professor_id,
      role: "professor",
      purpose: "change_email",
      otp_hash: otpHash,
      target_email: new_email,
      expires_at: expiresAt,
      last_sent_at: new Date().toISOString(),
      attempts: 0,
      used_at: null,
    }, { onConflict: "user_id,purpose" });

    if (dbErr) return json(origin, 500, { success: false, message: "DB error" });

    // 4) ✅ PAG-SEND GAMIT ANG TEMPLATE ID #5 (Email Change)
    const mail = await sendBrevoTemplate({
      to: new_email,
      templateId: 5, // ID para sa Email Change Request UI mo
      params: {
        OTP: otp,    // Papasok sa {{ params.OTP }} placeholder sa Brevo
      },
      apiKey: BREVO_API_KEY,
    });

    if (!mail.ok) return json(origin, 400, { success: false, message: "Email send failed", details: mail });

    return json(origin, 200, { success: true, message: "OTP sent to " + new_email });
  } catch (e) {
    return json(origin, 400, { success: false, message: String(e) });
  }
});