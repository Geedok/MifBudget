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
        bank: 412000,
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

      await shot(tester, '1-accueil-$suffix');

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
    });
  }
}
