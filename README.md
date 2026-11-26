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

**Étape 2 : vision claire des revenus** (faite, version 0.2.0)
- Accueil : carte « Revenus du mois » avec le total, l'écart avec le mois précédent, la répartition par source et la part déjà dépensée (ou le dépassement).
- Onglet Rapports, « Bilan du mois » : revenus, dépenses et reste ; revenus par source comparés au mois précédent ; revenus et dépenses sur 6 mois (toucher un mois pour l'afficher) ; dépenses par catégorie ; détail des revenus.

**Étape 3 : suivi de l'épargne** (version 0.4.0, revue après la 0.3.0)
- Portefeuilles multiples (Réglages ou tuiles de l'Accueil) : nom, type (espèces, banque, Mobile Money), rôle (courant ou épargne), commun au foyer ou personnel, privé ou visible, solde de départ, archivage.
- Épargner = virer d'un compte courant vers un compte épargne (onglet « Épargne » de la saisie rapide, ou Verser / Retirer). Disponible = comptes courants ; total épargné = comptes épargne.
- Objectifs (sûreté, construction…) rattachés à un compte épargne : un seul objectif a tout le solde du compte ; plusieurs se partagent le compte (part de départ + virements marqués), le reste est « non réparti ».
- Onglet Épargnes : total épargné, épargne du mois, puis chaque compte avec ses objectifs (progression, reste, versement mensuel pour la date cible, mois de dépenses couverts pour la sûreté).
- Les épargnes saisies en 0.3.0 sont reprises automatiquement dans un « Compte épargne ».

**Étape 4 : statistiques et projections** (version 0.5.0)
- Rapports → « Tendances » : capacité d'épargne (revenus, dépenses et épargne moyens des 3 derniers mois complets, taux d'épargne, reste après dépenses), revenus et dépenses sur 12 mois, épargne mois par mois, dépenses moyennes par catégorie comparées aux 3 mois d'avant, projections des objectifs et des projets.
- Objectifs : date estimée au rythme actuel (sur la carte) et simulateur « Si je verse chaque mois… » dans le détail.
- Projets (onglet Épargnes et projets) : budget, mois prévu, objectif d'épargne qui le finance, état (prévu, en cours, terminé) ; dépenses rattachées depuis la saisie rapide ; reste à financer et date estimée.

**Budgets mensuels** (version 0.6.0)
- Onglet Budgets : plafond par catégorie et par mois (mois suivant préparable), total dépensé sur le budget, reste et jours restants, dépenses hors budget ; une ligne par catégorie avec barre verte (< 80 %), orange (80 à 100 %) ou rouge « Dépassé », toujours avec icône et libellé.
- Saisie des plafonds : montant proposé sous chaque catégorie (moyenne des 3 mois précédents, arrondie au millier), bouton « Proposer les plafonds », copie des plafonds du mois précédent sans écraser.
- Après une dépense, la confirmation prévient si la catégorie atteint 80 % ou dépasse son plafond ; l'Accueil affiche « Budgets à surveiller ».

**Gestion des catégories** (version 0.7.0)
- Réglages → « Catégories et sous-catégories » (ou « Gérer les catégories » au bas de la liste « Autre » de la saisie) : dépenses par groupe (Essentiel, Confort, sans groupe) et revenus.
- Créer une catégorie (nom, groupe, icône parmi 36, couleur), la modifier (le groupe, l'icône et la couleur passent aux sous-catégories), l'archiver puis la restaurer ; noms en double refusés au même niveau.
- Sous-catégories : ajouter, renommer, archiver, restaurer.
- Archiver ne supprime rien : les opérations déjà saisies gardent leur catégorie et restent comptées.

Suite possible : opérations récurrentes, argent personnel, synchronisation Firebase entre les deux téléphones.

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
