// Vérification de la signature des pubs récompensées AdMob (SSV), sans dépendance à Deno (testée par scripts/test-ssv.mjs).
// Google signe la chaîne de requête *décodée* (custom_data « free_chest: » et non « free_chest%3A »), jusqu'à « &signature= ».

export function base64UrlDecode(value: string): Uint8Array {
  const b64 = value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (value.length % 4)) % 4);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// Signature DER (SEQUENCE { INTEGER r, INTEGER s }) → format brut r‖s de 64 octets attendu par WebCrypto.
export function derToRaw(der: Uint8Array): Uint8Array {
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

// Textes signés possibles : la requête décodée (ce que Google signe), puis la requête brute par prudence.
export function signedMessages(query: string): string[] {
  const cut = query.indexOf("&signature=");
  if (cut < 0) return [];
  const raw = query.slice(0, cut);
  let decoded = raw;
  try {
    decoded = decodeURIComponent(raw);
  } catch {
    // Encodage invalide : seule la version brute est essayée.
  }
  return decoded === raw ? [raw] : [decoded, raw];
}

export async function verifyQuery(query: string, getKey: (keyId: string) => Promise<CryptoKey | undefined>): Promise<boolean> {
  const params = new URLSearchParams(query);
  const signature = params.get("signature");
  const keyId = params.get("key_id");
  const messages = signedMessages(query);
  if (!signature || !keyId || messages.length === 0) return false;
  const key = await getKey(keyId);
  if (!key) return false;
  const raw = derToRaw(base64UrlDecode(signature));
  for (const message of messages) {
    if (await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, raw, new TextEncoder().encode(message))) return true;
  }
  return false;
}
