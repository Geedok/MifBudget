import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mifbudget/app.dart';
import 'package:mifbudget/core/format.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/wallet.dart';
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
      expect(find.text('Disponible'), findsOneWidget);
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
}
