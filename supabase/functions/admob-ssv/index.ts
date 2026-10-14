// Brainlix — vérification côté serveur des pubs récompensées AdMob (SSV).
// Google appelle cette URL (GET) quand une pub est vue en entier. On vérifie la signature ECDSA de Google avec ses
// clés publiques, puis on enregistre la vue (`ad_ssv_record`, clé de service). La récompense elle-même est donnée
// par `ad_claim`, à la demande de l'app. Déployée sans vérification JWT : c'est Google qui appelle, pas un joueur.
// Doc : https://developers.google.com/admob/ios/ssv

import { verifyQuery } from "./ssv.ts";

const KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const KEYS_TTL_MS = 12 * 60 * 60 * 1000;

let cachedKeys: { at: number; keys: Map<string, CryptoKey> } | null = null;

async function verifierKeys(force = false): Promise<Map<string, CryptoKey>> {
  if (!force && cachedKeys && Date.now() - cachedKeys.at < KEYS_TTL_MS) return cachedKeys.keys;
  const response = await fetch(KEYS_URL);
  if (!response.ok) throw new Error(`keys ${response.status}`);
  const body = await response.json() as { keys: { keyId: number; base64: string }[] };
  const keys = new Map<string, CryptoKey>();
  for (const k of body.keys) {
    const der = Uint8Array.from(atob(k.base64), (c) => c.charCodeAt(0));
    keys.set(String(k.keyId), await crypto.subtle.importKey("spki", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]));
  }
  cachedKeys = { at: Date.now(), keys };
  return keys;
}

async function verify(query: string): Promise<boolean> {
  return verifyQuery(query, async (keyId) => (await verifierKeys()).get(keyId) ?? (await verifierKeys(true)).get(keyId));  // rotation des clés Google
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const query = url.search.startsWith("?") ? url.search.slice(1) : url.search;
  const params = url.searchParams;
  // Vérification de l'URL par la console AdMob, sans paramètres : on répond simplement 200.
  if (!params.has("signature")) return new Response("ok");

  let valid = false;
  try {
    valid = await verify(query);
  } catch (error) {
    console.error("verify", error);
  }
  if (!valid) return new Response("invalid signature", { status: 403 });

  const response = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/ad_ssv_record`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""}`,
    },
    body: JSON.stringify({
      p_transaction: params.get("transaction_id"),
      p_user: params.get("user_id") ?? "",
      p_ad_unit: params.get("ad_unit") ?? "",
      p_custom: params.get("custom_data") ?? "",
    }),
  });
  if (!response.ok) {
    console.error("record", response.status, await response.text());
    return new Response("error", { status: 500 });  // Google réessaiera
  }
  return new Response("ok");
});
