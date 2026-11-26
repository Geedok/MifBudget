import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mifbudget/app.dart';
import 'package:mifbudget/core/format.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/state/budget_store.dart';

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await initializeDateFormatting('fr_FR');
  });

  final clock = DateTime(2026, 11, 26, 10);

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

  testWidgets("l'accueil montre d'où viennent les revenus du mois", (
    tester,
  ) async {
    final store = await pumpApp(tester);
    expect(find.text('Aucun revenu saisi en novembre.'), findsOneWidget);

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

    expect(find.text('Revenus de novembre'), findsOneWidget);
    expect(find.text('650${nbsp}000${nbsp}FCFA'), findsOneWidget);
    expect(find.text('+50${nbsp}000 par rapport à octobre'), findsOneWidget);
    expect(find.text('Salaires'), findsWidgets);
    expect(find.text('92$nbsp%'), findsOneWidget);
    expect(find.text('Activités annexes'), findsWidgets);
    expect(
      find.textContaining('soit 25$nbsp% des revenus', findRichText: true),
      findsWidgets,
    );

    // Toucher la carte ouvre le bilan du mois.
    await tester.tap(find.text('Revenus de novembre'));
    await tester.pumpAndSettle();
    expect(find.text('Bilan du mois'), findsOneWidget);
    expect(find.text('Revenus par source'), findsOneWidget);
    expect(find.text('+0 par rapport à octobre'), findsNothing);
    expect(find.text('Comme en octobre'), findsOneWidget);
    expect(find.text('Rien en octobre'), findsOneWidget);
  });

  testWidgets('« Saisir un revenu » ouvre la saisie sur Revenu', (
    tester,
  ) async {
    final store = await pumpApp(tester);
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

  testWidgets("créer l'épargne de sûreté puis y verser de l'argent", (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Épargnes').last);
    await tester.pumpAndSettle();
    expect(find.text('Créez vos épargnes'), findsOneWidget);

    await tester.tap(find.text('Épargne de sûreté'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle épargne'), findsOneWidget);
    expect(find.text('Saisir le montant cible'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Montant cible'),
      '1500000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Déjà mis de côté (facultatif)'),
      '5000',
    );
    await tester.pump();
    await tester.tap(find.text('Espèces'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final goal = store.goals.single;
    expect(goal.name, 'Épargne de sûreté');
    expect(goal.target, 1500000);
    expect(goal.icon, 'surete');
    expect(goal.walletId, DefaultIds.walletCash);
    expect(
      find.text('Il reste 1${nbsp}495${nbsp}000${nbsp}FCFA'),
      findsOneWidget,
    );

    // Verser 10 000 depuis la carte.
    await tester.tap(find.text('Verser'));
    await tester.pumpAndSettle();
    expect(
      find.text('Déjà mis de côté : 5${nbsp}000${nbsp}FCFA'),
      findsOneWidget,
    );
    await type(tester, ['1', '0', '000']);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('10${nbsp}000${nbsp}FCFA mis de côté'), findsOneWidget);
    expect(store.goalBalance(goal.id), 15000);
    expect(store.walletBalance(DefaultIds.walletCash), 20000);
    expect(store.available, 5000);

    // Retirer plus que l'épargne est refusé.
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    await type(tester, ['2', '0', '000']);
    expect(find.text('Maximum 15${nbsp}000${nbsp}FCFA'), findsOneWidget);
    await type(tester, ['⌫', '⌫', '⌫', '⌫']);
    await type(tester, ['000']);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(store.goalBalance(goal.id), 13000);

    // L'accueil montre le disponible et l'épargne.
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('7${nbsp}000${nbsp}FCFA'), findsOneWidget);
    expect(find.text('13${nbsp}000 sur 1${nbsp}500${nbsp}000${nbsp}FCFA'), findsOneWidget);
  });

  testWidgets("l'onglet Épargne de la saisie rapide", (tester) async {
    final store = await pumpApp(tester);
    final g = await store.addGoal(
      name: 'Construction',
      target: 8000000,
      walletId: DefaultIds.walletBank,
      icon: 'construction',
    );
    await tester.tap(find.byTooltip('Ajouter une opération'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Épargne'));
    await tester.pump();
    await type(tester, ['2', '5', '000']);
    // Une seule épargne : déjà choisie, avec son portefeuille.
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final op = store.operations.single;
    expect(op.type, OperationType.savingsDeposit);
    expect(op.savingsGoalId, g.id);
    expect(op.sourceWalletId, DefaultIds.walletBank);
    expect(store.goalBalance(g.id), 25000);
    expect(find.text('Construction'), findsWidgets);
  });
}
