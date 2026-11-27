// Vérifie les règles de sécurité de MifBudget avec l'émulateur Firestore.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection,
  arrayUnion, Timestamp, query, where,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'mifbudget-test',
  firestore: { rules: readFileSync('../../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
});
const eudokia = env.authenticatedContext('uid-eudokia').firestore();
const awa = env.authenticatedContext('uid-awa').firestore();
const intrus = env.authenticatedContext('uid-intrus').firestore();
const anonyme = env.unauthenticatedContext().firestore();
const F = 'foyer1';
let passed = 0;
async function check(name, fn) { await fn(); passed++; console.log('ok -', name); }

await check('création du foyer par son seul membre', async () => {
  await assertFails(setDoc(doc(intrus, 'foyers/autre'), { membres: ['uid-eudokia'], noms: {} }));
  await assertSucceeds(setDoc(doc(eudokia, `foyers/${F}`), {
    nom: 'Foyer', membres: ['uid-eudokia'], noms: { 'uid-eudokia': 'Eudokia' },
  }));
});
await check('données communes : membre oui, autres non', async () => {
  await assertSucceeds(setDoc(doc(eudokia, `foyers/${F}/operations/o1`), { montant: 15000 }));
  await assertFails(getDoc(doc(intrus, `foyers/${F}/operations/o1`)));
  await assertFails(getDoc(doc(anonyme, `foyers/${F}/operations/o1`)));
  await assertFails(setDoc(doc(intrus, `foyers/${F}/operations/o2`), { montant: 1 }));
  await assertFails(getDoc(doc(intrus, `foyers/${F}`)));
  await assertFails(getDocs(collection(intrus, 'foyers')));
});
await check('données privées : leur propriétaire seulement', async () => {
  await assertSucceeds(setDoc(doc(eudokia, `foyers/${F}/prive/uid-eudokia/operations/p1`), { montant: 8000 }));
  await assertFails(setDoc(doc(eudokia, `foyers/${F}/prive/uid-awa/operations/p2`), { montant: 1 }));
});
await check('invitation : créée par un membre, illisible en liste', async () => {
  const expire = Timestamp.fromMillis(Date.now() + 7 * 86400e3);
  await assertFails(setDoc(doc(intrus, 'invitations/INTRUS22'), { foyer: F, creePar: 'uid-intrus', expire }));
  await assertSucceeds(setDoc(doc(eudokia, 'invitations/ABCD2345'), { foyer: F, creePar: 'uid-eudokia', expire }));
  await assertFails(getDocs(collection(awa, 'invitations')));
  await assertSucceeds(getDoc(doc(awa, 'invitations/ABCD2345')));
  // Une invitation expirée.
  await assertSucceeds(setDoc(doc(eudokia, 'invitations/VIEUX234'), {
    foyer: F, creePar: 'uid-eudokia', expire: Timestamp.fromMillis(Date.now() - 1000),
  }));
});
await check('rejoindre : code valide obligatoire, soi-même seulement', async () => {
  const ref = doc(awa, `foyers/${F}`);
  await assertFails(updateDoc(ref, { membres: arrayUnion('uid-awa'), 'noms.uid-awa': 'Awa', codeUtilise: 'FAUX2345' }));
  await assertFails(updateDoc(ref, { membres: arrayUnion('uid-awa'), 'noms.uid-awa': 'Awa', codeUtilise: 'VIEUX234' }));
  await assertFails(updateDoc(ref, { membres: arrayUnion('uid-awa', 'uid-intrus'), 'noms.uid-awa': 'Awa', codeUtilise: 'ABCD2345' }));
  await assertFails(updateDoc(ref, { membres: arrayUnion('uid-awa'), 'noms.uid-eudokia': 'X', codeUtilise: 'ABCD2345' }));
  await assertFails(updateDoc(ref, { membres: arrayUnion('uid-awa'), nom: 'Pirate', codeUtilise: 'ABCD2345' }));
  await assertSucceeds(updateDoc(ref, { membres: arrayUnion('uid-awa'), 'noms.uid-awa': 'Awa', codeUtilise: 'ABCD2345' }));
  await assertSucceeds(deleteDoc(doc(awa, 'invitations/ABCD2345')));
});
await check('après adhésion : commun partagé, privé toujours protégé', async () => {
  await assertSucceeds(getDoc(doc(awa, `foyers/${F}/operations/o1`)));
  await assertSucceeds(setDoc(doc(awa, `foyers/${F}/operations/o3`), { montant: 2000 }));
  await assertFails(getDoc(doc(awa, `foyers/${F}/prive/uid-eudokia/operations/p1`)));
  await assertFails(getDocs(collection(awa, `foyers/${F}/prive/uid-eudokia/operations`)));
  await assertSucceeds(getDocs(collection(eudokia, `foyers/${F}/prive/uid-eudokia/operations`)));
  await assertSucceeds(setDoc(doc(awa, `foyers/${F}/prive/uid-awa/operations/q1`), { montant: 500 }));
  await assertFails(getDoc(doc(eudokia, `foyers/${F}/prive/uid-awa/operations/q1`)));
});
await check('un membre ne peut pas retirer ou ajouter de membre', async () => {
  await assertFails(updateDoc(doc(awa, `foyers/${F}`), { membres: ['uid-awa'] }));
  await assertFails(updateDoc(doc(eudokia, `foyers/${F}`), { membres: arrayUnion('uid-intrus') }));
  await assertSucceeds(updateDoc(doc(eudokia, `foyers/${F}`), { nom: 'Foyer Eudokia et Awa' }));
  await assertFails(deleteDoc(doc(eudokia, `foyers/${F}`)));
});
await check('l\'intrus ne peut pas rejoindre avec un code déjà utilisé', async () => {
  await assertFails(updateDoc(doc(intrus, `foyers/${F}`), {
    membres: arrayUnion('uid-intrus'), 'noms.uid-intrus': 'X', codeUtilise: 'ABCD2345',
  }));
});
await env.cleanup();
console.log(`${passed} vérifications réussies`);
