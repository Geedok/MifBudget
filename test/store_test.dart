import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/core/format.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/category.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/state/budget_store.dart';

const cash = DefaultIds.walletCash;
const bank = DefaultIds.walletBank;
const momo = DefaultIds.walletMobileMoney;

void main() {
  late DateTime clock;
  DateTime now() => clock;

  Future<BudgetStore> newStore([BudgetRepository? repo]) async {
    final store = await BudgetStore.open(
      repo ?? MemoryRepository(),
      clock: now,
    );
    await store.completeSetup(
      memberName: 'Eudokia',
      cash: 20000,
      bank: 400000,
      mobileMoney: 50000,
    );
    return store;
  }

  setUp(() => clock = DateTime(2026, 11, 26, 10));

  test("l'installation crée catégories et portefeuilles", () async {
    final store = await newStore();
    expect(store.settings.setupDone, isTrue);
    expect(store.settings.memberName, 'Eudokia');
    expect(store.settings.memberId, isNotEmpty);
    expect(store.wallets.map((w) => w.name), [
      'Espèces',
      'Banque',
      'Mobile Money',
    ]);
    expect(store.topCategories(CategoryKind.expense), hasLength(15));
    expect(store.topCategories(CategoryKind.income).map((c) => c.name), [
      'Salaires',
      'Activités annexes',
      'Autres revenus',
    ]);
    expect(store.subcategories('cat-alimentation').first.name, 'Marché');
    expect(store.totalBalance, 470000);
  });

  test('soldes et totaux du mois recalculés à partir des opérations', () async {
    final store = await newStore();
    await store.addOperation(
      type: OperationType.income,
      amount: 650000,
      date: clock,
      categoryId: 'cat-salaires',
      targetWalletId: bank,
    );
    await store.addOperation(
      type: OperationType.expense,
      amount: 15000,
      date: clock,
      categoryId: 'cat-alimentation-marche',
      sourceWalletId: cash,
    );
    await store.addOperation(
      type: OperationType.transfer,
      amount: 100000,
      date: clock,
      sourceWalletId: bank,
      targetWalletId: momo,
    );
    // Un autre mois : compte dans les soldes, pas dans le mois.
    await store.addOperation(
      type: OperationType.expense,
      amount: 5000,
      date: DateTime(2026, 10, 3),
      categoryId: 'cat-transport',
      sourceWalletId: momo,
    );

    expect(store.walletBalance(cash), 5000);
    expect(store.walletBalance(bank), 950000);
    expect(store.walletBalance(momo), 145000);
    expect(store.totalBalance, 470000 + 650000 - 15000 - 5000);

    final m = store.monthSummary(clock);
    expect(m.income, 650000);
    expect(m.expense, 15000);
    expect(m.balance, 635000);
    expect(store.operationsInMonth(DateTime(2026, 10)), hasLength(1));
  });

  test('suppression douce puis restauration', () async {
    final store = await newStore();
    final op = await store.addOperation(
      type: OperationType.expense,
      amount: 3000,
      date: clock,
      categoryId: 'cat-transport',
      sourceWalletId: cash,
    );
    await store.deleteOperation(op.id);
    expect(store.operations, isEmpty);
    expect(store.walletBalance(cash), 20000);
    expect(store.operation(op.id)!.deleted, isTrue);
    expect(store.operation(op.id)!.deletedAt, clock);

    await store.restoreOperation(op.id);
    expect(store.operations, hasLength(1));
    expect(store.walletBalance(cash), 17000);
  });

  test('catégories fréquentes : les plus utilisées en tête', () async {
    final store = await newStore();
    expect(
      store.frequentCategories(CategoryKind.expense).first.name,
      'Alimentation',
    );

    Future<void> spend(String cat, {DateTime? date}) => store.addOperation(
      type: OperationType.expense,
      amount: 1000,
      date: date ?? clock,
      categoryId: cat,
      sourceWalletId: cash,
    );
    await spend('cat-loisirs');
    await spend('cat-famille-ceremonies');
    clock = clock.add(const Duration(minutes: 1));
    await spend('cat-famille');
    await spend('cat-sante');
    // Trop ancienne pour compter.
    await spend('cat-divers', date: DateTime(2026, 6, 1));
    await spend('cat-divers', date: DateTime(2026, 6, 2));
    await spend('cat-divers', date: DateTime(2026, 6, 3));

    final names = store
        .frequentCategories(CategoryKind.expense)
        .map((c) => c.name);
    expect(names.take(3), ['Famille et solidarité', 'Santé', 'Loisirs']);
    expect(names, hasLength(7));
    expect(names, isNot(contains('Divers')));
  });

  test('portefeuille de la dernière dépense présélectionné', () async {
    final store = await newStore();
    expect(store.lastWalletFor(OperationType.expense), isNull);
    await store.addOperation(
      type: OperationType.expense,
      amount: 1000,
      date: clock,
      categoryId: 'cat-transport',
      sourceWalletId: momo,
    );
    expect(store.lastWalletFor(OperationType.expense), momo);
    expect(store.lastWalletFor(OperationType.income), isNull);
  });

  test('les données survivent à un redémarrage (fichier JSON)', () async {
    final dir = await Directory.systemTemp.createTemp('mifbudget');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/mifbudget.json');

    final store = await newStore(LocalJsonRepository(file));
    final op = await store.addOperation(
      type: OperationType.expense,
      amount: 18500,
      date: DateTime(2026, 11, 25),
      categoryId: 'cat-logement-electricite',
      sourceWalletId: momo,
      note: 'Facture novembre',
    );
    await store.deleteOperation(op.id);
    await store.restoreOperation(op.id);

    final reopened = await BudgetStore.open(
      LocalJsonRepository(file),
      clock: now,
    );
    expect(reopened.settings.memberName, 'Eudokia');
    expect(reopened.wallets, hasLength(3));
    expect(reopened.operations, hasLength(1));
    final loaded = reopened.operations.single;
    expect(loaded.amount, 18500);
    expect(loaded.date, DateTime(2026, 11, 25));
    expect(loaded.note, 'Facture novembre');
    expect(loaded.deleted, isFalse);
    expect(reopened.walletBalance(momo), 31500);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('revenus du mois par source, avec détail par sous-catégorie', () async {
    final store = await newStore();
    Future<void> add(OperationType t, int a, String cat, {DateTime? date}) =>
        store.addOperation(
          type: t,
          amount: a,
          date: date ?? clock,
          categoryId: cat,
          sourceWalletId: t == OperationType.expense ? cash : null,
          targetWalletId: t == OperationType.income ? bank : null,
        );
    await add(OperationType.income, 400000, 'cat-salaires');
    await add(OperationType.income, 250000, 'cat-salaires');
    await add(OperationType.income, 45000, 'cat-activites-annexes');
    await add(
      OperationType.income,
      99000,
      'cat-salaires',
      date: DateTime(2026, 10, 28),
    );
    await add(OperationType.expense, 15000, 'cat-alimentation-marche');
    await add(OperationType.expense, 5000, 'cat-alimentation');
    await add(OperationType.expense, 30000, 'cat-transport');

    final incomes = store.totalsByCategory(clock, CategoryKind.income);
    expect(incomes.map((t) => (t.category!.name, t.amount, t.count)), [
      ('Salaires', 650000, 2),
      ('Activités annexes', 45000, 1),
    ]);

    final expenses = store.totalsByCategory(clock, CategoryKind.expense);
    expect(expenses.map((t) => (t.category!.name, t.amount)), [
      ('Transport', 30000),
      ('Alimentation', 20000),
    ]);
    final food = expenses[1];
    expect(food.subs.map((t) => (t.category!.name, t.amount)), [
      ('Marché', 15000),
      ('Alimentation', 5000),
    ]);
  });

  test('résumé des 6 derniers mois, du plus ancien au plus récent', () async {
    final store = await newStore();
    await store.addOperation(
      type: OperationType.income,
      amount: 600000,
      date: DateTime(2026, 9, 25),
      categoryId: 'cat-salaires',
      targetWalletId: bank,
    );
    await store.addOperation(
      type: OperationType.expense,
      amount: 12000,
      date: DateTime(2026, 2, 1),
      categoryId: 'cat-transport',
      sourceWalletId: cash,
    );

    final months = store.recentMonths(DateTime(2026, 11));
    expect(months.map((m) => monthKey(m.month!)), [
      '2026-06',
      '2026-07',
      '2026-08',
      '2026-09',
      '2026-10',
      '2026-11',
    ]);
    expect(months[3].income, 600000);
    expect(months.fold(0, (s, m) => s + m.expense), 0);

    // Passage d'année.
    final early = store.recentMonths(DateTime(2026, 3), count: 3);
    expect(early.map((m) => monthKey(m.month!)), [
      '2026-01',
      '2026-02',
      '2026-03',
    ]);
    expect(early[1].expense, 12000);
    expect(early[1].spentRatio, 0);
  });
}
