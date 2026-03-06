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

serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, step: "method", message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL");
  const ANON_KEY = Deno.env.get("ANON_KEY");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY");
  if (!PROJECT_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
    return json(origin, 500, { success: false, step: "env", message: "Missing PROJECT_URL/ANON_KEY/SERVICE_ROLE_KEY" });
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

    if (!professor_id || !otp) {
      return json(origin, 400, { success: false, step: "validate", message: "professor_id and otp are required" });
    }
    if (otp.length !== 6) {
      return json(origin, 400, { success: false, step: "validate", message: "OTP must be 6 digits" });
    }

    // ✅ verify JWT user
    const { data: u, error: uErr } = await authed.auth.getUser();
    if (uErr || !u?.user) {
      return json(origin, 401, { success: false, step: "auth", message: "Not authenticated" });
    }
    if (u.user.id !== professor_id) {
      return json(origin, 403, { success: false, step: "auth", message: "Forbidden" });
    }

    const role = "professor";
    const purpose = "change_email";

    const { data: row, error: rowErr } = await admin
      .from("password_reset_otps")
      .select("*")
      .eq("user_id", professor_id)
      .eq("role", role)
      .eq("purpose", purpose)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (rowErr) {
      return json(origin, 400, { success: false, step: "otp", message: rowErr.message });
    }
    if (!row) {
      return json(origin, 400, { success: false, step: "otp", message: "No OTP request found. Please request again." });
    }

    // if already used (optional)
    if (row.used_at) {
      return json(origin, 400, { success: false, step: "otp", message: "OTP already used. Please request again." });
    }

    const targetEmail = String(row.target_email ?? "").trim().toLowerCase();
    if (!targetEmail) {
      return json(origin, 400, { success: false, step: "otp", message: "Missing target email. Please request again." });
    }

    const now = new Date();
    const exp = new Date(row.expires_at);
    if (now > exp) {
      return json(origin, 400, { success: false, step: "otp", message: "OTP expired. Please resend." });
    }

    if (Number(row.attempts ?? 0) >= 5) {
      return json(origin, 429, { success: false, step: "otp", message: "Too many attempts. Please resend OTP." });
    }

    // ✅ hash must match send function:
    // send: sha256(`${professor_id}|${new_email}|${otp}`)
    const expected = String(row.otp_hash ?? "");
    const got = await sha256(`${professor_id}|${targetEmail}|${otp}`);

    if (got !== expected) {
      await admin
        .from("password_reset_otps") // ✅ fixed table name
        .update({ attempts: Number(row.attempts ?? 0) + 1 })
        .eq("id", row.id);

      return json(origin, 400, { success: false, step: "otp", message: "Invalid OTP." });
    }

    // ✅ OTP ok → change auth email (no magic link)
    const { error: updErr } = await admin.auth.admin.updateUserById(professor_id, {
      email: targetEmail,
      email_confirm: true, // optional
    });
    if (updErr) return json(origin, 400, { success: false, step: "update_auth_email", message: updErr.message });

    // ✅ ALSO update professors table email
    const { error: profErr } = await admin
      .from("professors")
      .update({ email: targetEmail })
      .eq("id", professor_id);

    if (profErr) {
      // You have 2 choices:
      // A) treat as error (recommended to keep consistency)
      return json(origin, 400, { success: false, step: "update_professors_email", message: profErr.message });

      // B) OR allow success but warn (not recommended)
      // return json(origin, 200, { success: true, warning: "Auth email changed but professors table not updated.", email: targetEmail });
    }

    // ✅ consume OTP (choose one)
    // A) delete row
    await admin.from("password_reset_otps").delete().eq("id", row.id);

    // B) OR mark used:
    // await admin.from("password_reset_otps").update({ used_at: now.toISOString() }).eq("id", row.id);

    return json(origin, 200, { success: true, message: "Email changed.", email: targetEmail });
  } catch (e) {
    return json(origin, 400, { success: false, step: "catch", message: String(e) });
  }
});
