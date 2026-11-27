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

**Opérations récurrentes** (version 0.8.0)
- Mensuelles : dépense, revenu, virement d'épargne ou transfert, le jour J de chaque mois (le dernier jour pour les mois plus courts), à partir d'un mois, jusqu'à un mois facultatif.
- « À confirmer » par défaut : le jour venu, l'Accueil la propose avec Confirmer / Ignorer (toucher la ligne pour ajuster le montant ou la date) ; « automatique » en option. Rattrapage des échéances manquées à l'ouverture, sans doublon ; « Annuler » juste après rend l'échéance à nouveau à confirmer.
- Création depuis Réglages → Opérations récurrentes (saisie habituelle puis calendrier) ou depuis une opération déjà saisie (« Rendre récurrente », qui devient l'échéance de son mois). Pause, arrêt, reprise.
- Accueil : « À confirmer » et « À venir » (30 jours) ; carte Revenus : revenus attendus du mois ; Budgets : dépenses récurrentes encore prévues.
- Pas de notifications (choix du foyer).

**Argent personnel** (version 0.9.0)
- Réglages → Argent personnel : montant mensuel, jour, portefeuille commun d'où part le versement, portefeuille personnel qui le reçoit (« Créer Porte-monnaie » en un toucher). Versement « à confirmer » chaque mois, montant modifiable ; compté comme dépense du foyer (catégorie Argent personnel).
- Argent personnel réparti sur un ou plusieurs portefeuilles personnels (porte-monnaie, Mobile Money perso) ; le disponible du foyer ne compte que les portefeuilles communs.
- Saisie avec un portefeuille personnel : « Pour : moi (privé) · moi (visible) · le foyer ». Les dépenses perso ne comptent pas dans les chiffres du foyer (le versement y est déjà).
- « Mon argent personnel » (Accueil), visible par soi seul : reste, reçu et dépensé du mois, détail par portefeuille, par catégorie, mois par mois, dépenses privées ou visibles.
- Plus tard : interrupteur « Avance sur mon argent personnel » (voir CLAUDE.md).

**Synchronisation entre les deux téléphones** (version 1.0.0)
- Réglages → Partage du foyer : « Créer le foyer partagé » (connexion Google, les données du téléphone deviennent celles du foyer), puis « Inviter mon conjoint » (code de 8 caractères, valable 7 jours, une seule fois).
- Sur l'autre téléphone, dès la première ouverture : « Rejoindre le foyer de mon conjoint » avec le code.
- Fonctionne hors connexion (cache Firestore) : les saisies partent dès que le réseau revient. Prénom de l'auteur affiché sur les opérations de l'autre.
- Confidentialité côté serveur : portefeuilles privés et dépenses perso privées dans `foyers/{id}/prive/{membre}`, lisibles par leur seul propriétaire (`firestore.rules`).
- Verrouillage : code à 4 chiffres (et empreinte en option), demandé à l'ouverture et après 5 minutes hors de l'application.

**Logo et écran de chargement** (version 1.0.1)
- Logo « le duo » : un « m » fait de deux arches, verte et orange, qui se chevauchent, sur un vert profond.
- Icône adaptative (rond, carré arrondi… selon le téléphone) avec version d'une seule couleur pour les icônes thématiques d'Android 13+.
- Écran de chargement vert profond avec le logo et « MifBudget · Le budget du foyer » (écran de démarrage du système sur Android 12+).
- Logo dans l'application : écran du code de verrouillage et première ouverture.

**Interface simplifiée** (version 1.0.2)
- Accueil plus court : ce qui est à confirmer, puis une seule carte pour le mois (argent disponible, entré, dépensé, reste) avec « Mes comptes », les budgets en alerte, l'argent personnel, l'épargne et les dernières opérations. Le détail des revenus est dans Rapports.
- Opérations : une seule ligne d'information sous chaque opération ; dépense perso signalée par une icône.
- Épargnes : une phrase par objectif, les calculs dans le détail.
- Réglages rangés : Mon foyer, Mon budget, Mes comptes, Sécurité, Apparence.
- Présentation en 3 écrans à la première ouverture (et une fois après la mise à jour), à revoir dans les Réglages.

### Firebase

- Projet `mifbudget`, configuration Android dans `android/app/google-services.json` (empreintes SHA-1 et SHA-256 de la clé de signature déclarées dans la console).
- Règles de sécurité : `firestore.rules`. Après toute modification, les publier (console Firebase → Firestore Database → Règles) et les vérifier :

```bash
cd tool/firestore-rules-test && npm install && npm test
```


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

Logo : sources SVG dans `tool/logo/` (`icon.svg`, calques `background.svg`, `foreground.svg`, `monochrome.svg`). Après modification, régénérer les images Android (icônes et écran de chargement) :

```bash
NODE_PATH=$(npm root -g) node tool/logo/render.js
```

Le même logo est dessiné dans l'application par `lib/ui/widgets/logo.dart` (à garder identique).

Captures d'écran de contrôle (jour et nuit) :

```bash
SHOTS_DIR=/chemin/vers/dossier flutter test tool/screenshots_test.dart
```
