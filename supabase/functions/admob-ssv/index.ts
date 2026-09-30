// Brainlix — vérification côté serveur des pubs récompensées AdMob (SSV).
// Google appelle cette URL (GET) quand une pub est vue en entier. On vérifie la signature ECDSA de Google avec ses
// clés publiques, puis on enregistre la vue (`ad_ssv_record`, clé de service). La récompense elle-même est donnée
// par `ad_claim`, à la demande de l'app. Déployée sans vérification JWT : c'est Google qui appelle, pas un joueur.
// Doc : https://developers.google.com/admob/ios/ssv

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

function base64UrlDecode(value: string): Uint8Array {
  const b64 = value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (value.length % 4)) % 4);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// Signature DER (SEQUENCE { INTEGER r, INTEGER s }) → format brut r‖s de 64 octets attendu par WebCrypto.
function derToRaw(der: Uint8Array): Uint8Array {
  let i = 2;
  if (der[1] & 0x80) i = 2 + (der[1] & 0x7f);
  const read = () => {
    if (der[i] !== 0x02) throw new Error("bad der");
    const len = der[i + 1];
    let int = der.slice(i + 2, i + 2 + len);
    i += 2 + len;
    while (int.length > 32 && int[0] === 0) int = int.slice(1);
    const out = new Uint8Array(32);
    out.set(int, 32 - int.length);
    return out;
  };
  const r = read();
  const s = read();
  const raw = new Uint8Array(64);
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

async function verify(query: string, params: URLSearchParams): Promise<boolean> {
  const cut = query.indexOf("&signature=");
  const signature = params.get("signature");
  const keyId = params.get("key_id");
  if (cut < 0 || !signature || !keyId) return false;
  const message = new TextEncoder().encode(query.slice(0, cut));
  const raw = derToRaw(base64UrlDecode(signature));
  let key = (await verifierKeys()).get(keyId);
  if (!key) key = (await verifierKeys(true)).get(keyId);  // rotation des clés Google
  if (!key) return false;
  return crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, raw, message);
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const query = url.search.startsWith("?") ? url.search.slice(1) : url.search;
  const params = url.searchParams;
  // Vérification de l'URL par la console AdMob, sans paramètres : on répond simplement 200.
  if (!params.has("signature")) return new Response("ok");

  let valid = false;
  try {
    valid = await verify(query, params);
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
