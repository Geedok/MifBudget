import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/budget.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/state/budget_store.dart';

const cash = DefaultIds.walletCash;

void main() {
  final clock = DateTime(2026, 11, 26, 10);
  final nov = DateTime(2026, 11);
  final dec = DateTime(2026, 12);

  Future<BudgetStore> newStore([BudgetRepository? repo]) async {
    final store = await BudgetStore.open(
      repo ?? MemoryRepository(),
      clock: () => clock,
    );
    await store.completeSetup(memberName: 'Eudokia', cash: 2000000);
    return store;
  }

  Future<void> spend(BudgetStore s, int a, String cat, DateTime d) =>
      s.addOperation(
        type: OperationType.expense,
        amount: a,
        date: d,
        categoryId: cat,
        sourceWalletId: cash,
      );

  test('seuils : vert sous 80 %, orange jusqu\'à 100 %, rouge au-delà', () {
    expect(budgetStatus(79, 100), BudgetStatus.ok);
    expect(budgetStatus(80, 100), BudgetStatus.warning);
    expect(budgetStatus(100, 100), BudgetStatus.warning);
    expect(budgetStatus(101, 100), BudgetStatus.over);
    expect(budgetStatus(50, 0), BudgetStatus.ok);
  });

  test('plafonds du mois et dépenses par catégorie', () async {
    final store = await newStore();
    await store.setBudgets(nov, {
      'cat-transport': 60000,
      'cat-alimentation': 120000,
      'cat-sante': 0,
    });
    // Dans l'ordre des catégories, sans celles à 0.
    expect(store.budgetsFor(nov).map((b) => b.categoryId), [
      'cat-alimentation',
      'cat-transport',
    ]);
    expect(store.budgetsFor(dec), isEmpty);

    await spend(store, 100000, 'cat-alimentation-marche', clock);
    await spend(store, 32000, 'cat-alimentation', clock);
    await spend(store, 9999, 'cat-alimentation', DateTime(2026, 10, 3));
    expect(store.spentIn(nov, 'cat-alimentation'), 132000);
    expect(
      budgetStatus(store.spentIn(nov, 'cat-alimentation'), 120000),
      BudgetStatus.over,
    );

    // Retirer un budget : plafond à 0.
    await store.setBudgets(nov, {'cat-transport': 0});
    expect(store.budgetsFor(nov), hasLength(1));
  });

  test('plafond proposé : moyenne des 3 mois précédents, au millier', () async {
    final store = await newStore();
    expect(store.suggestedLimit(nov, 'cat-transport'), isNull);
    await spend(store, 50000, 'cat-transport', DateTime(2026, 9, 10));
    await spend(store, 60500, 'cat-transport', DateTime(2026, 10, 10));
    await spend(store, 999999, 'cat-transport', clock); // novembre : ignoré
    // Septembre et octobre seulement (rien n'est saisi avant septembre).
    expect(store.suggestedLimit(nov, 'cat-transport'), 56000);
    // Pour décembre : septembre, octobre, novembre.
    expect(store.suggestedLimit(dec, 'cat-transport'), 371000);
    expect(store.suggestedLimit(nov, 'cat-sante'), isNull);
  });

  test('copier les plafonds du mois précédent sans écraser', () async {
    final store = await newStore();
    await store.setBudgets(nov, {
      'cat-transport': 60000,
      'cat-alimentation': 120000,
    });
    await store.setBudgets(dec, {'cat-transport': 70000});
    expect(await store.copyPreviousBudgets(dec), 1);
    expect(store.budgetLimit(dec, 'cat-transport'), 70000);
    expect(store.budgetLimit(dec, 'cat-alimentation'), 120000);
    expect(await store.copyPreviousBudgets(dec), 0);
  });

  test('les budgets sont enregistrés dans le fichier', () async {
    final dir = await Directory.systemTemp.createTemp('mifbudget');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/mifbudget.json');
    final store = await newStore(LocalJsonRepository(file));
    await store.setBudgets(nov, {'cat-logement': 125000});
    final reopened = await BudgetStore.open(
      LocalJsonRepository(file),
      clock: () => clock,
    );
    expect(reopened.budgetLimit(nov, 'cat-logement'), 125000);
    expect(reopened.budgetsFor(nov).single.id, '2026-11:cat-logement');
  });
}
