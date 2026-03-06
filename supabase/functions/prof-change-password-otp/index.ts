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

// ✅ Ginawang Template-based ang email sender
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
      "api-key": args.apiKey
    },
    body: JSON.stringify({
      to: [{ email: args.to }],
      templateId: args.templateId, // Template ID #2
      params: args.params,         // Dito ipapasa ang OTP code
    }),
  });
  const data = await r.json().catch(() => ({}));
  return { ok: r.ok, status: r.status, data };
}

serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL") ?? Deno.env.get("SUPABASE_URL");
  const ANON_KEY = Deno.env.get("ANON_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");

  if (!PROJECT_URL || !ANON_KEY || !SERVICE_ROLE_KEY || !BREVO_API_KEY) {
    return json(origin, 500, { success: false, message: "Missing environment variables" });
  }

  const authed = createClient(PROJECT_URL, ANON_KEY, {
    global: { headers: { Authorization: req.headers.get("authorization") ?? "" } },
    auth: { persistSession: false },
  });
  const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    const body = await req.json();
    const professor_id = String(body.professor_id ?? "").trim();
    if (!professor_id) return json(origin, 400, { success: false, message: "professor_id is required" });

    // ✅ verify JWT user
    const { data: u, error: uErr } = await authed.auth.getUser();
    if (uErr || !u?.user || u.user.id !== professor_id) {
      return json(origin, 401, { success: false, message: "Unauthorized" });
    }

    // ✅ Get email from professors table
    const { data: prof, error: profErr } = await admin.from("professors").select("email").eq("id", professor_id).maybeSingle();
    if (profErr || !prof?.email) return json(origin, 400, { success: false, message: "Email not found" });

    const tableEmail = prof.email.trim().toLowerCase();
    const purpose = "change_password";

    // ✅ Rate limiting logic
    const { data: existing } = await admin.from("password_reset_otps").select("*").eq("user_id", professor_id).eq("purpose", purpose).order("created_at", { ascending: false }).limit(1).maybeSingle();

    const now = new Date();
    if (existing) {
      const lastSent = new Date(existing.last_sent_at);
      const diffSec = Math.floor((now.getTime() - lastSent.getTime()) / 1000);
      if (diffSec < 60) return json(origin, 429, { success: false, message: `Wait ${60 - diffSec}s.` });
    }

    // ✅ OTP Generation
    const otp = genOtp6();
    const otpHash = await sha256(`${professor_id}|${tableEmail}|${otp}`);
    const expiresAt = new Date(now.getTime() + 10 * 60 * 1000).toISOString();

    // ✅ DB Update/Insert
    await admin.from("password_reset_otps").upsert({
      user_id: professor_id,
      role: "professor",
      purpose,
      otp_hash: otpHash,
      target_email: tableEmail,
      expires_at: expiresAt,
      last_sent_at: now.toISOString(),
      attempts: 0,
      used_at: null,
    }, { onConflict: "user_id,purpose" });

    // ✅ PAG-SEND GAMIT ANG TEMPLATE ID #2
    const mail = await sendBrevoTemplate({
      to: tableEmail,
      templateId: 2, // "FOR OTPS" UI Template
      params: {
        OTP: otp,    // Papasok sa {{ params.OTP }} sa dinesign mong UI
      },
      apiKey: BREVO_API_KEY,
    });

    if (!mail.ok) return json(origin, 400, { success: false, message: "Brevo send failed", details: mail });

    return json(origin, 200, { success: true, message: "OTP sent to your email." });
  } catch (e) {
    return json(origin, 400, { success: false, message: String(e) });
  }
});