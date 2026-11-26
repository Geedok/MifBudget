import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/core/projection.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/category.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/project.dart';
import 'package:mifbudget/models/wallet.dart';
import 'package:mifbudget/state/budget_store.dart';

const cash = DefaultIds.walletCash;
const bank = DefaultIds.walletBank;

void main() {
  final clock = DateTime(2026, 11, 26, 10);

  test('mois nécessaires et date atteinte', () {
    expect(monthsToReach(0, 100), 0);
    expect(monthsToReach(1000, 0), isNull);
    expect(monthsToReach(1000, 300), 4);
    // Le mois en cours compte comme le premier versement.
    expect(reachDate(clock, 1000, 300), DateTime(2027, 2));
    expect(reachDate(clock, 300, 300), DateTime(2026, 11));
    expect(reachDate(clock, -5, 300), DateTime(2026, 11));
    expect(monthsBetween(DateTime(2026, 11), DateTime(2028, 2)), 15);
    expect(average([1, 2, 4]), 2);
    expect(average(const []), 0);
  });

  Future<(BudgetStore, Wallet)> setup() async {
    final store = await BudgetStore.open(
      MemoryRepository(),
      clock: () => clock,
    );
    await store.completeSetup(memberName: 'Eudokia', bank: 1000000);
    final compte = await store.addWallet(
      name: 'Compte épargne',
      type: WalletType.bank,
      role: WalletRole.savings,
    );
    // Trois mois complets (août, septembre, octobre) et le mois en cours.
    for (final (month, salary, spent, saved) in [
      (8, 600000, 400000, 100000),
      (9, 600000, 500000, 50000),
      (10, 650000, 450000, 150000),
      (11, 650000, 900000, 0),
    ]) {
      final d = DateTime(2026, month, 25);
      await store.addOperation(
        type: OperationType.income,
        amount: salary,
        date: d,
        categoryId: 'cat-salaires',
        targetWalletId: bank,
      );
      await store.addOperation(
        type: OperationType.expense,
        amount: spent,
        date: d,
        categoryId: month == 10 ? 'cat-transport' : 'cat-alimentation',
        sourceWalletId: bank,
      );
      if (saved > 0) {
        await store.addOperation(
          type: OperationType.transfer,
          amount: saved,
          date: d,
          sourceWalletId: bank,
          targetWalletId: compte.id,
        );
      }
    }
    return (store, compte);
  }

  test(
    'moyennes et capacité d\'épargne sur les 3 derniers mois complets',
    () async {
      final (store, _) = await setup();
      expect(store.firstActivityMonth, DateTime(2026, 8));
      expect(store.lastCompleteMonths(12), [
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
      ]);
      final a = store.averages();
      expect(a.months, 3);
      expect(a.income, 616667);
      expect(a.expense, 450000);
      expect(a.saved, 100000);
      expect(a.leftover, 166667);
      expect(a.savingsRate, closeTo(0.162, 0.001));
    },
  );

  test("rythme et date estimée d'un objectif", () async {
    final (store, compte) = await setup();
    final g = await store.addGoal(
      name: 'Sûreté',
      target: 1500000,
      walletId: compte.id,
    );
    expect(store.goalBalance(g.id), 300000);
    expect(store.goalPace(g), 100000);
    // Il manque 1 200 000 à 100 000 par mois : 12 mois, novembre compris.
    expect(store.goalReachDate(g), DateTime(2027, 10));

    final immobile = await store.addGoal(
      name: 'Voyage',
      target: 500000,
      walletId: (await store.addWallet(
        name: 'Autre',
        type: WalletType.bank,
        role: WalletRole.savings,
      )).id,
    );
    expect(store.goalReachDate(immobile), isNull);
  });

  test('tendances par catégorie', () async {
    final (store, _) = await setup();
    final trends = store.categoryTrends(CategoryKind.expense);
    final food = trends.firstWhere((t) => t.category?.name == 'Alimentation');
    expect(food.recent, 300000); // (400 000 + 500 000) / 3
    expect(food.previous, 0); // rien avant août
    expect(food.change, isNull);
    final transport = trends.firstWhere((t) => t.category?.name == 'Transport');
    expect(transport.recent, 150000);
  });

  test('projet : dépenses, financement et date', () async {
    final (store, compte) = await setup();
    final g = await store.addGoal(
      name: 'Construction',
      target: 8000000,
      walletId: compte.id,
    );
    final p = await store.addProject(
      name: 'Fondations',
      budget: 1800000,
      goalId: g.id,
      status: ProjectStatus.active,
    );
    await store.addOperation(
      type: OperationType.expense,
      amount: 500000,
      date: clock,
      categoryId: 'cat-maison',
      sourceWalletId: bank,
      projectId: p.id,
    );
    expect(store.projectSpent(p.id), 500000);
    // 1 800 000 − 500 000 dépensés − 300 000 épargnés.
    expect(store.projectToFund(p), 1000000);
    expect(store.projectFundingDate(p), DateTime(2027, 8));
    expect(store.openProjects.single.id, p.id);

    await store.updateProject(p.copyWith(status: ProjectStatus.done));
    expect(store.openProjects, isEmpty);
    expect(store.projects.single.status, ProjectStatus.done);
  });
}
