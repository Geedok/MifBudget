# MifBudget

Application Android de budget familial (Flutter). Voir `CLAUDE.md` pour le cahier des charges.

## État d'avancement

**Étape 1 : saisie facile des dépenses** (faite)
- Installation au premier lancement : prénom et soldes de départ (Espèces, Banque, Mobile Money).
- Saisie rapide (bouton +) : montant au pavé numérique (touche 000), catégorie parmi les 7 plus utilisées (+ « Autre »), sous-catégorie facultative, portefeuille présélectionné (le dernier utilisé), date (aujourd'hui, hier ou autre), note. Dépense, revenu ou transfert.
- Confirmation avec « Annuler ».
- Accueil : solde total, revenus, dépenses et reste du mois, solde par portefeuille, dernières opérations.
- Opérations : liste par mois et par jour, modification au toucher, suppression en glissant (annulable).
- Réglages : prénom, thème (comme le téléphone, jour, nuit), noms et soldes de départ des portefeuilles.
- Données enregistrées sur le téléphone (fichier JSON). Firebase viendra ensuite.

Étapes suivantes : 2. vision claire des revenus · 3. suivi de l'épargne · 4. statistiques et projections.

## Développement

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

### Signature permanente

Les APK « release » sont signés avec une clé permanente (alias `mifbudget`), indispensable pour installer chaque mise à jour par-dessus la précédente sans perdre les données. Deux fichiers, **jamais versionnés** :

- `android/mifbudget-upload.jks` : la clé ;
- `android/key.properties` : son mot de passe (`storePassword`, `keyPassword`, `keyAlias=mifbudget`, `storeFile=mifbudget-upload.jks`).

Sans eux, `flutter build apk --release` s'arrête avec un message. Empreinte SHA-256 du certificat :
`1B:6F:2E:D6:DE:99:97:50:2D:A3:E8:F8:4D:D6:E7:37:0F:C1:64:5F:16:06:CB:8D:06:F1:5D:3E:CF:84:75:62`

Identifiant de l'application : `com.mifbudget.app` (ne plus le changer). Augmenter le numéro après le `+` de `version` dans `pubspec.yaml` à chaque nouvelle version distribuée.

Captures d'écran de contrôle (jour et nuit) :

```bash
SHOTS_DIR=/chemin/vers/dossier flutter test tool/screenshots_test.dart
```
