import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function cors(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin ?? "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Content-Type": "application/json",
  };
}
function json(origin: string | null, status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: cors(origin) });
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
async function sendBrevoEmail(args: {
  to: string;
  subject: string;
  html: string;
  fromEmail: string;
  fromName: string;
  apiKey: string;
}) {
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "content-type": "application/json", "api-key": args.apiKey },
    body: JSON.stringify({
      sender: { email: args.fromEmail, name: args.fromName },
      to: [{ email: args.to }],
      subject: args.subject,
      htmlContent: args.html,
    }),
  });
  const data = await r.json().catch(() => ({}));
  return { ok: r.ok, status: r.status, data };
}

serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY");
  const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");
  const BREVO_FROM_EMAIL = Deno.env.get("BREVO_FROM_EMAIL");
  const BREVO_FROM_NAME = Deno.env.get("BREVO_FROM_NAME") ?? "Attendly";

  if (!PROJECT_URL || !SERVICE_ROLE_KEY) return json(origin, 500, { success: false, message: "Missing env" });
  if (!BREVO_API_KEY || !BREVO_FROM_EMAIL) return json(origin, 500, { success: false, message: "Missing brevo env" });

  const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    const body = await req.json();
    const email = String(body.email ?? "").trim().toLowerCase();

    if (!email) {
      return json(origin, 400, { success: false, message: "email are required" });
    }
    if (!/^[^@]+@[^@]+\.[^@]+$/.test(email)) {
      return json(origin, 400, { success: false, message: "Invalid email format" });
    }

    // ✅ confirm professor exists (match email + professor_number)
    const { data: prof, error: profErr } = await admin
      .from("professors")
      .select("id,email")
      .eq("email", email)
      .maybeSingle();

    if (profErr) return json(origin, 400, { success: false, message: profErr.message });

    // security: you can hide existence, but since you already checked earlier,
    // here we return clear error to match your UI requirement
    if (!prof?.id) {
      return json(origin, 404, { success: false, message: "professor not found" });
    }

    const professor_id = String(prof.id);

    // ✅ cooldown / rate limit
    const role = "professor";
    const purpose = "enable_2fa";

    const { data: existing, error: exErr } = await admin
      .from("password_reset_otps")
      .select("*")
      .eq("user_id", professor_id)
      .eq("role", role)
      .eq("purpose", purpose)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (exErr) return json(origin, 400, { success: false, message: exErr.message });

    const now = new Date();
    const COOLDOWN_SECONDS = 60;
    const MAX_PER_HOUR = 10;

    if (existing) {
      const lastSent = new Date(existing.last_sent_at);
      const diffSec = Math.floor((now.getTime() - lastSent.getTime()) / 1000);
      if (diffSec < COOLDOWN_SECONDS) {
        return json(origin, 429, {
          success: false,
          message: `Please wait ${COOLDOWN_SECONDS - diffSec}s before resending.`,
          wait_seconds: COOLDOWN_SECONDS - diffSec,
        });
      }

      const windowStart = new Date(existing.window_started_at);
      const windowDiffSec = Math.floor((now.getTime() - windowStart.getTime()) / 1000);
      let sentCount = Number(existing.sent_count ?? 1);
      if (windowDiffSec >= 3600) sentCount = 0;
      if (sentCount >= MAX_PER_HOUR) {
        return json(origin, 429, { success: false, message: "Too many OTP requests. Try again later." });
      }
    }

    // ✅ create OTP row
    const otp = genOtp6();
    const otpHash = await sha256(`${professor_id}|${email}|${otp}`);
    const expiresAt = new Date(now.getTime() + 10 * 60 * 1000);

    if (existing?.id) {
      const windowStart = new Date(existing.window_started_at);
      const inSameHour = now.getTime() - windowStart.getTime() < 3600 * 1000;

      await admin.from("password_reset_otps").update({
        otp_hash: otpHash,
        expires_at: expiresAt.toISOString(),
        last_sent_at: now.toISOString(),
        sent_count: inSameHour ? Number(existing.sent_count ?? 1) + 1 : 1,
        window_started_at: inSameHour ? existing.window_started_at : now.toISOString(),
        attempts: 0,
        target_email: email,
        used_at: null,
      }).eq("id", existing.id);
    } else {
      await admin.from("password_reset_otps").insert({
        user_id: professor_id,
        role,
        purpose,
        otp_hash: otpHash,
        expires_at: expiresAt.toISOString(),
        last_sent_at: now.toISOString(),
        sent_count: 1,
        window_started_at: now.toISOString(),
        attempts: 0,
        target_email: email,
      });
    }

    // ✅ send mail
    const html = `
      <h2>Attendly OTP</h2>
      <p>Your OTP for enabling your Two-Factor Authentication</p>
      <div style="font-size:28px;font-weight:800;letter-spacing:6px;margin:16px 0;">${otp}</div>
      <p>This OTP will expire in <b>10 minutes</b>.</p>
      <p style="font-size:12px;color:#6b7280">If you didn't request this, ignore this email.</p>
    `;

    const mail = await sendBrevoEmail({
      to: email,
      subject: "Attendly OTP",
      html,
      fromEmail: BREVO_FROM_EMAIL,
      fromName: BREVO_FROM_NAME,
      apiKey: BREVO_API_KEY,
    });

    if (!mail.ok) {
      return json(origin, 400, { success: false, message: "Brevo send failed", details: mail });
    }

    return json(origin, 200, { success: true, message: "OTP sent." });
  } catch (e) {
    return json(origin, 400, { success: false, message: String(e) });
  }
});
