// Vérification des JWS signés par Apple (StoreKit 2 et notifications serveur v2), sans dépendance.
// Le JWS porte sa chaîne de certificats (en-tête x5c : feuille, intermédiaire, racine). On vérifie :
//   · la racine est bien « Apple Root CA - G3 » (empreinte SHA-256 épinglée) ;
//   · l'intermédiaire est signé par la racine, la feuille par l'intermédiaire, chacun valide à la date de signature ;
//   · les extensions Apple : intermédiaire WWDR (1.2.840.113635.100.6.2.1), feuille « App Store » (1.2.840.113635.100.6.11.1) ;
//   · la signature ES256 du JWS avec la clé de la feuille.
// Même logique que la bibliothèque officielle d'Apple (app-store-server-library).

export const APPLE_ROOT_CA_G3_SHA256 = "63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179";

const OID_LEAF = "1.2.840.113635.100.6.11.1";
const OID_INTERMEDIATE = "1.2.840.113635.100.6.2.1";
const CURVES: Record<string, { name: string; size: number }> = {
  "1.2.840.10045.3.1.7": { name: "P-256", size: 32 },
  "1.3.132.0.34": { name: "P-384", size: 48 },
};
const HASHES: Record<string, string> = {
  "1.2.840.10045.4.3.2": "SHA-256",
  "1.2.840.10045.4.3.3": "SHA-384",
};

// ─────────────────────────────────────────── DER

interface Tlv { tag: number; start: number; contentStart: number; end: number }

function readTlv(der: Uint8Array, offset: number): Tlv {
  const tag = der[offset];
  let length = der[offset + 1];
  let contentStart = offset + 2;
  if (length & 0x80) {
    const count = length & 0x7f;
    if (count < 1 || count > 4) throw new Error("der: longueur invalide");
    length = 0;
    for (let i = 0; i < count; i++) length = length * 256 + der[offset + 2 + i];
    contentStart += count;
  }
  const end = contentStart + length;
  if (end > der.length) throw new Error("der: tronqué");
  return { tag, start: offset, contentStart, end };
}

function children(der: Uint8Array, parent: Tlv): Tlv[] {
  const list: Tlv[] = [];
  let offset = parent.contentStart;
  while (offset < parent.end) {
    const child = readTlv(der, offset);
    list.push(child);
    offset = child.end;
  }
  return list;
}

function oid(der: Uint8Array, t: Tlv): string {
  const bytes = der.subarray(t.contentStart, t.end);
  const parts = [Math.floor(bytes[0] / 40), bytes[0] % 40];
  let value = 0;
  for (let i = 1; i < bytes.length; i++) {
    value = value * 128 + (bytes[i] & 0x7f);
    if (!(bytes[i] & 0x80)) {
      parts.push(value);
      value = 0;
    }
  }
  return parts.join(".");
}

function time(der: Uint8Array, t: Tlv): number {
  const text = new TextDecoder().decode(der.subarray(t.contentStart, t.end));
  const full = t.tag === 0x17 ? (Number(text.slice(0, 2)) >= 50 ? "19" : "20") + text : text;  // UTCTime : AA → AAAA
  const iso = `${full.slice(0, 4)}-${full.slice(4, 6)}-${full.slice(6, 8)}T${full.slice(8, 10)}:${full.slice(10, 12)}:${full.slice(12, 14)}Z`;
  return Date.parse(iso);
}

export interface Certificate {
  der: Uint8Array;
  tbs: Uint8Array;
  signatureHash: string;
  signature: Uint8Array;
  spki: Uint8Array;
  curve: { name: string; size: number };
  notBefore: number;
  notAfter: number;
  extensions: Set<string>;
}

export function parseCertificate(der: Uint8Array): Certificate {
  const root = readTlv(der, 0);
  const [tbsTlv, algTlv, sigTlv] = children(der, root);
  const tbsFields = children(der, tbsTlv);
  let i = tbsFields[0].tag === 0xa0 ? 1 : 0;  // version explicite
  i += 2;  // numéro de série, algorithme
  i += 1;  // émetteur
  const validity = children(der, tbsFields[i++]);
  i += 1;  // sujet
  const spkiTlv = tbsFields[i++];
  const spkiAlg = children(der, children(der, spkiTlv)[0]);
  const curve = CURVES[oid(der, spkiAlg[1])];
  if (!curve) throw new Error("certificat : courbe non prise en charge");
  const extensions = new Set<string>();
  for (; i < tbsFields.length; i++) {
    if (tbsFields[i].tag !== 0xa3) continue;
    const list = children(der, children(der, tbsFields[i])[0]);
    for (const ext of list) extensions.add(oid(der, children(der, ext)[0]));
  }
  const signatureHash = HASHES[oid(der, children(der, algTlv)[0])];
  if (!signatureHash) throw new Error("certificat : algorithme non pris en charge");
  return {
    der,
    tbs: der.subarray(tbsTlv.start, tbsTlv.end),
    signatureHash,
    signature: der.subarray(sigTlv.contentStart + 1, sigTlv.end),  // BIT STRING : 1er octet = bits inutilisés
    spki: der.subarray(spkiTlv.start, spkiTlv.end),
    curve,
    notBefore: time(der, validity[0]),
    notAfter: time(der, validity[1]),
    extensions,
  };
}

/// Signature ECDSA DER (SEQUENCE { r, s }) → r ‖ s (format de WebCrypto).
function derSignatureToRaw(der: Uint8Array, size: number): Uint8Array {
  const seq = readTlv(der, 0);
  const [r, s] = children(der, seq);
  const raw = new Uint8Array(2 * size);
  const put = (t: Tlv, at: number) => {
    let bytes = der.subarray(t.contentStart, t.end);
    while (bytes.length > size && bytes[0] === 0) bytes = bytes.subarray(1);
    if (bytes.length > size) throw new Error("signature invalide");
    raw.set(bytes, at + size - bytes.length);
  };
  put(r, 0);
  put(s, size);
  return raw;
}

// ─────────────────────────────────────────── Vérifications

const subtle = globalThis.crypto.subtle;

function importKey(cert: Certificate): Promise<CryptoKey> {
  return subtle.importKey("spki", cert.spki, { name: "ECDSA", namedCurve: cert.curve.name }, false, ["verify"]);
}

async function signedBy(child: Certificate, issuer: Certificate): Promise<boolean> {
  const raw = derSignatureToRaw(child.signature, issuer.curve.size);
  return subtle.verify({ name: "ECDSA", hash: child.signatureHash }, await importKey(issuer), raw, child.tbs);
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = new Uint8Array(await subtle.digest("SHA-256", bytes));
  return Array.from(digest, (b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();
}

function base64UrlDecode(text: string): Uint8Array {
  const b64 = text.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(text.length / 4) * 4, "=");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function base64Decode(text: string): Uint8Array {
  return Uint8Array.from(atob(text), (c) => c.charCodeAt(0));
}

/// Vérifie un JWS signé par Apple et renvoie son contenu. Lève une erreur sinon.
/// `rootSha256` : empreinte de la racine attendue (celle d'Apple ; une autre seulement dans les tests).
export async function verifyAppleJws(token: string, rootSha256 = APPLE_ROOT_CA_G3_SHA256): Promise<Record<string, unknown>> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("jws : format");
  const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[1])));
  if (header.alg !== "ES256") throw new Error("jws : algorithme");
  if (!Array.isArray(header.x5c) || header.x5c.length !== 3) throw new Error("jws : chaîne de certificats");
  const [leaf, intermediate, root] = header.x5c.map((c: string) => parseCertificate(base64Decode(c)));

  if ((await sha256Hex(root.der)) !== rootSha256.replace(/:/g, "").toUpperCase()) throw new Error("jws : racine inconnue");
  if (!leaf.extensions.has(OID_LEAF) || !intermediate.extensions.has(OID_INTERMEDIATE)) throw new Error("jws : certificats non Apple");
  // Date de signature (les certificats d'Apple peuvent expirer après une transaction ancienne).
  const at = typeof payload.signedDate === "number" ? payload.signedDate : Date.now();
  for (const cert of [leaf, intermediate, root]) {
    if (at < cert.notBefore || at > cert.notAfter) throw new Error("jws : certificat expiré");
  }
  if (!(await signedBy(root, root)) || !(await signedBy(intermediate, root)) || !(await signedBy(leaf, intermediate))) {
    throw new Error("jws : chaîne invalide");
  }
  const signature = base64UrlDecode(parts[2]);
  const valid = await subtle.verify({ name: "ECDSA", hash: "SHA-256" }, await importKey(leaf), signature,
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!valid) throw new Error("jws : signature invalide");
  return payload;
}
