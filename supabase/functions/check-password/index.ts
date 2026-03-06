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

  const PROJECT_URL = Deno.env.get("PROJECT_URL");
  const ANON_KEY = Deno.env.get("ANON_KEY");
  if (!PROJECT_URL || !ANON_KEY) {
    return json(origin, 500, { success: false, message: "Missing env PROJECT_URL/ANON_KEY" });
  }

  const authHeader = req.headers.get("authorization") ?? "";

  const authed = createClient(PROJECT_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  try {
    const body = await req.json();
    const professor_id = String(body.professor_id ?? "").trim();
    const current_password = String(body.current_password ?? "").trim();

    if (!professor_id || !current_password) {
      return json(origin, 400, { success: false, message: "professor_id and current_password are required" });
    }

    // verify JWT user
    const { data: u, error: uErr } = await authed.auth.getUser();
    if (uErr || !u?.user) return json(origin, 401, { success: false, message: "Not authenticated" });
    if (u.user.id !== professor_id) return json(origin, 403, { success: false, message: "Forbidden" });

    const email = (u.user.email ?? "").trim().toLowerCase();
    if (!email) return json(origin, 400, { success: false, message: "Missing auth email" });

    // validate password by trying sign-in
    const checkClient = createClient(PROJECT_URL, ANON_KEY, { auth: { persistSession: false } });
    const { error: signErr } = await checkClient.auth.signInWithPassword({
      email,
      password: current_password,
    });

    if (signErr) {
      return json(origin, 400, { success: false, message: "Incorrect current password" });
    }

    return json(origin, 200, { success: true, message: "Password ok" });
  } catch (e) {
    return json(origin, 400, { success: false, message: String(e) });
  }
});
