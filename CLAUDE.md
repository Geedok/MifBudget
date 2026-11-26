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
- Étapes faites : 1 (saisie rapide, opérations, accueil, réglages), 2 (carte Revenus de l'accueil, Bilan du mois dans l'onglet Rapports), 3 (épargnes), revue le 26/11/2026 : comptes épargne, portefeuilles multiples, communs ou personnels, privés ou publics (version 0.4.0). 4 (version 0.5.0) : Rapports → Tendances (`lib/ui/trends_view.dart`), projections (`lib/core/projection.dart`, `BudgetStore.averages` / `goalPace` / `goalReachDate` / `categoryTrends`), simulateur dans le détail d'un objectif, projets (`lib/models/project.dart`, `lib/ui/projects.dart`, dépenses rattachées par `projet`). Les moyennes portent sur les 3 derniers mois complets depuis le premier mois saisi. Budgets (version 0.6.0) : `lib/models/budget.dart` (id `AAAA-MM:categorie`, plafond 0 = pas de budget), `BudgetStore.budgetsFor` / `spentIn` / `suggestedLimit` / `setBudgets` / `copyPreviousBudgets`, `lib/ui/budgets_screen.dart`, couleurs d'état `statusOk` / `statusWarning` / `statusWarningText` / `statusOver` du thème. Catégories (version 0.7.0) : `lib/ui/categories_screen.dart`, `BudgetStore.addCategory` / `updateCategory` (groupe, icône et couleur reportés sur les sous-catégories) / `categoryNameTaken` / `archivedTopCategories`, icônes et couleurs dans `lib/ui/widgets/common.dart` (`categoryIcons`, `categoryIconLabels`, `categoryColors`). Restent : récurrences, argent personnel, Firebase.
- Épargne dans le code : `Wallet.role` (`courant` / `epargne`), virements avec `objectifEpargne` facultatif, `BudgetStore.goalBalance` / `unallocated` / `savingsDirection`. Les anciens types `versement_epargne` / `retrait_epargne` (v0.3.0) sont convertis en virements à l'ouverture (`_migrateToSavingsAccounts`, format de données version 2).
- Graphiques : couleurs `chartIncome` / `chartExpense` du thème (variantes de la charte validées daltonisme/contraste), barres `ValueBar` de `lib/ui/widgets/charts.dart` ; texte toujours dans les couleurs de texte, jamais dans celle de la série.

## Fonctionnalités V1 (ordre de priorité)

Indispensable : opérations (revenu, dépense, transfert, versement/retrait d'épargne), catégories et sous-catégories, budgets mensuels, épargnes.
Important : opérations récurrentes (salaire, loyer, argent personnel mensuel, abonnements), projets avec budget.
Utile : rapports (bilan mensuel, répartition par catégorie, 12 mois, export PDF/tableur).

- Portefeuilles : autant que voulu (plusieurs comptes bancaires, Mobile Money, espèces), de type espèces / banque / Mobile Money, avec un rôle **courant** (argent de tous les jours, compte dans le disponible) ou **épargne**. Chacun est commun au foyer ou personnel ; un portefeuille personnel est public (visible du conjoint) ou privé (son propriétaire seul le voit, avec ses opérations — à appliquer aussi dans les règles Firestore).
- Épargne (décision du 26/11/2026, remplace les enveloppes) : épargner = virer d'un compte courant vers un compte épargne (opération transfert), ce n'est pas une dépense. Disponible = total des portefeuilles courants ; total épargné = total des comptes épargne. Objectifs (nom, cible modifiable, date cible facultative ; au départ sûreté et construction proposés) rattachés à un compte épargne : un ou plusieurs objectifs par compte, ou un compte par objectif. Seul sur son compte, un objectif en a tout le solde ; à plusieurs, chacun a sa part de départ + les virements marqués pour lui, le reste est « non réparti ».
- Budgets : plafond par catégorie et par mois. L'app propose un montant (moyenne des 3 derniers mois) mais l'utilisateur peut saisir le sien. Copier les plafonds du mois précédent. Barre verte < 80 %, orange ≥ 80 %, rouge « Dépassé ».
- Pas de suivi de tontine.

## Argent personnel (règle de confidentialité importante)

- Option activable dans les Réglages. Chaque conjoint a un portefeuille personnel alimenté par un montant mensuel paramétrable (ex. 30 000 FCFA), créé par une opération récurrente.
- L'autre conjoint voit uniquement le versement mensuel. Il ne voit ni le détail des dépenses personnelles, ni le solde restant.
- Chaque dépense personnelle est privée par défaut ; un interrupteur « Rendre visible » la montre à l'autre.
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
