import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
