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

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function randomOtp6() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function bytesToHex(bytes: Uint8Array) {
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(input: string) {
  const data = new TextEncoder().encode(input);
  const hashBuf = await crypto.subtle.digest("SHA-256", data);
  return bytesToHex(new Uint8Array(hashBuf));
}

serve(async (req) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: cors(origin) });
  }
  if (req.method !== "POST") {
    return json(origin, 405, { success: false, message: "Method not allowed" });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const emailRaw = String(body.email ?? "");
    const email = normalizeEmail(emailRaw);

    if (!email || !email.includes("@")) {
      return json(origin, 400, { success: false, message: "Invalid email" });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return json(origin, 500, {
        success: false,
        message: "Missing env SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY",
      });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false },
    });

    // ✅ generate OTP + hash
    const otp = randomOtp6();
    const otpHash = await sha256Hex(otp);

    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
    const nowIso = new Date().toISOString();

    // ✅ UPSERT (overwrite by email PK)
    const { error: upErr } = await admin.from("twofa_otps").upsert({
      email,
      otp_hash: otpHash,
      expires_at: expiresAt,
      updated_at: nowIso,
      verified: false,
    });

    if (upErr) {
      return json(origin, 200, {
        success: false,
        message: "DB upsert failed",
        db_error: upErr,
      });
    }

    // ✅ send email (optional — but we return debug)
    const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");
    const FROM_EMAIL =
      Deno.env.get("BREVO_FROM_EMAIL") ??
      Deno.env.get("MAIL_FROM") ??
      "no-reply@example.com";
    const FROM_NAME = Deno.env.get("BREVO_FROM_NAME") ?? "Attendly";

    if (!BREVO_API_KEY) {
      // DB saved, pero walang email key
      return json(origin, 200, {
        success: true,
        message: "OTP saved but BREVO_API_KEY missing",
        saved: true,
        email,
      });
    }

    const r = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": BREVO_API_KEY,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        sender: { email: FROM_EMAIL, name: FROM_NAME },
        to: [{ email }],
        subject: "Your Attendly OTP Code",
        htmlContent: `
          <div style="font-family:Arial,sans-serif">
            <p>Your OTP code is:</p>
            <h2 style="letter-spacing:2px">${otp}</h2>
            <p>This code expires in 5 minutes.</p>
          </div>
        `,
      }),
    });

    const text = await r.text().catch(() => "");
    let parsed: unknown = text;
    try {
      parsed = text ? JSON.parse(text) : text;
    } catch {}

    if (!r.ok) {
      // ✅ DB saved, email failed
      return json(origin, 200, {
        success: false,
        message: "Brevo send failed (OTP still saved)",
        saved: true,
        brevo_status: r.status,
        brevo_body: parsed,
        from: FROM_EMAIL,
        to: email,
      });
    }

    return json(origin, 200, {
      success: true,
      message: "OTP saved and email sent",
      saved: true,
      brevo_status: r.status,
      brevo_body: parsed,
      to: email,
    });
  } catch (e) {
    return json(origin, 200, { success: false, message: "Exception", error: String(e) });
  }
});
