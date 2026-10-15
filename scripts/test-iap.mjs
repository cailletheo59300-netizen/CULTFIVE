// Test de la vérification des achats Apple (supabase/functions/iap-verify).
// Fabrique une fausse chaîne « Apple » avec openssl (racine P-384, intermédiaire et feuille avec les extensions d'Apple),
// signe des transactions comme StoreKit 2, puis vérifie qu'elles passent, et que les falsifications échouent.
// Usage : node scripts/test-iap.mjs
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash, createPrivateKey, sign } from 'node:crypto';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { verifyAppleJws, APPLE_ROOT_CA_G3_SHA256 } from '../supabase/functions/iap-verify/jws.ts';
import { checkTransaction, revokedTransaction } from '../supabase/functions/iap-verify/pass.ts';

const dir = mkdtempSync(join(tmpdir(), 'iap-'));
const ssl = (...args) => execFileSync('openssl', args, { cwd: dir, stdio: ['ignore', 'pipe', 'pipe'] });
const ext = (name, body) => writeFileSync(join(dir, name), body);

function chain({ leafOid = '1.2.840.113635.100.6.11.1', interOid = '1.2.840.113635.100.6.2.1' } = {}) {
  ssl('ecparam', '-name', 'secp384r1', '-genkey', '-noout', '-out', 'root.key');
  ssl('req', '-x509', '-new', '-key', 'root.key', '-sha384', '-days', '3650', '-subj', '/CN=Test Root', '-out', 'root.pem');
  ssl('ecparam', '-name', 'secp384r1', '-genkey', '-noout', '-out', 'inter.key');
  ssl('req', '-new', '-key', 'inter.key', '-subj', '/CN=Test WWDR', '-out', 'inter.csr');
  ext('inter.ext', `basicConstraints=critical,CA:true\n${interOid}=ASN1:NULL\n`);
  ssl('x509', '-req', '-in', 'inter.csr', '-CA', 'root.pem', '-CAkey', 'root.key', '-CAcreateserial', '-sha384', '-days', '3650',
      '-extfile', 'inter.ext', '-out', 'inter.pem');
  ssl('ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', 'leaf.key');
  ssl('req', '-new', '-key', 'leaf.key', '-subj', '/CN=Test StoreKit', '-out', 'leaf.csr');
  ext('leaf.ext', `${leafOid}=ASN1:NULL\n`);
  ssl('x509', '-req', '-in', 'leaf.csr', '-CA', 'inter.pem', '-CAkey', 'inter.key', '-CAcreateserial', '-sha384', '-days', '3650',
      '-extfile', 'leaf.ext', '-out', 'leaf.pem');
  const der = (name) => ssl('x509', '-in', name, '-outform', 'der');
  const x5c = ['leaf.pem', 'inter.pem', 'root.pem'].map((n) => der(n).toString('base64'));
  const rootSha = createHash('sha256').update(der('root.pem')).digest('hex').toUpperCase();
  return { x5c, rootSha, key: createPrivateKey(readFileSync(join(dir, 'leaf.key'))) };
}

const b64u = (b) => Buffer.from(b).toString('base64url');
function jws(c, payload) {
  const head = b64u(JSON.stringify({ alg: 'ES256', x5c: c.x5c }));
  const body = b64u(JSON.stringify(payload));
  const sig = sign('sha256', Buffer.from(`${head}.${body}`), { key: c.key, dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${b64u(sig)}`;
}

const user = '6f9619ff-8b86-d011-b42d-00c04fc964ff';
const transaction = {
  transactionId: '2000000123', originalTransactionId: '2000000123', bundleId: 'app.brainlix.ios', productId: 'app.brainlix.passplus',
  type: 'Non-Renewing Subscription', purchaseDate: Date.now(), signedDate: Date.now() + 600_000, environment: 'Sandbox',
  appAccountToken: user.toUpperCase(),
};

try {
  const good = chain();
  const token = jws(good, transaction);

  // Une vraie transaction (racine de test) passe ; avec la racine d'Apple, notre fausse chaîne est refusée.
  const payload = await verifyAppleJws(token, good.rootSha);
  assert.equal(payload.transactionId, '2000000123');
  await assert.rejects(verifyAppleJws(token), /racine inconnue/);
  assert.equal(APPLE_ROOT_CA_G3_SHA256.length, 64);

  // Contenu modifié, signature d'une autre clé, en-tête trafiqué : refusés.
  const [h, , s] = token.split('.');
  await assert.rejects(verifyAppleJws(`${h}.${b64u(JSON.stringify({ ...transaction, productId: 'x' }))}.${s}`, good.rootSha), /signature/);
  const other = chain();
  await assert.rejects(verifyAppleJws(jws({ ...other, x5c: good.x5c }, transaction), good.rootSha), /signature/);
  await assert.rejects(verifyAppleJws(jws({ ...good, x5c: [good.x5c[0], other.x5c[1], good.x5c[2]] }, transaction), good.rootSha), /chaîne/);

  // Signée hors de la validité des certificats : refusée.
  await assert.rejects(verifyAppleJws(jws(good, { ...transaction, signedDate: Date.now() + 20 * 365 * 86_400_000 }), good.rootSha), /expiré/);

  // Certificats sans les extensions d'Apple : refusés.
  const plain = chain({ leafOid: '1.2.3.4' });
  await assert.rejects(verifyAppleJws(jws(plain, transaction), plain.rootSha), /non Apple/);

  // Règles du Pass+.
  const purchase = checkTransaction(payload, user);
  assert.equal(purchase.transactionId, '2000000123');
  assert.equal(purchase.environment, 'Sandbox');
  assert.throws(() => checkTransaction(payload, '00000000-0000-0000-0000-000000000000'), /wrong_account/);
  assert.throws(() => checkTransaction({ ...payload, appAccountToken: undefined }, user), /wrong_account/);
  assert.throws(() => checkTransaction({ ...payload, productId: 'autre' }, user), /wrong_product/);
  assert.throws(() => checkTransaction({ ...payload, bundleId: 'autre' }, user), /wrong_app/);
  assert.throws(() => checkTransaction({ ...payload, revocationDate: Date.now() }, user), /revoked/);

  // Notifications : remboursement → transaction à retirer ; le reste est ignoré.
  assert.equal(revokedTransaction({ notificationType: 'REFUND' }, payload), '2000000123');
  assert.equal(revokedTransaction({ notificationType: 'REVOKE' }, payload), '2000000123');
  assert.equal(revokedTransaction({ notificationType: 'CONSUMPTION_REQUEST' }, payload), null);
  const notification = await verifyAppleJws(jws(good, { notificationType: 'REFUND',
    data: { signedTransactionInfo: token }, signedDate: Date.now() + 600_000 }), good.rootSha);
  assert.equal(revokedTransaction(notification, await verifyAppleJws(notification.data.signedTransactionInfo, good.rootSha)), '2000000123');

  console.log('ok   vérification des achats Apple (Pass+)');
} finally {
  rmSync(dir, { recursive: true, force: true });
}
