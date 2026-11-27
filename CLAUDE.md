# MifBudget — instructions pour Claude Code

Application mobile Android de budget familial pour Eudokia et sa femme (deux utilisateurs, un foyer). Langue de l'app et des échanges : français. Devise : franc CFA (XOF), montants entiers, affichés « 125 000 FCFA ».

Références (à jour au 26/11/2026) :
- Cahier des charges complet : https://claude.ai/artifact/Lgbnou5TRSuPiExDb1nyMv
- Maquettes (Accueil, Saisie rapide, Épargnes et projets, Mon argent personnel, Budgets) : https://claude.ai/artifact/A3DG42xPYezNxgJZA2quUa (affichent encore l'ancien nom « Budgify » : le nom est MifBudget)
- Charte jour / nuit : https://claude.ai/artifact/PHXC5a4NFFQBa7BsAJvuX9

## Choix techniques

- Flutter (Android seulement en V1 ; les deux téléphones sont sous Android), distribution par APK ou Google Play.
- Firebase : Cloud Firestore avec persistance hors ligne + Firebase Authentication (connexion par compte Google), puis code PIN ou empreinte à l'ouverture.
- Identifiants générés sur le téléphone (UUID). Soldes jamais stockés : recalculés à partir des opérations. Suppression douce (champ supprimée), annulable 30 jours.
- Conflits : dernière modification gagne, historique conservé ; une suppression l'emporte sur une modification.

## Priorités du foyer (26/11/2026)

Ce qui compte le plus pour Eudokia, à garder en tête dans chaque choix :
1. Saisir une dépense facilement et vite (saisie rapide en quelques touches, catégories récentes, montant en premier).
2. Avoir une idée claire des revenus (ce qui est entré ce mois-ci, d'où, comparé aux dépenses).
3. Suivre l'épargne (progression vers chaque cible).
4. Avoir des statistiques pour se projeter et planifier les projets (tendances sur plusieurs mois, capacité d'épargne mensuelle, date estimée pour atteindre une cible ou financer un projet).

Les statistiques et les projets sont donc plus importants que l'ordre ci-dessous ne le laisse penser : ils viennent juste après le socle (opérations, catégories, épargnes).

## Code (état au 26/11/2026)

- Flutter 3.50 / Dart 3.14. Material s'importe depuis `package:material_ui/material_ui.dart` (`package:flutter/material.dart` est déprécié) ; les traductions françaises viennent de `GlobalMaterialLocalizations.delegates` de material_ui, pas de flutter_localizations.
- `lib/models` (Portefeuille, Catégorie, Opération, Réglages ; noms de champs JSON en français, prêts pour Firestore) · `lib/data` (catégories par défaut, `BudgetRepository` avec stockage local JSON, à remplacer par Firestore) · `lib/state/budget_store.dart` (calculs : soldes, totaux du mois, catégories fréquentes) · `lib/ui` (écrans).
- Montants formatés par `lib/core/format.dart` (espace insécable entre milliers).
- Signature : clé permanente `android/mifbudget-upload.jks` + `android/key.properties` (non versionnés ; voir README). Sauvegarde dans le Google Drive d'Eudokia, dossier privé « MifBudget - clé de signature », fichier `MifBudget-cle-signature.zip` (id Drive `1pdkw6KvpCVXCwE72h1dmeB2p2dop-_sZ`) : le télécharger avec le connecteur Google Drive et le décompresser dans `android/` avant de fabriquer un APK. Ne jamais distribuer un APK signé autrement, ni changer l'identifiant `com.mifbudget.app`. Incrémenter le `+N` de `version` à chaque APK distribué.
- Vérifier avant chaque commit : `flutter analyze` et `flutter test`. Captures jour/nuit : `tool/screenshots_test.dart`.
- Étapes faites : 1 (saisie rapide, opérations, accueil, réglages), 2 (carte Revenus de l'accueil, Bilan du mois dans l'onglet Rapports), 3 (épargnes), revue le 26/11/2026 : comptes épargne, portefeuilles multiples, communs ou personnels, privés ou publics (version 0.4.0). 4 (version 0.5.0) : Rapports → Tendances (`lib/ui/trends_view.dart`), projections (`lib/core/projection.dart`, `BudgetStore.averages` / `goalPace` / `goalReachDate` / `categoryTrends`), simulateur dans le détail d'un objectif, projets (`lib/models/project.dart`, `lib/ui/projects.dart`, dépenses rattachées par `projet`). Les moyennes portent sur les 3 derniers mois complets depuis le premier mois saisi. Budgets (version 0.6.0) : `lib/models/budget.dart` (id `AAAA-MM:categorie`, plafond 0 = pas de budget), `BudgetStore.budgetsFor` / `spentIn` / `suggestedLimit` / `setBudgets` / `copyPreviousBudgets`, `lib/ui/budgets_screen.dart`, couleurs d'état `statusOk` / `statusWarning` / `statusWarningText` / `statusOver` du thème. Catégories (version 0.7.0) : `lib/ui/categories_screen.dart`, `BudgetStore.addCategory` / `updateCategory` (groupe, icône et couleur reportés sur les sous-catégories) / `categoryNameTaken` / `archivedTopCategories`, icônes et couleurs dans `lib/ui/widgets/common.dart` (`categoryIcons`, `categoryIconLabels`, `categoryColors`). Récurrences (version 0.8.0, mensuelles seulement, « à confirmer » par défaut, pas de notifications) : `lib/models/recurrence.dart`, opérations liées par `recurrence` avec un identifiant fixe `rec-<id>-AAAA-MM` (pas de doublon entre téléphones), échéance ignorée = opération supprimée, annulation immédiate = `undoOccurrence` (effacement), `BudgetStore.dueOccurrences` / `pendingOccurrences` / `upcomingOccurrences` / `processAutomaticRecurrences` (à l'ouverture) / `expectedIncomes` / `plannedExpenses`, `lib/ui/recurrences_screen.dart`, saisie en modes `EntryMode.confirm` / `EntryMode.draft`. Argent personnel (version 0.9.0) : `lib/ui/personal_money.dart` ; versement = récurrence « à confirmer » de type dépense (catégorie `cat-argent-personnel`) d'un portefeuille commun vers un portefeuille personnel (`portefeuilleCible`), comptée comme dépense du foyer ; dépenses avec `personnelle: true` exclues des chiffres du foyer (`monthSummary`, `totalsByCategory`, `spentIn`) ; `BudgetStore.personalWallets` / `personalBalance` / `personalReceived` / `personalSpent` / `personalByCategory` / `setupPersonalMoney` / `disablePersonalMoney`. Synchronisation (version 1.0.0) : projet Firebase `mifbudget` (Firestore `(default)` en europe-west1, connexion Google ; `android/app/google-services.json` versionné, il est de toute façon dans l'APK). `lib/sync/firestore_repository.dart` (données du foyer `foyers/{id}/…`, données privées `foyers/{id}/prive/{membre}/…` : portefeuilles privés et opérations privées selon `isPrivateOperation` ; écritures jamais attendues, écouteurs → `onRemoteChange`), `lib/sync/household_service.dart` (connexion Google, création du foyer avec copie des données locales, invitation à 8 caractères valable 7 jours et à usage unique, adhésion), `lib/sync/app_controller.dart` (passage du stockage local au foyer ; sauvegarde `mifbudget-avant-foyer.json`), `lib/ui/sync_screen.dart`, verrouillage `lib/ui/lock.dart` (code à 4 chiffres salé et haché, empreinte, redemandé après 5 minutes ailleurs). Règles : `firestore.rules`, à publier dans la console Firebase (Firestore → Règles) à chaque modification ; vérifiées par `tool/firestore-rules-test` (`npm install` puis `npm test`, émulateur Firestore).
- Logo (version 1.0.1) : « le duo », deux arches verte (#6FF0B8 → #22A06F) et orange (#FFB877 → #E0622E, fusion « screen ») sur dégradé #0B2A1F → #1F6B4F. Sources `tool/logo/*.svg`, images Android générées par `tool/logo/render.js` (icône adaptative + monochrome, `splash_logo`, `splash_branding`), écran de chargement #0F3326 (`launch_background.xml`, `values-v31` et `values-night-v31` pour Android 12+). Dans l'app : `MifLogo` (`lib/ui/widgets/logo.dart`).
- Argent personnel seul privé (version 1.0.3) : `Wallet.isPersonal` / `isPrivate` = `!shared` (le champ `prive` est toujours écrit égal à `!shared`), un portefeuille personnel est toujours courant ; plus de `visibleParAutre` sur les opérations. `isPrivateOperation` : privée si `personnelle` (dépense « pour moi », revenu reçu sur un portefeuille perso) ou transfert entre portefeuilles personnels ; tout le reste est commun (versement, dépôt du foyer vers un portefeuille perso, dépense « pour le foyer » payée avec un portefeuille perso). `monthSummary` exclut les revenus personnels. Reprise à chaque ouverture, sans effet si tout est en ordre : `BudgetStore._alignPersonalMoney` (épargne perso → compte du foyer, revenu sur portefeuille perso → personnel) puis `BudgetRepository.reconcilePrivacy` (Firestore : chaque document rangé selon la règle ; seulement mes portefeuilles et mes opérations, celles du conjoint sont rangées par son téléphone). Règles Firestore inchangées.
- Simplification (version 1.0.2, 27/11/2026, la femme d'Eudokia se perdait dans l'interface) : garder l'interface simple, une question par bloc, pas de chiffre répété, vocabulaire de tous les jours (mais garder « Épargne » et « Transfert », demandé par Eudokia). Accueil dans l'ordre : « À confirmer » (seulement s'il y en a ; « À venir » est dans Réglages → Opérations récurrentes), grande carte verte (Argent disponible, Entré ce mois / Dépensé / Reste, toucher = Bilan, « Mes comptes » = feuille `showWalletsSheet` des portefeuilles), budgets en alerte, argent personnel, épargne (barres seulement), 5 dernières opérations. Le détail des revenus est dans Rapports → Bilan (plus de carte Revenus sur l'Accueil ; `SpentGauge` dans `widgets/spent_gauge.dart`). `OperationTile` : une seule ligne sous le titre (auteur si c'est l'autre, compte ou « A → B » ou « Mis de côté / Retiré », date), le perso en icône (cadenas = privé, silhouette = visible). `GoalCard` : une phrase dans la liste, tous les calculs avec `detailed: true` (détail de l'objectif). Réglages en sections : Mon foyer, Mon budget, Mes comptes, Sécurité, Apparence, Présentation. Présentation en 3 écrans (`lib/ui/intro_screen.dart`), une fois par téléphone (`AppSettings.introSeen`, `MifBudgetApp(showIntro: true)` dans `main.dart` seulement), puis Réglages → Présentation.
- Épargne dans le code : `Wallet.role` (`courant` / `epargne`), virements avec `objectifEpargne` facultatif, `BudgetStore.goalBalance` / `unallocated` / `savingsDirection`. Les anciens types `versement_epargne` / `retrait_epargne` (v0.3.0) sont convertis en virements à l'ouverture (`_migrateToSavingsAccounts`, format de données version 2).
- Graphiques : couleurs `chartIncome` / `chartExpense` du thème (variantes de la charte validées daltonisme/contraste), barres `ValueBar` de `lib/ui/widgets/charts.dart` ; texte toujours dans les couleurs de texte, jamais dans celle de la série.

## Fonctionnalités V1 (ordre de priorité)

Indispensable : opérations (revenu, dépense, transfert, versement/retrait d'épargne), catégories et sous-catégories, budgets mensuels, épargnes.
Important : opérations récurrentes (salaire, loyer, argent personnel mensuel, abonnements), projets avec budget.
Utile : rapports (bilan mensuel, répartition par catégorie, 12 mois, export PDF/tableur).

- Principe (décision du 27/11/2026, remplace « chaque portefeuille public ou privé » du 26/11) : **tout ce qui concerne le foyer est visible des deux ; seul l'argent personnel (argent de poche) est privé.**
- Portefeuilles : autant que voulu (plusieurs comptes bancaires, Mobile Money, espèces), de type espèces / banque / Mobile Money, de deux sortes seulement : **du foyer** (visibles des deux, comptés ; rôle **courant** — argent de tous les jours, compté dans l'argent disponible — ou **épargne**) et **argent personnel** (toujours privés, toujours courants, jamais comptés dans le foyer). Pas d'épargne personnelle, pas d'interrupteur privé / visible.
- Épargne (décision du 26/11/2026, remplace les enveloppes) : épargner = virer d'un compte courant vers un compte épargne (opération transfert), ce n'est pas une dépense. Disponible = total des portefeuilles courants ; total épargné = total des comptes épargne. Objectifs (nom, cible modifiable, date cible facultative ; au départ sûreté et construction proposés) rattachés à un compte épargne : un ou plusieurs objectifs par compte, ou un compte par objectif. Seul sur son compte, un objectif en a tout le solde ; à plusieurs, chacun a sa part de départ + les virements marqués pour lui, le reste est « non réparti ».
- Budgets : plafond par catégorie et par mois. L'app propose un montant (moyenne des 3 derniers mois) mais l'utilisateur peut saisir le sien. Copier les plafonds du mois précédent. Barre verte < 80 %, orange ≥ 80 %, rouge « Dépassé ».
- Pas de suivi de tontine.

## Argent personnel (règle de confidentialité importante)

- Option activable dans les Réglages. Chaque conjoint a un portefeuille personnel alimenté par un montant mensuel paramétrable (ex. 30 000 FCFA), créé par une opération récurrente.
- L'autre conjoint voit uniquement le versement mensuel. Il ne voit ni le détail des dépenses personnelles, ni le solde restant.
- Quand on paie avec un portefeuille personnel, la saisie propose « Pour : moi · le foyer ». « Moi » : dépense personnelle, privée, hors chiffres du foyer. « Le foyer » : dépense commune payée depuis un portefeuille perso (ex. facture réglée avec le Mobile Money perso après y avoir déposé de l'argent du foyer) ; visible des deux et comptée dans le budget familial. Un revenu reçu sur un portefeuille personnel (un cadeau) est personnel : privé, hors revenus du foyer.
- L'argent personnel est réparti sur un ou plusieurs portefeuilles personnels (porte-monnaie en espèces, Mobile Money perso) ; le reste est leur total ; passer de l'un à l'autre est un transfert. Le disponible du foyer ne compte que les portefeuilles communs.
- Versement mensuel « à confirmer » (le montant peut varier d'un mois à l'autre).
- Les dépenses privées sont stockées à part et lisibles par leur seul propriétaire, y compris côté serveur (règles Firestore) : l'autre téléphone ne les reçoit jamais.
- Chacun a ses statistiques d'argent personnel (par catégorie, mois par mois, reste), visibles par lui seul.

## Catégories par défaut

Dépenses (groupe) : Alimentation (Essentiel) · Logement (Essentiel) · Transport (Essentiel) · Communication (Essentiel) · Santé (Essentiel) · Enfants et école (Essentiel) · Dettes et crédits (Essentiel) · Frais financiers, dont frais Mobile Money (Essentiel) · Famille et solidarité, dont cérémonies (Confort) · Dons et religion (Confort) · Maison et équipement (Confort) · Habillement et soins (Confort) · Loisirs (Confort) · Argent personnel (Confort) · Divers (Confort).
Revenus : Salaires · Activités annexes · Autres revenus.
Tout est modifiable : créer, renommer, archiver des catégories et sous-catégories, changer de groupe.

## Données (Firestore)

Foyer (nom, devise XOF, argent personnel activé) · Membre · Portefeuille (type espèces/banque/Mobile Money, solde de départ, commun ou personnel, propriétaire, montant mensuel) · Catégorie (type, groupe, parente, icône, couleur, archivée) · Opération (type, montant, date, catégorie, portefeuilles source/cible, projet, objectif d'épargne, note, visible par l'autre, auteur, dates, supprimée) · Budget (catégorie, mois AAAA-MM, plafond) · Objectif d'épargne (nom, portefeuille, cible, date cible, projet lié) · Projet · Récurrence.

## Écrans

Barre du bas : Accueil, Opérations, Budgets, Épargnes, Rapports ; bouton « + » flottant pour la saisie rapide. Réglages accessibles depuis l'Accueil. Installation : compte, foyer, portefeuilles et soldes de départ, deux épargnes avec cible, invitation du conjoint (code ou lien).

## Charte graphique

Police Inter. Jour : vert #1F6B4F, terre cuite #B4531A, fond #F5F6F3, cartes #FFFFFF, texte #1C2420, texte secondaire #5B6660. Nuit : fond #101513, cartes #1A211E, vert #5CC197, terre cuite #E5884E, texte #E6ECE8. Suit le réglage du téléphone, avec un choix forcé possible dans les Réglages.

## Idées pour plus tard (décidées mais pas encore faites)

- Interrupteur « Avance sur mon argent personnel » (26/11/2026, mis de côté à la demande d'Eudokia) : visible seulement quand on paie une dépense avec un portefeuille commun. La dépense resterait visible des deux mais ne compterait pas dans les dépenses du foyer ; elle apparaîtrait dans les statistiques perso et dans un « À rembourser » de l'espace personnel, avec un bouton « Rembourser » (transfert du portefeuille personnel vers le portefeuille commun, visible lui aussi). Sans lui, une dépense perso payée avec un portefeuille commun puis remboursée gonfle légèrement les dépenses du foyer.
