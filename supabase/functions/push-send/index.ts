// Brainlix — envoi des notifications push (Apple APNs).
// Appelée chaque minute par pg_cron tant que des notifications sont dues. Elle ne fait que vider la file
// (`push_claim`) : l'appeler en trop ne peut rien envoyer de plus. Déployée sans vérification JWT.
// Secrets de la fonction (Supabase → Edge Functions → Secrets), jamais dans le dépôt :
//   APNS_KEY_ID      identifiant de la clé (10 caractères)
//   APNS_TEAM_ID     identifiant d'équipe Apple (BM85BF2WVQ)
//   APNS_PRIVATE_KEY contenu du fichier AuthKey_XXXX.p8 (avec les lignes BEGIN / END)
// Sans ces secrets, rien n'est envoyé (les notifications attendent dans la file 2 jours au plus).

const TOPIC = "app.brainlix.ios";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

let cachedJwt: { token: string; at: number } | null = null;

function b64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = "";
  raw.forEach((b) => (s += String.fromCharCode(b)));
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function apnsJwt(): Promise<string | null> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const pem = Deno.env.get("APNS_PRIVATE_KEY");
  if (!keyId || !teamId || !pem) return null;
  // Apple accepte un même jeton pendant 1 h ; on le renouvelle toutes les 50 min.
  if (cachedJwt && Date.now() - cachedJwt.at < 50 * 60 * 1000) return cachedJwt.token;
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = b64url(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
  const signature = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(`${header}.${claims}`)));
  const token = `${header}.${claims}.${b64url(signature)}`;
  cachedJwt = { token, at: Date.now() };
  return token;
}

async function rpc(name: string, args: Record<string, unknown>): Promise<unknown> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    body: JSON.stringify(args),
  });
  if (!response.ok) throw new Error(`${name} ${response.status} ${await response.text()}`);
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

type Item = {
  id: number;
  title: string;
  body: string;
  data: Record<string, unknown>;
  tokens: { token: string; environment: string }[];
};

Deno.serve(async () => {
  const jwt = await apnsJwt();
  if (!jwt) return new Response("APNs non configuré", { status: 200 });

  const items = (await rpc("push_claim", { p_limit: 200 })) as Item[];
  let sent = 0;
  for (const item of items) {
    let error: string | null = null;
    for (const { token, environment } of item.tokens) {
      const host = environment === "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
      try {
        const response = await fetch(`https://${host}/3/device/${token}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${jwt}`,
            "apns-topic": TOPIC,
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          body: JSON.stringify({ aps: { alert: { title: item.title, body: item.body }, sound: "default" }, ...item.data }),
        });
        if (response.ok) {
          sent++;
        } else {
          const reason = ((await response.json().catch(() => ({}))) as { reason?: string }).reason ?? `${response.status}`;
          if (response.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered") {
            await rpc("push_token_invalid", { p_token: token });
          } else {
            error = reason;
          }
        }
      } catch (e) {
        error = String(e);
      }
    }
    await rpc("push_done", { p_id: item.id, p_error: error });
  }
  return new Response(JSON.stringify({ claimed: items.length, sent }), { headers: { "Content-Type": "application/json" } });
});
