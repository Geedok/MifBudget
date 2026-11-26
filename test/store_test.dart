import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/core/format.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/category.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/wallet.dart';
import 'package:mifbudget/models/savings_goal.dart';
import 'package:mifbudget/models/settings.dart';
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

  group('épargnes', () {
    test('versement mensuel nécessaire pour tenir la date cible', () async {
      final store = await newStore();
      final g = await store.addGoal(
        name: 'Construction',
        target: 8000000,
        startAmount: 2400000,
        targetDate: DateTime(2027, 12, 15),
      );
      expect(store.goal(g.id)!.targetDate, DateTime(2027, 12));
      // Novembre 2026 → décembre 2027 : 14 mois, mois en cours compris.
      expect(store.monthlyNeeded(g), 400000);

      final sansDate = await store.addGoal(name: 'Voyage', target: 500000);
      expect(store.monthlyNeeded(sansDate), isNull);

      final passee = await store.addGoal(
        name: 'Passée',
        target: 100000,
        targetDate: DateTime(2026, 3),
      );
      expect(store.monthlyNeeded(passee), 100000);
    });

    test('dépenses mensuelles moyennes des 3 derniers mois complets', () async {
      final store = await newStore();
      Future<void> spend(int a, DateTime d) => store.addOperation(
        type: OperationType.expense,
        amount: a,
        date: d,
        categoryId: 'cat-transport',
        sourceWalletId: cash,
      );
      await spend(300000, DateTime(2026, 10, 3));
      await spend(500000, DateTime(2026, 9, 3));
      await spend(999999, clock); // mois en cours : ignoré
      expect(store.averageMonthlyExpense(), 400000);
    });

    test(
      "épargner = virer d'un compte courant vers un compte épargne",
      () async {
        final store = await newStore();
        final compte = await store.addWallet(
          name: 'Compte épargne',
          type: WalletType.bank,
          role: WalletRole.savings,
          openingBalance: 500000,
        );
        expect(store.savingsWallets.single.id, compte.id);
        expect(store.currentWallets.map((w) => w.id), [cash, bank, momo]);
        expect(store.totalSaved, 500000);
        expect(store.available, 470000);

        // Seul objectif du compte : il en a tout le solde.
        final surete = await store.addGoal(
          name: 'Sûreté',
          target: 1500000,
          walletId: compte.id,
          icon: 'surete',
        );
        expect(store.goalBalance(surete.id), 500000);
        expect(store.unallocated(compte.id), 0);

        Future<Operation> move(int a, String from, String to) =>
            store.addOperation(
              type: OperationType.transfer,
              amount: a,
              date: clock,
              sourceWalletId: from,
              targetWalletId: to,
            );
        final versement = await move(100000, bank, compte.id);
        await move(30000, compte.id, cash);
        expect(store.savingsDirection(versement), 1);
        expect(store.walletBalance(bank), 300000);
        expect(store.walletBalance(compte.id), 570000);
        expect(store.goalBalance(surete.id), 570000);
        expect(store.totalSaved, 570000);
        expect(store.available, 400000);
        final m = store.monthSummary(clock);
        expect(m.saved, 70000);
        expect(m.expense, 0);
        expect(m.income, 0);

        // Un virement entre comptes courants ne compte pas comme épargne.
        await move(5000, cash, momo);
        expect(store.monthSummary(clock).saved, 70000);
      },
    );

    test(
      'plusieurs objectifs sur un même compte, et la part non répartie',
      () async {
        final store = await newStore();
        final compte = await store.addWallet(
          name: 'Compte épargne',
          type: WalletType.bank,
          role: WalletRole.savings,
          openingBalance: 1000000,
        );
        final surete = await store.addGoal(
          name: 'Sûreté',
          target: 1500000,
          walletId: compte.id,
        );
        // Le deuxième objectif prend 300 000 sur le premier.
        final construction = await store.addGoal(
          name: 'Construction',
          target: 8000000,
          walletId: compte.id,
          startAmount: 300000,
        );
        expect(store.goalBalance(surete.id), 700000);
        expect(store.goalBalance(construction.id), 300000);
        expect(store.unallocated(compte.id), 0);

        Future<void> move(int a, String from, String to, [String? goal]) =>
            store.addOperation(
              type: OperationType.transfer,
              amount: a,
              date: clock,
              sourceWalletId: from,
              targetWalletId: to,
              savingsGoalId: goal,
            );
        await move(200000, bank, compte.id, construction.id);
        await move(50000, bank, compte.id); // non réparti
        await move(20000, compte.id, cash, surete.id);
        expect(store.goalBalance(construction.id), 500000);
        expect(store.goalBalance(surete.id), 680000);
        expect(store.unallocated(compte.id), 50000);
        expect(store.walletBalance(compte.id), 1230000);
        expect(store.goalOperations(construction.id), hasLength(1));

        // Archiver l'un : l'autre redevient seul et reprend tout le compte.
        await store.updateGoal(
          store.goal(construction.id)!.copyWith(archived: true),
        );
        expect(store.goalBalance(surete.id), 1230000);
      },
    );

    test('deux comptes épargne, un objectif chacun', () async {
      final store = await newStore();
      Future<Wallet> account(String name, int opening) => store.addWallet(
        name: name,
        type: WalletType.bank,
        role: WalletRole.savings,
        openingBalance: opening,
      );
      final a = await account('Épargne sûreté', 900000);
      final b = await account('Épargne construction', 2400000);
      final ga = await store.addGoal(
        name: 'Sûreté',
        target: 1500000,
        walletId: a.id,
      );
      final gb = await store.addGoal(
        name: 'Construction',
        target: 8000000,
        walletId: b.id,
      );
      expect(store.goalBalance(ga.id), 900000);
      expect(store.goalBalance(gb.id), 2400000);
      expect(store.totalSaved, 3300000);
      // Un virement d'un compte épargne à l'autre ne change pas l'épargne.
      await store.addOperation(
        type: OperationType.transfer,
        amount: 100000,
        date: clock,
        sourceWalletId: a.id,
        targetWalletId: b.id,
      );
      expect(store.monthSummary(clock).saved, 0);
      expect(store.goalBalance(gb.id), 2500000);
    });

    test('portefeuille personnel privé', () async {
      final store = await newStore();
      final wave = await store.addWallet(
        name: 'Wave',
        type: WalletType.mobileMoney,
        shared: false,
        private: true,
      );
      expect(wave.isPrivate, isTrue);
      expect(wave.ownerId, store.settings.memberId);
      // Un portefeuille commun n'est jamais privé.
      final commun = await store.addWallet(
        name: 'Caisse',
        type: WalletType.cash,
        private: true,
      );
      expect(commun.isPrivate, isFalse);
      expect(commun.ownerId, isNull);
    });

    test('reprise des épargnes de la version 0.3.0', () async {
      final t = DateTime(2026, 11, 20);
      final repo = MemoryRepository(
        BudgetData(
          version: 1,
          settings: const AppSettings(
            setupDone: true,
            memberId: 'moi',
            memberName: 'Eudokia',
          ),
          wallets: defaultWallets(t, cash: 20000, bank: 1000000),
          categories: defaultCategories(t),
          goals: [
            SavingsGoal(
              id: 'g1',
              name: 'Épargne de sûreté',
              target: 1500000,
              walletId: bank,
              startAmount: 300000,
              createdAt: t,
              updatedAt: t,
            ),
          ],
          operations: [
            Operation(
              id: 'v1',
              type: OperationType.savingsDeposit,
              amount: 100000,
              date: t,
              savingsGoalId: 'g1',
              sourceWalletId: bank,
              authorId: 'moi',
              createdAt: t,
              updatedAt: t,
            ),
            Operation(
              id: 'r1',
              type: OperationType.savingsWithdrawal,
              amount: 30000,
              date: t,
              savingsGoalId: 'g1',
              targetWalletId: bank,
              authorId: 'moi',
              createdAt: t,
              updatedAt: t,
            ),
          ],
        ),
      );
      final store = await BudgetStore.open(repo, clock: now);
      final compte = store.savingsWallets.single;
      expect(compte.name, 'Compte épargne');
      expect(store.goal('g1')!.walletId, compte.id);
      expect(store.walletBalance(compte.id), 370000);
      expect(store.goalBalance('g1'), 370000);
      expect(store.walletBalance(bank), 630000);
      // Le disponible ne change pas : 1 020 000 − 370 000.
      expect(store.available, 650000);
      expect(store.operation('v1')!.type, OperationType.transfer);
      expect(store.operation('v1')!.targetWalletId, compte.id);
      expect(store.operation('r1')!.sourceWalletId, compte.id);
      expect(store.operation('r1')!.targetWalletId, bank);

      // Pas de deuxième reprise à la réouverture.
      final again = await BudgetStore.open(repo, clock: now);
      expect(again.savingsWallets, hasLength(1));
      expect(again.walletBalance(compte.id), 370000);
    });

    test('comptes et objectifs sont enregistrés dans le fichier', () async {
      final dir = await Directory.systemTemp.createTemp('mifbudget');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/mifbudget.json');
      final store = await newStore(LocalJsonRepository(file));
      final compte = await store.addWallet(
        name: 'Compte épargne',
        type: WalletType.bank,
        role: WalletRole.savings,
        openingBalance: 2400000,
        shared: false,
        private: true,
      );
      final g = await store.addGoal(
        name: 'Épargne de construction',
        target: 8000000,
        targetDate: DateTime(2028, 12),
        walletId: compte.id,
        icon: 'construction',
      );
      await store.addOperation(
        type: OperationType.transfer,
        amount: 225000,
        date: clock,
        sourceWalletId: bank,
        targetWalletId: compte.id,
      );

      final reopened = await BudgetStore.open(
        LocalJsonRepository(file),
        clock: now,
      );
      final w = reopened.savingsWallets.single;
      expect(w.isSavings, isTrue);
      expect(w.isPrivate, isTrue);
      final loaded = reopened.goals.single;
      expect(loaded.targetDate, DateTime(2028, 12));
      expect(loaded.walletId, compte.id);
      expect(reopened.goalBalance(g.id), 2625000);
    });
  });
}
