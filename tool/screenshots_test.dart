// Captures d'écran de contrôle (non versionné). Lancer avec :
//   flutter test tool/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mifbudget/app.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/settings.dart';
import 'package:mifbudget/models/project.dart';
import 'package:mifbudget/models/wallet.dart';
import 'package:mifbudget/state/budget_store.dart';

final outDir = Platform.environment['SHOTS_DIR']!;

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  late ui.Image image;
  await tester.runAsync(() async {
    image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await loadFont('Inter', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'assets/fonts/Inter-$w.ttf',
    ]);
    await loadFont('MaterialIcons', [
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  for (final dark in [false, true]) {
    testWidgets('captures ${dark ? 'nuit' : 'jour'}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final clock = DateTime(2026, 11, 26, 19, 30);
      final store = await BudgetStore.open(
        MemoryRepository(),
        clock: () => clock,
      );
      final suffix = dark ? 'nuit' : 'jour';

      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: MifBudgetApp(store: store),
        ),
      );
      if (!dark) await shot(tester, '0-installation');

      await store.completeSetup(
        memberName: 'Eudokia',
        cash: 22000,
        bank: 712000,
        mobileMoney: 58300,
      );
      await store.setTheme(dark ? ThemeChoice.dark : ThemeChoice.light);
      Future<void> add(
        OperationType t,
        int a,
        int daysAgo,
        String? cat, {
        String? src,
        String? dst,
        String note = '',
      }) => store.addOperation(
        type: t,
        amount: a,
        date: clock.subtract(Duration(days: daysAgo)),
        categoryId: cat,
        sourceWalletId: src,
        targetWalletId: dst,
        note: note,
      );
      await add(
        OperationType.income,
        650000,
        25,
        'cat-salaires',
        dst: DefaultIds.walletBank,
      );
      await add(
        OperationType.expense,
        150000,
        24,
        'cat-logement-loyer',
        src: DefaultIds.walletBank,
      );
      await add(
        OperationType.transfer,
        50000,
        10,
        null,
        src: DefaultIds.walletBank,
        dst: DefaultIds.walletMobileMoney,
      );
      await add(
        OperationType.expense,
        18500,
        1,
        'cat-logement-electricite',
        src: DefaultIds.walletMobileMoney,
      );
      await add(
        OperationType.expense,
        4500,
        1,
        'cat-transport-taxi-et-moto',
        src: DefaultIds.walletCash,
      );
      await add(
        OperationType.expense,
        15000,
        0,
        'cat-alimentation-marche',
        src: DefaultIds.walletCash,
        note: 'Légumes et poisson',
      );
      await add(
        OperationType.expense,
        2000,
        0,
        'cat-communication-credit-telephone',
        src: DefaultIds.walletMobileMoney,
      );

      await add(
        OperationType.income,
        45000,
        6,
        'cat-activites-annexes',
        dst: DefaultIds.walletMobileMoney,
      );
      // Historique des mois précédents.
      const history = [
        (600000, 0, 540000),
        (600000, 30000, 610000),
        (600000, 0, 480000),
        (650000, 60000, 590000),
        (650000, 20000, 520000),
      ];
      for (final (i, (salary, side, spent)) in history.indexed) {
        final d = DateTime(2026, 6 + i, 25);
        final days = clock.difference(d).inDays;
        await add(
          OperationType.income,
          salary,
          days,
          'cat-salaires',
          dst: DefaultIds.walletBank,
        );
        if (side > 0) {
          await add(
            OperationType.income,
            side,
            days,
            'cat-activites-annexes',
            dst: DefaultIds.walletMobileMoney,
          );
        }
        await add(
          OperationType.expense,
          spent,
          days,
          'cat-logement-loyer',
          src: DefaultIds.walletBank,
        );
      }

      // Le salaire arrive sur la banque ; l'épargne part vers un compte
      // épargne qui porte deux objectifs.
      final compte = await store.addWallet(
        name: 'Compte épargne',
        type: WalletType.bank,
        role: WalletRole.savings,
        openingBalance: 3000000,
      );
      await store.addWallet(
        name: 'Wave',
        type: WalletType.mobileMoney,
        shared: false,
        private: true,
        openingBalance: 12500,
      );
      final surete = await store.addGoal(
        name: 'Épargne de sûreté',
        target: 1500000,
        walletId: compte.id,
        icon: 'surete',
      );
      final construction = await store.addGoal(
        name: 'Épargne de construction',
        target: 8000000,
        targetDate: DateTime(2028, 12),
        walletId: compte.id,
        startAmount: 2200000,
        icon: 'construction',
      );
      // Épargne des mois précédents (le rythme des projections).
      for (final m in [8, 9, 10]) {
        await store.addOperation(
          type: OperationType.transfer,
          amount: 150000,
          date: DateTime(2026, m, 26),
          savingsGoalId: construction.id,
          sourceWalletId: DefaultIds.walletBank,
          targetWalletId: compte.id,
        );
      }
      // Récurrences : salaire attendu le 28, loyer le 2 (dès décembre),
      // abonnement du 26 à confirmer aujourd'hui, épargne automatique.
      await store.addRecurrence(
        type: OperationType.income,
        amount: 650000,
        categoryId: 'cat-salaires',
        targetWalletId: DefaultIds.walletBank,
        dayOfMonth: 28,
        startMonth: DateTime(2026, 12),
      );
      await store.addRecurrence(
        type: OperationType.expense,
        amount: 150000,
        categoryId: 'cat-logement-loyer',
        sourceWalletId: DefaultIds.walletBank,
        dayOfMonth: 2,
        startMonth: DateTime(2026, 12),
        automatic: true,
      );
      await store.addRecurrence(
        type: OperationType.expense,
        amount: 15000,
        categoryId: 'cat-loisirs-abonnements',
        sourceWalletId: DefaultIds.walletMobileMoney,
        dayOfMonth: 26,
        startMonth: DateTime(2026, 11),
        note: 'Canal+',
      );
      // Argent personnel : porte-monnaie, versement du 1er, dépenses perso.
      final purse = await store.addWallet(
        name: 'Porte-monnaie',
        type: WalletType.cash,
        shared: false,
        private: true,
      );
      await store.setupPersonalMoney(
        amount: 30000,
        dayOfMonth: 1,
        fromWalletId: DefaultIds.walletBank,
        toWalletId: purse.id,
      );
      for (final m in [9, 10, 11]) {
        await store.addOperation(
          type: OperationType.expense,
          amount: 30000,
          date: DateTime(2026, m, 1),
          categoryId: 'cat-argent-personnel',
          sourceWalletId: DefaultIds.walletBank,
          targetWalletId: purse.id,
          note: 'Argent personnel',
        );
      }
      for (final (a, cat, note, visible, days) in [
        (8000, 'cat-loisirs-sorties', 'Sortie entre amis', false, 6),
        (6500, 'cat-transport-taxi-et-moto', 'Taxi-moto', false, 3),
        (4000, 'cat-famille', 'Cadeau anniversaire', true, 1),
        (21000, 'cat-loisirs', '', false, 40),
        (17500, 'cat-habillement', '', false, 70),
      ]) {
        await store.addOperation(
          type: OperationType.expense,
          amount: a,
          date: clock.subtract(Duration(days: days)),
          categoryId: cat,
          sourceWalletId: purse.id,
          note: note,
          personal: true,
          visibleToPartner: visible,
        );
      }
      await store.setBudgets(DateTime(2026, 11), {
        'cat-logement': 150000,
        'cat-alimentation': 40000,
        'cat-transport': 5000,
        'cat-communication': 6000,
        'cat-sante': 25000,
      });
      final fondations = await store.addProject(
        name: 'Fondations',
        budget: 1800000,
        targetDate: DateTime(2027, 6),
        goalId: construction.id,
        status: ProjectStatus.active,
      );
      await store.addOperation(
        type: OperationType.expense,
        amount: 350000,
        date: clock.subtract(const Duration(days: 8)),
        categoryId: 'cat-maison',
        sourceWalletId: DefaultIds.walletBank,
        projectId: fondations.id,
        note: 'Ciment et fer',
      );
      for (final (g, a) in [(surete, 100000), (construction, 200000)]) {
        await store.addOperation(
          type: OperationType.transfer,
          amount: a,
          date: clock.subtract(const Duration(days: 3)),
          savingsGoalId: g.id,
          sourceWalletId: DefaultIds.walletBank,
          targetWalletId: compte.id,
        );
      }

      await shot(tester, '1-accueil-$suffix');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await shot(tester, '1b-accueil-revenus-$suffix');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 420));

      await tester.tap(find.byTooltip('Ajouter une opération'));
      await tester.pumpAndSettle();
      for (final k in ['1', '5', '000']) {
        await tester.tap(find.byKey(Key('touche-$k')));
      }
      await tester.tap(find.text('Alimentation'));
      await shot(tester, '2-saisie-$suffix');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Opérations').last);
      await shot(tester, '3-operations-$suffix');

      await tester.tap(find.text('Épargnes').last);
      await shot(tester, '5-epargnes-$suffix');
      await tester.tap(find.byTooltip('Ajouter une opération'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Épargne'));
      for (final k in ['1', '0', '0', '000']) {
        await tester.tap(find.byKey(Key('touche-$k')));
      }
      await shot(tester, '6-saisie-epargne-$suffix');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rapports'));
      await shot(tester, '4-bilan-$suffix');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -520));
      await shot(tester, '4b-bilan-6mois-$suffix');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tendances'));
      await shot(tester, '7-tendances-$suffix');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1700));
      await shot(tester, '7b-tendances-projections-$suffix');

      await tester.tap(find.text('Budgets'));
      await shot(tester, '10-budgets-$suffix');

      await tester.tap(find.text('Épargnes').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await shot(tester, '8-projets-$suffix');
      await tester.ensureVisible(find.text('Épargne de construction').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Épargne de construction').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
      await shot(tester, '9-simulateur-$suffix');
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accueil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Réglages'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mon argent personnel'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Mon argent personnel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mon argent personnel'));
      await shot(tester, '14-argent-personnel-$suffix');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
      await shot(tester, '14b-argent-personnel-$suffix');
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Réglages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opérations récurrentes').last);
      await shot(tester, '13-recurrences-$suffix');
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catégories et sous-catégories'));
      await shot(tester, '11-categories-$suffix');
      await tester.tap(find.text('Alimentation'));
      await shot(tester, '12-categorie-$suffix');
    });
  }
}
