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

serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors(origin) });
  if (req.method !== "POST") return json(origin, 405, { success: false, message: "Method not allowed" });

  const PROJECT_URL = Deno.env.get("PROJECT_URL") ?? Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!PROJECT_URL || !SERVICE_ROLE_KEY) return json(origin, 500, { success: false, message: "Missing env" });

  const admin = createClient(PROJECT_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

  try {
    const body = await req.json().catch(() => ({}));
    const user_id = String(body.user_id ?? "").trim();

    if (!user_id) return json(origin, 400, { success: false, message: "user_id is required" });

    // reset attempts + clear lock-related timestamps
    const { error } = await admin
      .from("professors")
      .update({
        login_attempts: 0,
        last_failed_login_at: null,
        last_login_alert_at: null, // optional: remove cooldown after successful login
      })
      .eq("id", user_id);

    if (error) return json(origin, 400, { success: false, message: error.message });

    return json(origin, 200, { success: true, message: "Attempts reset." });
  } catch (e) {
    return json(origin, 400, { success: false, message: String(e) });
  }
});
