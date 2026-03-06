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
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// ✅ same rules as your Flutter validator (basic)
function validateStrongPassword(pw: string): string | null {
  if (!pw || pw.trim().isEmpty) return "Password is required";
  if (pw.length < 8) return "Minimum 8 characters";
  if (!/[A-Z]/.test(pw)) return "Must contain at least 1 uppercase letter";
  if (!/[a-z]/.test(pw)) return "Must contain at least 1 lowercase letter";
  if (!/[0-9]/.test(pw)) return "Must contain at least 1 number";
  if (!/[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]/.test(pw)) return "Must contain at least 1 special character";
  return null;
}

serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY");
  if (!PROJECT_URL || !SERVICE_ROLE_KEY) return json(origin, 500, { success: false, message: "Missing env" });

  const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    const body = await req.json();

    const email = String(body.email ?? "").trim().toLowerCase();
    const otp = String(body.otp ?? "").trim();
    const new_password = String(body.new_password ?? "").trim();

    if (!email || !otp || !new_password) {
      return json(origin, 400, { success: false, message: "email, otp, new_password are required" });
    }

    if (!/^[^@]+@[^@]+\.[^@]+$/.test(email)) {
      return json(origin, 400, { success: false, message: "Invalid email format" });
    }

    if (otp.length !== 6 || !/^\d{6}$/.test(otp)) {
      return json(origin, 400, { success: false, message: "OTP must be 6 digits" });
    }

    const pwMsg = validateStrongPassword(new_password);
    if (pwMsg) return json(origin, 400, { success: false, message: pwMsg });

    // ✅ find professor by email
    const { data: prof, error: profErr } = await admin
      .from("professors")
      .select("id,email")
      .eq("email", email)
      .maybeSingle();

    if (profErr) return json(origin, 400, { success: false, message: profErr.message });
    if (!prof?.id) return json(origin, 404, { success: false, message: "Professor not found" });

    const professor_id = String(prof.id);

    const role = "professor";
    const purpose = "forgot_password";

    // ✅ get latest OTP row
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

    const now = new Date();
    const exp = new Date(row.expires_at);
    if (now > exp) return json(origin, 400, { success: false, message: "OTP expired. Please resend." });

    const attempts = Number(row.attempts ?? 0);
    if (attempts >= 5) {
      return json(origin, 429, { success: false, message: "Too many attempts. Please resend OTP." });
    }

    const targetEmail = String(row.target_email ?? "").trim().toLowerCase();
    if (!targetEmail) return json(origin, 400, { success: false, message: "Missing target email. Please request OTP again." });

    // ✅ hash check (professor_id + targetEmail + otp)
    const expected = String(row.otp_hash ?? "");
    const got = await sha256(`${professor_id}|${targetEmail}|${otp}`);

    if (got !== expected) {
      await admin
        .from("password_reset_otps")
        .update({ attempts: attempts + 1 })
        .eq("id", row.id);

      return json(origin, 400, { success: false, message: "Invalid OTP." });
    }

    // ✅ reset password in Supabase Auth
    const { error: upErr } = await admin.auth.admin.updateUserById(professor_id, { password: new_password });
    if (upErr) return json(origin, 400, { success: false, message: upErr.message });

    // ✅ consume OTP
    await admin.from("password_reset_otps").update({ used_at: now.toISOString() }).eq("id", row.id);

    return json(origin, 200, { success: true, message: "Password reset successful." });
  } catch (e) {
    return json(origin, 400, { success: false, message: String(e) });
  }
});
