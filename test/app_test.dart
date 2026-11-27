import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mifbudget/app.dart';
import 'package:mifbudget/core/format.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/category.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/project.dart';
import 'package:mifbudget/models/wallet.dart';
import 'package:mifbudget/state/budget_store.dart';
import 'package:mifbudget/ui/quick_entry_screen.dart';

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await initializeDateFormatting('fr_FR');
  });

  final clock = DateTime(2026, 11, 26, 10);

  /// Fait défiler la liste de l'écran du dessus jusqu'au texte, puis le
  /// centre (un champ de texte contient aussi une zone défilante, d'où la
  /// recherche de la ListView).
  Future<void> reveal(WidgetTester tester, String text) async {
    final list = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -200));
      await tester.pump();
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, List<String> keys) async {
    for (final k in keys) {
      await tester.tap(find.byKey(Key('touche-$k')));
    }
    await tester.pump();
  }

  Future<BudgetStore> pumpApp(WidgetTester tester, {bool setup = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final store = await BudgetStore.open(
      MemoryRepository(),
      clock: () => clock,
    );
    if (setup) {
      await store.completeSetup(memberName: 'Eudokia', cash: 20000);
    }
    await tester.pumpWidget(MifBudgetApp(store: store));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets("première ouverture : prénom et soldes de départ", (
    tester,
  ) async {
    final store = await pumpApp(tester, setup: false);
    expect(find.text('Bienvenue'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Votre prénom'),
      'Eudokia',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Banque'), '400000');
    await tester.pump();
    expect(find.text('400${nbsp}000'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Eudokia'), findsOneWidget);
    expect(store.walletBalance(DefaultIds.walletBank), 400000);
    expect(find.text('400${nbsp}000${nbsp}FCFA'), findsOneWidget);
  });

  testWidgets('saisie rapide d\'une dépense en quelques touches', (
    tester,
  ) async {
    final store = await pumpApp(tester);

    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle opération'), findsOneWidget);
    expect(find.text('Saisir un montant'), findsOneWidget);

    await type(tester, ['1', '5', '000']);
    expect(find.text('15${nbsp}000'), findsOneWidget);
    expect(find.text('Choisir une catégorie'), findsOneWidget);

    await tester.tap(find.text('Alimentation'));
    await tester.pump();
    await tester.tap(find.text('Marché'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final op = store.operations.single;
    expect(op.type, OperationType.expense);
    expect(op.amount, 15000);
    expect(op.categoryId, 'cat-alimentation-marche');
    expect(op.sourceWalletId, DefaultIds.walletCash);
    expect(op.date, DateTime(2026, 11, 26));
    expect(store.walletBalance(DefaultIds.walletCash), 5000);

    expect(
      find.text('Dépense de 15${nbsp}000${nbsp}FCFA enregistrée'),
      findsOneWidget,
    );
    // Elle apparaît dans l'accueil et dans l'onglet Opérations.
    expect(find.text('Marché'), findsWidgets);
    expect(find.text('−15${nbsp}000'), findsWidgets);

    // « Annuler » la retire.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(store.operations, isEmpty);
  });

  testWidgets('saisie d\'un revenu puis modification depuis la liste', (
    tester,
  ) async {
    final store = await pumpApp(tester);

    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenu'));
    await tester.pump();
    await type(tester, ['6', '5', '0', '000']);
    await tester.tap(find.text('Salaires'));
    await tester.tap(find.text('Banque'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final op = store.operations.single;
    expect(op.type, OperationType.income);
    expect(op.amount, 650000);
    expect(op.targetWalletId, DefaultIds.walletBank);
    expect(store.monthSummary(clock).income, 650000);

    // Onglet Opérations, puis modification du montant.
    await tester.tap(find.text('Opérations').last);
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
    await tester.tap(find.text('Salaires').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    await type(tester, ['⌫', '⌫', '⌫', '000']);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(store.operations.single.amount, 650000);

    await tester.tap(find.text('Salaires').hitTestable());
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('touche-⌫')));
    await tester.pump();
    await type(tester, ['7', '0', '0', '000']);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(store.operations.single.amount, 700000);
    expect(store.operations.single.id, op.id);
  });

  testWidgets('transfert entre deux portefeuilles', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfert'));
    await tester.pump();
    await type(tester, ['5', '000']);
    // Par défaut : Espèces → Banque.
    await tester.tap(find.text('Mobile Money').last);
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(store.walletBalance(DefaultIds.walletCash), 15000);
    expect(store.walletBalance(DefaultIds.walletMobileMoney), 5000);
    expect(store.totalBalance, 20000);
  });

  testWidgets("l'accueil montre l'argent entré, dépensé et le reste du mois", (
    tester,
  ) async {
    final store = await pumpApp(tester);
    expect(find.text('Argent disponible'), findsOneWidget);
    expect(find.text('Entré ce mois'), findsOneWidget);

    Future<void> income(int a, String cat, DateTime d) => store.addOperation(
      type: OperationType.income,
      amount: a,
      date: d,
      categoryId: cat,
      targetWalletId: DefaultIds.walletBank,
    );
    await income(600000, 'cat-salaires', DateTime(2026, 10, 25));
    await income(600000, 'cat-salaires', DateTime(2026, 11, 25));
    await income(50000, 'cat-activites-annexes', DateTime(2026, 11, 20));
    await store.addOperation(
      type: OperationType.expense,
      amount: 162500,
      date: clock,
      categoryId: 'cat-logement-loyer',
      sourceWalletId: DefaultIds.walletCash,
    );
    await tester.pumpAndSettle();

    expect(find.text('650${nbsp}000'), findsOneWidget);
    expect(find.text('162${nbsp}500'), findsOneWidget);
    expect(find.text('487${nbsp}500'), findsOneWidget);

    // Toucher la carte ouvre le bilan du mois, avec le détail des revenus.
    await tester.tap(find.text('Argent disponible'));
    await tester.pumpAndSettle();
    expect(find.text('Bilan du mois'), findsOneWidget);
    expect(find.text('Revenus par source'), findsOneWidget);
    expect(find.text('+0 par rapport à octobre'), findsNothing);
    expect(find.text('Comme en octobre'), findsOneWidget);
    expect(find.text('Rien en octobre'), findsOneWidget);
    expect(
      find.textContaining('soit 25$nbsp% des revenus', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('la présentation se montre une fois, puis l\'Accueil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = await BudgetStore.open(
      MemoryRepository(),
      clock: () => clock,
    );
    await store.completeSetup(memberName: 'Eudokia');
    await tester.pumpWidget(MifBudgetApp(store: store, showIntro: true));
    await tester.pumpAndSettle();
    expect(find.text('Une dépense en quelques secondes'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Cinq onglets, en bas'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("C'est parti"));
    await tester.pumpAndSettle();
    expect(store.settings.introSeen, isTrue);
    expect(find.text('Argent disponible'), findsOneWidget);
  });

  testWidgets("« Mes comptes » liste les portefeuilles et leur solde", (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Mes comptes'));
    await tester.pumpAndSettle();
    expect(find.text('Argent de tous les jours'), findsOneWidget);
    expect(find.text('Banque'), findsOneWidget);
    expect(find.text('Ajouter un portefeuille'), findsOneWidget);
  });

  testWidgets('« Saisir un revenu » (bilan) ouvre la saisie sur Revenu', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Rapports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saisir un revenu'));
    await tester.pumpAndSettle();
    await type(tester, ['5', '0', '000']);
    expect(find.text('Choisir une catégorie'), findsOneWidget);
    await tester.tap(find.text('Activités annexes'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(store.operations.single.type, OperationType.income);
    expect(store.monthSummary(clock).income, 50000);
  });

  testWidgets('le bilan change de mois depuis le graphique des 6 mois', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await store.addOperation(
      type: OperationType.income,
      amount: 600000,
      date: DateTime(2026, 9, 25),
      categoryId: 'cat-salaires',
      targetWalletId: DefaultIds.walletBank,
    );
    await tester.tap(find.text('Rapports'));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.text('Aucun revenu en novembre.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('sept.'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('sept.'));
    await tester.pumpAndSettle();
    // Remonter en haut du bilan.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(find.text('Rien en août'), findsOneWidget);
  });

  testWidgets(
    "ajouter un compte épargne, un objectif, puis verser et retirer",
    (tester) async {
      final store = await pumpApp(tester);
      await tester.tap(find.text('Épargnes').last);
      await tester.pumpAndSettle();
      expect(find.text('Ajoutez votre compte épargne'), findsOneWidget);

      await tester.tap(find.text('Ajouter un compte épargne'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau portefeuille'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nom'),
        'Compte épargne',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Solde de départ'),
        '500000',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final compte = store.savingsWallets.single;
      expect(compte.name, 'Compte épargne');
      expect(store.totalSaved, 500000);
      expect(store.available, 20000);

      // Objectif proposé sous le compte.
      await tester.tap(find.text('Épargne de sûreté'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvel objectif'), findsOneWidget);
      expect(
        find.text(
          'Seul objectif de ce compte : tout son solde '
          '(500${nbsp}000${nbsp}FCFA) compte pour lui.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Montant cible'),
        '1500000',
      );
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final goal = store.goals.single;
      expect(goal.walletId, compte.id);
      expect(store.goalBalance(goal.id), 500000);
      expect(
        find.text('Il reste 1${nbsp}000${nbsp}000${nbsp}FCFA'),
        findsOneWidget,
      );

      // Verser 10 000 : un virement des Espèces vers le compte épargne.
      await tester.tap(find.text('Verser'));
      await tester.pumpAndSettle();
      expect(find.text('Pour : Épargne de sûreté'), findsOneWidget);
      await type(tester, ['1', '0', '000']);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('10${nbsp}000${nbsp}FCFA mis de côté'), findsOneWidget);
      final op = store.operations.single;
      expect(op.type, OperationType.transfer);
      expect(op.sourceWalletId, DefaultIds.walletCash);
      expect(op.targetWalletId, compte.id);
      expect(store.goalBalance(goal.id), 510000);
      expect(store.walletBalance(DefaultIds.walletCash), 10000);
      expect(store.available, 10000);

      // Retirer plus que le compte épargne est refusé.
      await tester.ensureVisible(find.text('Retirer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      await type(tester, ['6', '0', '0', '000']);
      expect(find.text('Maximum 510${nbsp}000${nbsp}FCFA'), findsOneWidget);
      await type(tester, ['⌫', '⌫', '⌫', '⌫', '⌫', '⌫']);
      await type(tester, ['5', '000']);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(store.walletBalance(compte.id), 505000);
      expect(store.available, 15000);

      // Accueil : disponible = comptes courants.
      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      expect(find.text('Argent disponible'), findsOneWidget);
      expect(find.text('15${nbsp}000${nbsp}FCFA'), findsOneWidget);
    },
  );

  testWidgets("saisie rapide : verser sur l'un des objectifs d'un compte", (
    tester,
  ) async {
    final store = await pumpApp(tester);
    final compte = await store.addWallet(
      name: 'Compte épargne',
      type: WalletType.bank,
      role: WalletRole.savings,
    );
    await store.addGoal(name: 'Sûreté', target: 1500000, walletId: compte.id);
    final construction = await store.addGoal(
      name: 'Construction',
      target: 8000000,
      walletId: compte.id,
      icon: 'construction',
    );
    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Épargne'));
    await tester.pump();
    await type(tester, ['2', '5', '000']);
    expect(find.text('Pour quel objectif ?'), findsOneWidget);
    await tester.tap(find.text('Construction'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final op = store.operations.single;
    expect(op.savingsGoalId, construction.id);
    expect(op.targetWalletId, compte.id);
    expect(store.goalBalance(construction.id), 25000);
    expect(store.unallocated(compte.id), 0);
  });

  testWidgets('ajouter un portefeuille personnel privé depuis les Réglages', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await reveal(tester, 'Ajouter un portefeuille');
    await tester.tap(find.text('Ajouter un portefeuille'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Wave');
    await tester.tap(find.text('Mobile Money'));
    await tester.tap(find.text('Personnel'));
    await tester.pump();
    await tester.tap(find.text('Privé'));
    await tester.pump();
    expect(
      find.text('Vous seul verrez ce portefeuille et ses opérations.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final wave = store.wallets.firstWhere((w) => w.name == 'Wave');
    expect(wave.type, WalletType.mobileMoney);
    expect(wave.isPrivate, isTrue);
    expect(wave.isSavings, isFalse);
    expect(find.text('Mobile Money · Personnel, privé'), findsOneWidget);
  });

  testWidgets('tendances, projection et simulateur', (tester) async {
    final store = await pumpApp(tester);
    final compte = await store.addWallet(
      name: 'Compte épargne',
      type: WalletType.bank,
      role: WalletRole.savings,
      openingBalance: 300000,
    );
    // Octobre : un mois complet avec revenus, dépenses et épargne.
    final oct = DateTime(2026, 10, 25);
    await store.addOperation(
      type: OperationType.income,
      amount: 600000,
      date: oct,
      categoryId: 'cat-salaires',
      targetWalletId: DefaultIds.walletBank,
    );
    await store.addOperation(
      type: OperationType.expense,
      amount: 450000,
      date: oct,
      categoryId: 'cat-alimentation',
      sourceWalletId: DefaultIds.walletBank,
    );
    await store.addOperation(
      type: OperationType.transfer,
      amount: 100000,
      date: oct,
      sourceWalletId: DefaultIds.walletBank,
      targetWalletId: compte.id,
    );
    final g = await store.addGoal(
      name: 'Sûreté',
      target: 1000000,
      walletId: compte.id,
      icon: 'surete',
    );

    await tester.tap(find.text('Rapports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tendances'));
    await tester.pumpAndSettle();
    expect(find.text("Capacité d'épargne"), findsOneWidget);
    expect(find.text('Moyenne par mois, en octobre 2026'), findsOneWidget);
    expect(
      find.textContaining(
        '100${nbsp}000${nbsp}FCFA par mois',
        findRichText: true,
      ),
      findsWidgets,
    );

    await tester.scrollUntilVisible(
      find.text('Projections'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    // Il manque 600 000 à 100 000 par mois : 6 mois, novembre compris.
    expect(find.text('Atteint vers avril 2027'), findsOneWidget);

    // Simulateur dans le détail de l'objectif.
    await tester.tap(find.text('Épargnes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sûreté'));
    await tester.pumpAndSettle();
    expect(find.text('Simuler'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Si je verse chaque mois'),
      '200000',
    );
    await tester.pump();
    // 600 000 à 200 000 par mois : 3 mois, novembre compris.
    expect(
      find.textContaining(
        'Cible atteinte vers janvier 2027',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(store.goalPace(g), 100000);
  });

  testWidgets('créer un projet et y rattacher une dépense', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Épargnes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Fondations');
    await tester.enterText(
      find.widgetWithText(TextField, 'Budget prévu'),
      '1800000',
    );
    await tester.tap(find.text('En cours'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final p = store.projects.single;
    expect(p.status, ProjectStatus.active);
    expect(
      find.text('Reste à financer 1${nbsp}800${nbsp}000${nbsp}FCFA'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await type(tester, ['5', '0', '0', '000']);
    await tester.tap(find.text('Logement'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Projet (facultatif)'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(QuickEntryScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Le nom du projet figure aussi dans l'onglet Épargnes, sous la saisie.
    final chip = find.text('Fondations').last;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(store.operations.single.projectId, p.id);
    expect(store.projectSpent(p.id), 500000);
    expect(store.projectToFund(p), 1300000);
  });

  testWidgets('fixer un budget, puis être prévenu en approchant du plafond', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await store.addOperation(
      type: OperationType.expense,
      amount: 90000,
      date: DateTime(2026, 10, 12),
      categoryId: 'cat-alimentation',
      sourceWalletId: DefaultIds.walletCash,
    );
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun budget pour novembre'), findsOneWidget);
    await tester.tap(find.text('Définir les plafonds'));
    await tester.pumpAndSettle();
    expect(find.text('Plafonds de novembre'), findsOneWidget);
    expect(
      find.text('Proposé : 90${nbsp}000${nbsp}FCFA (moyenne 3 mois)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Proposer les plafonds'));
    await tester.pump();
    expect(find.text('90${nbsp}000'), findsOneWidget);
    await tester.tap(find.textContaining('Enregistrer'));
    await tester.pumpAndSettle();
    expect(store.budgetLimit(DateTime(2026, 11), 'cat-alimentation'), 90000);
    expect(find.text('Dépensé sur le budget du mois'), findsOneWidget);
    expect(
      find.text('Reste 90${nbsp}000${nbsp}FCFA · 4 jours avant la fin du mois'),
      findsOneWidget,
    );

    // Une dépense qui fait passer à 89 % : prévenu dans la confirmation.
    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await type(tester, ['8', '0', '000']);
    await tester.tap(find.text('Alimentation').last);
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Dépense de 80${nbsp}000${nbsp}FCFA enregistrée · '
        'Alimentation : 89$nbsp% du budget',
      ),
      findsOneWidget,
    );
    expect(find.text('89$nbsp%'), findsOneWidget);

    // L'accueil le signale aussi.
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('Budgets à surveiller'), findsOneWidget);
  });

  testWidgets('créer une catégorie et l\'utiliser dans la saisie', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await reveal(tester, 'Catégories et sous-catégories');
    await tester.tap(find.text('Catégories et sous-catégories'));
    await tester.pumpAndSettle();
    expect(find.text('Essentiel'), findsOneWidget);
    await reveal(tester, 'Nouvelle catégorie');
    await tester.tap(find.text('Nouvelle catégorie'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nom'),
      'Alimentation',
    );
    await tester.pump();
    expect(find.text('Ce nom existe déjà'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Animaux');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Animaux'));
    await tester.pump();
    await reveal(tester, 'Enregistrer');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final animaux = store
        .topCategories(CategoryKind.expense)
        .firstWhere((c) => c.name == 'Animaux');
    expect(animaux.icon, 'animaux');
    expect(animaux.group, CategoryGroup.comfort);

    // Ajouter une sous-catégorie depuis la fiche.
    await reveal(tester, 'Animaux');
    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();
    await reveal(tester, 'Ajouter une sous-catégorie');
    await tester.tap(find.text('Ajouter une sous-catégorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Vétérinaire');
    await tester.pump();
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();
    expect(store.subcategories(animaux.id).single.name, 'Vétérinaire');
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    // Dans la saisie : « Autre » → la nouvelle sous-catégorie.
    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await type(tester, ['7', '000']);
    await tester.tap(find.text('Autre'));
    await tester.pumpAndSettle();
    await reveal(tester, 'Vétérinaire');
    await tester.tap(find.text('Vétérinaire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      store.topCategory(store.operations.single.categoryId)!.id,
      animaux.id,
    );
  });

  testWidgets('rendre récurrente une opération déjà saisie', (tester) async {
    final store = await pumpApp(tester);
    await store.addOperation(
      type: OperationType.expense,
      amount: 150000,
      date: DateTime(2026, 11, 4),
      categoryId: 'cat-logement-loyer',
      sourceWalletId: DefaultIds.walletCash,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opérations').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loyer').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rendre récurrente'));
    await tester.pumpAndSettle();
    expect(find.text('le 4 de chaque mois'), findsOneWidget);
    expect(find.text('Novembre 2026'), findsOneWidget);
    await reveal(tester, 'Enregistrer');
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();
    final r = store.recurrences.single;
    expect(r.dayOfMonth, 4);
    expect(r.automatic, isFalse);
    // Novembre est déjà saisi : rien à confirmer, décembre à venir.
    expect(store.pendingOccurrences, isEmpty);
    expect(store.upcomingOccurrences().single.date, DateTime(2026, 12, 4));
    expect(store.operations, hasLength(1));
  });

  testWidgets(
    'nouvelle récurrence, puis confirmer, annuler et ignorer sur l\'Accueil',
    (tester) async {
      final store = await pumpApp(tester);
      await tester.tap(find.byTooltip('Réglages'));
      await tester.pumpAndSettle();
      await reveal(tester, 'Opérations récurrentes');
      await tester.tap(find.text('Opérations récurrentes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle récurrence'));
      await tester.pumpAndSettle();
      // D'abord l'opération, avec la saisie habituelle (sans date).
      expect(find.text('Opération récurrente'), findsOneWidget);
      expect(find.text('Date'), findsNothing);
      await type(tester, ['1', '5', '000']);
      await tester.tap(find.text('Communication'));
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      // Puis le calendrier : le 26 (aujourd'hui), à confirmer.
      expect(find.text('Rendre récurrente'), findsOneWidget);
      expect(find.text('le 26 de chaque mois'), findsOneWidget);
      await reveal(tester, 'Enregistrer');
      await tester.tap(find.text('Enregistrer').last);
      await tester.pumpAndSettle();
      expect(store.recurrences.single.amount, 15000);
      expect(find.text('le 26 de chaque mois · à confirmer'), findsOneWidget);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(find.text('À confirmer (1)'), findsOneWidget);

      // Confirmer, puis annuler : l'échéance revient.
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      expect(store.operations.single.amount, 15000);
      expect(find.text('À confirmer (1)'), findsNothing);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(store.operations, isEmpty);
      expect(find.text('À confirmer (1)'), findsOneWidget);

      // Ignorer : plus rien à confirmer, rien d'enregistré.
      await tester.tap(find.text('Ignorer'));
      await tester.pumpAndSettle();
      expect(store.pendingOccurrences, isEmpty);
      expect(store.operations, isEmpty);
      expect(store.walletBalance(DefaultIds.walletCash), 20000);
    },
  );

  testWidgets("activer l'argent personnel et faire une dépense privée", (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Argent personnel').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Montant mensuel'),
      '30000',
    );
    await reveal(tester, 'Créer « Porte-monnaie » (espèces, privé)');
    await tester.tap(find.text('Créer « Porte-monnaie » (espèces, privé)'));
    await tester.pumpAndSettle();
    await reveal(tester, "Activer l'argent personnel");
    await tester.tap(find.text("Activer l'argent personnel").last);
    await tester.pumpAndSettle();
    final purse = store.personalWallets.single;
    expect(purse.isPrivate, isTrue);
    expect(store.allowance!.targetWalletId, purse.id);
    expect(store.allowance!.sourceWalletId, DefaultIds.walletCash);
    expect(
      find.text('30${nbsp}000${nbsp}FCFA le 1er de chaque mois'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    // Le porte-monnaie reçoit 5 000 puis sert à une dépense perso.
    await store.addOperation(
      type: OperationType.transfer,
      amount: 5000,
      date: DateTime(2026, 11, 26),
      sourceWalletId: DefaultIds.walletCash,
      targetWalletId: purse.id,
    );
    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await type(tester, ['2', '000']);
    await tester.tap(find.text('Transport'));
    await tester.tap(find.text('Porte-monnaie'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Payée avec votre argent personnel, visible par vous seul.'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(QuickEntryScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.text('Payée avec votre argent personnel, visible par vous seul.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final op = store.operations.firstWhere(
      (o) => o.type == OperationType.expense,
    );
    expect(op.personal, isTrue);
    expect(op.visibleToPartner, isFalse);
    expect(store.monthSummary(DateTime(2026, 11)).expense, 0);
    expect(store.personalBalance, 3000);

    // L'accueil montre l'argent personnel ; l'écran dédié, la dépense.
    expect(find.text('Mon argent personnel'), findsOneWidget);
    await tester.ensureVisible(find.text('Mon argent personnel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon argent personnel'));
    await tester.pumpAndSettle();
    expect(find.text('Visible par vous seul'), findsOneWidget);
    expect(
      find.textContaining('2${nbsp}000${nbsp}FCFA dépensés en novembre'),
      findsOneWidget,
    );
  });
}
