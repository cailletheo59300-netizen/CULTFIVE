// Brainlix — achats du Pass+ (StoreKit 2).
// Deux appelants :
//   · l'app (POST { signedTransaction }, avec le jeton du joueur) juste après un achat ou une restauration ;
//   · Apple (POST { signedPayload }) : notifications serveur v2, pour retirer un Pass+ remboursé.
// Tout ce qui est signé par Apple est vérifié (jws.ts) avant d'être cru. Déployée sans vérification JWT (Apple n'en
// envoie pas) : le joueur est identifié ici à partir de son jeton.

import { verifyAppleJws } from "./jws.ts";
import { checkTransaction, revokedTransaction } from "./pass.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

async function rpc(fn: string, params: Record<string, unknown>): Promise<Response> {
  return await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    body: JSON.stringify(params),
  });
}

/// Joueur connecté (jeton de session de l'app), ou null.
async function currentUser(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY, Authorization: auth } });
  if (!response.ok) return null;
  const user = await response.json() as { id?: string };
  return user.id ?? null;
}

async function handlePurchase(req: Request, signedTransaction: string): Promise<Response> {
  const user = await currentUser(req);
  if (!user) return json({ error: "not_authenticated" }, 401);
  let purchase;
  try {
    purchase = checkTransaction(await verifyAppleJws(signedTransaction), user);
  } catch (error) {
    console.error("purchase", user, String(error));
    return json({ error: error instanceof Error ? error.message : "invalid" }, 400);
  }
  const response = await rpc("pass_plus_record", {
    p_user: user,
    p_transaction: purchase.transactionId,
    p_original: purchase.originalTransactionId,
    p_product: purchase.productId,
    p_environment: purchase.environment,
    p_purchased_at: new Date(purchase.purchaseDate).toISOString(),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("record", response.status, JSON.stringify(body));
    const message = String((body as { message?: string }).message ?? "");
    return json({ error: message.split(/[: ]/)[0] || "record_failed" }, response.status >= 500 ? 500 : 400);
  }
  return json(body);
}

async function handleNotification(signedPayload: string): Promise<Response> {
  let notification: Record<string, unknown>;
  let transaction: Record<string, unknown> | null = null;
  try {
    notification = await verifyAppleJws(signedPayload);
    const data = notification.data as { signedTransactionInfo?: string; bundleId?: string } | undefined;
    if (data?.signedTransactionInfo) transaction = await verifyAppleJws(data.signedTransactionInfo);
  } catch (error) {
    console.error("notification", String(error));
    return json({ error: "invalid" }, 400);
  }
  const revoked = revokedTransaction(notification, transaction);
  if (revoked) {
    const response = await rpc("pass_plus_revoke", { p_transaction: revoked });
    if (!response.ok) {
      console.error("revoke", response.status, await response.text());
      return json({ error: "revoke_failed" }, 500);  // Apple réessaiera
    }
  }
  return json({ ok: true });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const body = await req.json().catch(() => null) as { signedTransaction?: string; signedPayload?: string } | null;
  if (body?.signedPayload) return await handleNotification(body.signedPayload);
  if (body?.signedTransaction) return await handlePurchase(req, body.signedTransaction);
  return json({ error: "bad_request" }, 400);
});
