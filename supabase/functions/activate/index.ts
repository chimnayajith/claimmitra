import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});
const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes))
  .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
const hex = (bytes: Uint8Array) => Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");

async function sha256Hex(value: string): Promise<string> {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))));
}

async function signPayload(payload: Record<string, unknown>): Promise<string> {
  const encodedPrivateKey = Deno.env.get("LICENSE_PRIVATE_KEY_PKCS8_B64");
  if (!encodedPrivateKey) throw new Error("Server signing key is not configured");
  const keyBytes = Uint8Array.from(atob(encodedPrivateKey), (c) => c.charCodeAt(0));
  const privateKey = await crypto.subtle.importKey("pkcs8", keyBytes, { name: "Ed25519" }, false, ["sign"]);
  const payloadBytes = new TextEncoder().encode(JSON.stringify(payload));
  const signature = new Uint8Array(await crypto.subtle.sign("Ed25519", privateKey, payloadBytes));
  return `${b64url(payloadBytes)}.${b64url(signature)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { license_key, machine_hash } = await req.json();
    if (typeof license_key !== "string" || license_key.trim().length < 12 ||
        typeof machine_hash !== "string" || !/^[a-f0-9]{64}$/.test(machine_hash)) {
      return json({ error: "A valid licence key and device fingerprint are required." }, 400);
    }

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const keyHash = await sha256Hex(license_key.trim().toUpperCase());
    const { data: licence, error } = await supabase.from("licenses")
      .select("id, customer_name, status, machine_hash, activated_at")
      .eq("key_hash", keyHash).maybeSingle();
    if (error) throw error;
    if (!licence || licence.status !== "active") return json({ error: "This licence key is invalid or revoked." }, 403);

    let boundMachine = licence.machine_hash as string | null;
    let activatedAt = licence.activated_at as string | null;
    if (boundMachine && boundMachine !== machine_hash) {
      return json({ error: "This licence is already activated on another computer. Contact ClaimMitra support for a transfer." }, 409);
    }

    if (!boundMachine) {
      const now = new Date().toISOString();
      // Conditional update prevents two computers winning a first-activation race.
      const { data: updated, error: updateError } = await supabase.from("licenses")
        .update({ machine_hash, activated_at: now })
        .eq("id", licence.id).is("machine_hash", null).eq("status", "active")
        .select("machine_hash, activated_at").maybeSingle();
      if (updateError) throw updateError;
      if (updated) {
        boundMachine = updated.machine_hash;
        activatedAt = updated.activated_at;
      } else {
        const { data: latest, error: latestError } = await supabase.from("licenses")
          .select("status, machine_hash, activated_at").eq("id", licence.id).maybeSingle();
        if (latestError) throw latestError;
        if (!latest || latest.status !== "active" || latest.machine_hash !== machine_hash) {
          return json({ error: "This licence was activated on another computer first." }, 409);
        }
        boundMachine = latest.machine_hash;
        activatedAt = latest.activated_at;
      }
    }

    const issuedAt = new Date().toISOString();
    const payload = {
      product: "ClaimMitra",
      license_id: licence.id,
      customer_name: licence.customer_name,
      machine_hash: boundMachine,
      issued_at: issuedAt,
      activated_at: activatedAt ?? issuedAt,
      license_type: "perpetual",
      schema_version: 1,
    };
    const license_token = await signPayload(payload);
    return json({ license_token, customer_name: licence.customer_name });
  } catch (error) {
    console.error("Activation error", error);
    return json({ error: "Activation service error. Please try again later." }, 500);
  }
});
