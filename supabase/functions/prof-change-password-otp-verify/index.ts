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
async function sha256(text: string) {
  const enc = new TextEncoder().encode(text);
  const buf = await crypto.subtle.digest("SHA-256", enc);
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function isStrongEnough(pw: string) {
  // same as your current rule (>= 8)
  if (pw.length < 8) return false;
  return true;
}

serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL");
  const ANON_KEY = Deno.env.get("ANON_KEY");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY");
  if (!PROJECT_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
    return json(origin, 500, { success: false, message: "Missing env" });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const authed = createClient(PROJECT_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    const body = await req.json();
    const professor_id = String(body.professor_id ?? "").trim();
    const otp = String(body.otp ?? "").trim();
    const new_password = String(body.new_password ?? "").trim();

    if (!professor_id || !otp || !new_password) {
      return json(origin, 400, { success: false, message: "professor_id, otp, and new_password are required" });
    }
    if (otp.length !== 6) return json(origin, 400, { success: false, message: "OTP must be 6 digits" });
    if (!isStrongEnough(new_password)) {
      return json(origin, 400, { success: false, message: "Password must be at least 8 characters" });
    }

    // ✅ auth user check
    const { data: u, error: uErr } = await authed.auth.getUser();
    if (uErr || !u?.user) return json(origin, 401, { success: false, message: "Not authenticated" });
    if (u.user.id !== professor_id) return json(origin, 403, { success: false, message: "Forbidden" });

    const role = "professor";
    const purpose = "change_password";

    const { data: row, error: rowErr } = await admin
      .from("password_reset_otps")
      .select("*")
      .eq("user_id", professor_id)
      .eq("role", role)
      .eq("purpose", purpose)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (rowErr) return json(origin, 400, { success: false, message: rowErr.message });
    if (!row) return json(origin, 400, { success: false, message: "No OTP request found. Please request again." });
    if (row.used_at) return json(origin, 400, { success: false, message: "OTP already used. Please request again." });

    const targetEmail = String(row.target_email ?? "").trim().toLowerCase();
    if (!targetEmail) return json(origin, 400, { success: false, message: "Missing target email. Please request again." });

    const now = new Date();
    const exp = new Date(row.expires_at);
    if (now > exp) return json(origin, 400, { success: false, message: "OTP expired. Please resend." });

    if (Number(row.attempts ?? 0) >= 5) {
      return json(origin, 429, { success: false, message: "Too many attempts. Please resend OTP." });
    }

    // ✅ OTP hash check (bound to professor + email)
    const expected = String(row.otp_hash ?? "");
    const got = await sha256(`${professor_id}|${targetEmail}|${otp}`);

    if (got !== expected) {
      await admin
        .from("password_reset_otps")
        .update({ attempts: Number(row.attempts ?? 0) + 1 })
        .eq("id", row.id);

      return json(origin, 400, { success: false, message: "Invalid OTP." });
    }

    // ✅ update AUTH password (admin API)
    const { error: upErr } = await admin.auth.admin.updateUserById(professor_id, {
      password: new_password,
    });

    if (upErr) return json(origin, 400, { success: false, message: upErr.message });

    // ✅ consume OTP
    await admin.from("password_reset_otps").update({ used_at: now.toISOString() }).eq("id", row.id);

    return json(origin, 200, { success: true, message: "Password changed." });
  } catch (e) {
    return json(origin, 400, { success: false, message: String(e) });
  }
});
