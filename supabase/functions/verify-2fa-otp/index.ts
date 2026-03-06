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

  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, message: "Method not allowed" });

  try {
    const body = await req.json().catch(() => ({}));
    const email = normalizeEmail(String(body.email ?? ""));
    const otp = String(body.otp ?? "").trim();

    if (!email || !email.includes("@")) return json(origin, 400, { success: false, message: "Invalid email" });
    if (!/^\d{6}$/.test(otp)) return json(origin, 400, { success: false, message: "Invalid otp" });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return json(origin, 500, { success: false, message: "Missing env" });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    // 1) get OTP row
    const { data: row, error: selErr } = await admin
      .from("twofa_otps")
      .select("email, otp_hash, expires_at, verified")
      .eq("email", email)
      .maybeSingle();

    if (selErr) return json(origin, 200, { success: false, message: "DB select failed", db_error: selErr });
    if (!row) return json(origin, 200, { success: false, message: "OTP not found", verified: false });

    // 2) expiry check
    const now = Date.now();
    const exp = new Date(row.expires_at).getTime();
    if (Number.isNaN(exp) || exp < now) {
      // optional: mark as not verified if expired
      await admin.from("twofa_otps").update({ verified: false, updated_at: new Date().toISOString() }).eq("email", email);
      return json(origin, 200, { success: false, message: "OTP expired", verified: false });
    }

    // 3) hash compare
    const otpHash = await sha256Hex(otp);
    const ok = otpHash === row.otp_hash;

    if (!ok) {
      // optional: keep verified false
      await admin.from("twofa_otps").update({ verified: false, updated_at: new Date().toISOString() }).eq("email", email);
      return json(origin, 200, { success: false, message: "Invalid OTP", verified: false });
    }

    // 4) success -> mark verified true
    const { error: upErr } = await admin
      .from("twofa_otps")
      .update({ verified: true, updated_at: new Date().toISOString() })
      .eq("email", email);

    if (upErr) {
      return json(origin, 200, { success: false, message: "Verified but failed to update flag", verified: false, db_error: upErr });
    }

    return json(origin, 200, { success: true, message: "OTP verified", verified: true });
  } catch (e) {
    return json(origin, 200, { success: false, message: "Exception", error: String(e), verified: false });
  }
});