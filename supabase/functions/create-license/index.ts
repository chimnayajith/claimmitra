import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-admin-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});
const hex = (bytes: Uint8Array) => Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
async function sha256Hex(value: string): Promise<string> {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const expectedSecret = Deno.env.get("LICENSE_ADMIN_SECRET");
  if (!expectedSecret || req.headers.get("x-admin-secret") !== expectedSecret) {
    return json({ error: "Unauthorized" }, 401);
  }
  try {
    const { customer_name, customer_email } = await req.json();
    if (typeof customer_name !== "string" || customer_name.trim().length < 2) {
      return json({ error: "Customer name is required." }, 400);
    }
    // Exclude ambiguous characters so keys are easier to read over the phone.
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const random = new Uint8Array(16);
    crypto.getRandomValues(random);
    const chars = Array.from(random, (byte) => alphabet[byte % alphabet.length]);
    const groups = [0, 4, 8, 12].map((start) => chars.slice(start, start + 4).join(""));
    const licenseKey = `CM-${groups.join("-")}`;
    const keyHash = await sha256Hex(licenseKey);
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data, error } = await supabase.from("licenses").insert({
      key_hash: keyHash,
      key_last4: groups[3],
      customer_name: customer_name.trim(),
      customer_email: typeof customer_email === "string" && customer_email.trim() ? customer_email.trim() : null,
    }).select("id, customer_name, customer_email, created_at").single();
    if (error) throw error;
    // The raw key is returned only once; only its SHA-256 hash is stored.
    return json({ license_key: licenseKey, license: data });
  } catch (error) {
    console.error("Create licence error", error);
    return json({ error: "Could not create the licence." }, 500);
  }
});
