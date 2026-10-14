// Test de la vérification des pubs récompensées AdMob (supabase/functions/admob-ssv/ssv.ts).
// Google signe la requête décodée : « custom_data=free_chest: » alors que l'URL reçue contient « free_chest%3A ».
// Usage : node scripts/test-ssv.mjs
import assert from 'node:assert/strict';
import { verifyQuery, signedMessages } from '../supabase/functions/admob-ssv/ssv.ts';

const { subtle } = globalThis.crypto;
const keys = await subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);

// Signature au format de Google : DER, en base64 URL sans « = ».
function rawToDer(raw) {
  const int = (b) => {
    let i = 0;
    while (i < b.length - 1 && b[i] === 0) i++;
    b = b.slice(i);
    return b[0] & 0x80 ? [0x02, b.length + 1, 0, ...b] : [0x02, b.length, ...b];
  };
  const body = [...int(raw.slice(0, 32)), ...int(raw.slice(32))];
  return new Uint8Array([0x30, body.length, ...body]);
}
async function googleSign(message) {
  const raw = new Uint8Array(await subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, keys.privateKey, new TextEncoder().encode(message)));
  return Buffer.from(rawToDer(raw)).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
const getKey = async (id) => (id === '42' ? keys.publicKey : undefined);

const encoded = 'ad_network=5450213213286189855&ad_unit=9555262634&custom_data=free_chest%3A&reward_amount=1&reward_item=Reward'
  + '&timestamp=1791976448576&transaction_id=00065dcb0690011e021c4baa8b346893&user_id=00000000-0000-4000-8000-000000000001';
const decoded = decodeURIComponent(encoded);

// Cas réel : signé sur la version décodée, reçu codé.
const sig = await googleSign(decoded);
assert.equal(await verifyQuery(`${encoded}&signature=${sig}&key_id=42`, getKey), true, 'requête codée, signée décodée : acceptée');
// Sans caractère codé : identique.
const plain = encoded.replace('free_chest%3A', 'streak_rescue');
assert.equal(await verifyQuery(`${plain}&signature=${await googleSign(plain)}&key_id=42`, getKey), true, 'sans caractère codé : acceptée');
// Fausses vues : refusées.
assert.equal(await verifyQuery(`${encoded.replace('reward_amount=1', 'reward_amount=9')}&signature=${sig}&key_id=42`, getKey), false, 'requête modifiée : refusée');
assert.equal(await verifyQuery(`${encoded}&signature=${sig}&key_id=7`, getKey), false, 'clé inconnue : refusée');
assert.equal(await verifyQuery(encoded, getKey), false, 'sans signature : refusée');
assert.deepEqual(signedMessages(`a=b%3A&signature=x`), ['a=b:', 'a=b%3A']);
console.log('ok   vérification des pubs AdMob (SSV)');
