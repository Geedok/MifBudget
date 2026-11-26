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

Captures d'écran de contrôle (jour et nuit) :

```bash
SHOTS_DIR=/chemin/vers/dossier flutter test tool/screenshots_test.dart
```
