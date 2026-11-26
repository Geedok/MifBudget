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
}
