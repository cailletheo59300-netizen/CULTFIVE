// Règles d'un achat (Pass+ et produits de la boutique, transaction StoreKit 2 déjà vérifiée).
// Le serveur (iap_record) sait quels produits existent : ici on vérifie seulement qu'il s'agit d'un produit Brainlix.
export const BUNDLE_ID = "app.brainlix.ios";
export const PASS_PRODUCT = "app.brainlix.pass";
export const PRODUCT_PREFIX = "app.brainlix.";

export interface PassTransaction {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  environment: string;
  purchaseDate: number;
}

/// Contrôle le contenu d'une transaction pour le joueur `userId`. Renvoie l'achat, ou lève une erreur (code court).
export function checkTransaction(payload: Record<string, unknown>, userId: string): PassTransaction {
  if (payload.bundleId !== BUNDLE_ID) throw new Error("wrong_app");
  const productId = String(payload.productId ?? "");
  if (!productId.startsWith(PRODUCT_PREFIX)) throw new Error("wrong_product");
  if (payload.revocationDate != null) throw new Error("revoked");
  // L'app pose l'identifiant du joueur dans l'achat : un achat ne sert qu'au compte qui l'a fait.
  const token = typeof payload.appAccountToken === "string" ? payload.appAccountToken.toLowerCase() : null;
  if (token !== userId.toLowerCase()) throw new Error("wrong_account");
  const environment = String(payload.environment ?? "");
  if (!["Production", "Sandbox", "Xcode", "LocalTesting"].includes(environment)) throw new Error("wrong_environment");
  return {
    transactionId: String(payload.transactionId),
    originalTransactionId: String(payload.originalTransactionId ?? payload.transactionId),
    productId,
    environment,
    purchaseDate: Number(payload.purchaseDate),
  };
}

/// Notification serveur d'Apple : transaction à retirer (remboursement, révocation), ou null.
export function revokedTransaction(notification: Record<string, unknown>, transaction: Record<string, unknown> | null): string | null {
  const type = notification.notificationType;
  if ((type === "REFUND" || type === "REVOKE") && transaction?.transactionId) return String(transaction.transactionId);
  return null;
}
