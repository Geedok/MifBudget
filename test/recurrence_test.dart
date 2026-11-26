import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/recurrence.dart';
import 'package:mifbudget/state/budget_store.dart';

const bank = DefaultIds.walletBank;

void main() {
  var clock = DateTime(2026, 11, 26, 10);
  DateTime now() => clock;

  setUp(() => clock = DateTime(2026, 11, 26, 10));

  Future<BudgetStore> newStore([BudgetRepository? repo]) async {
    final store = await BudgetStore.open(
      repo ?? MemoryRepository(),
      clock: now,
    );
    await store.completeSetup(memberName: 'Eudokia', bank: 1000000);
    return store;
  }

  Future<Recurrence> rent(
    BudgetStore store, {
    int day = 5,
    DateTime? start,
    bool automatic = false,
  }) => store.addRecurrence(
    type: OperationType.expense,
    amount: 150000,
    categoryId: 'cat-logement-loyer',
    sourceWalletId: bank,
    dayOfMonth: day,
    startMonth: start ?? DateTime(2026, 11),
    automatic: automatic,
  );

  test('date de l\'échéance : le 31 devient le dernier jour du mois', () {
    final r = Recurrence(
      id: 'r',
      type: OperationType.expense,
      amount: 1,
      dayOfMonth: 31,
      startMonth: DateTime(2026, 1),
      endMonth: DateTime(2026, 6),
      createdAt: clock,
      updatedAt: clock,
    );
    expect(r.dateIn(DateTime(2026, 2)), DateTime(2026, 2, 28));
    expect(r.dateIn(DateTime(2026, 4)), DateTime(2026, 4, 30));
    expect(r.covers(DateTime(2025, 12)), isFalse);
    expect(r.covers(DateTime(2026, 6)), isTrue);
    expect(r.covers(DateTime(2026, 7)), isFalse);
    expect(r.operationIdFor(DateTime(2026, 3)), 'rec-r-2026-03');
  });

  test('à confirmer : proposée le jour venu, confirmée ou ignorée', () async {
    final store = await newStore();
    final r = await rent(store);
    // Le 5 novembre est passé : l'échéance est à confirmer, rien d'enregistré.
    expect(store.operations, isEmpty);
    final pending = store.pendingOccurrences;
    expect(pending, hasLength(1));
    expect(pending.single.date, DateTime(2026, 11, 5));
    // Décembre est à venir.
    expect(store.upcomingOccurrences().single.date, DateTime(2026, 12, 5));

    final op = await store.confirmOccurrence(pending.single, amount: 155000);
    expect(op.id, 'rec-${r.id}-2026-11');
    expect(op.amount, 155000);
    expect(op.recurrenceId, r.id);
    expect(op.date, DateTime(2026, 11, 5));
    expect(store.pendingOccurrences, isEmpty);
    expect(store.walletBalance(bank), 845000);

    // Deux mois plus tard : décembre et janvier sont à confirmer.
    clock = DateTime(2027, 1, 10);
    expect(store.pendingOccurrences.map((o) => o.date), [
      DateTime(2026, 12, 5),
      DateTime(2027, 1, 5),
    ]);
    await store.skipOccurrence(store.pendingOccurrences.first);
    expect(store.pendingOccurrences.single.date, DateTime(2027, 1, 5));
    // L'échéance ignorée n'est pas comptée.
    expect(store.walletBalance(bank), 845000);
  });

  test(
    'automatique : enregistrée seule, avec rattrapage, sans doublon',
    () async {
      final repo = MemoryRepository();
      final store = await newStore(repo);
      await rent(store, start: DateTime(2026, 9), automatic: true);
      // Septembre, octobre, novembre (le 5 est passé).
      expect(store.operations.map((o) => o.date), [
        DateTime(2026, 11, 5),
        DateTime(2026, 10, 5),
        DateTime(2026, 9, 5),
      ]);
      expect(store.pendingOccurrences, isEmpty);

      // Réouverture plus tard : décembre est ajouté, rien en double.
      clock = DateTime(2026, 12, 6);
      final reopened = await BudgetStore.open(repo, clock: now);
      expect(reopened.operations, hasLength(4));

      // Une opération automatique supprimée n'est pas recréée.
      await reopened.deleteOperation(reopened.operations.first.id);
      expect(await reopened.processAutomaticRecurrences(), 0);
      expect(reopened.operations, hasLength(3));
    },
  );

  test('pause, arrêt et date de fin', () async {
    final store = await newStore();
    final r = await rent(store);
    await store.updateRecurrence(r.copyWith(paused: true));
    expect(store.pendingOccurrences, isEmpty);
    expect(store.upcomingOccurrences(), isEmpty);
    await store.updateRecurrence(
      store
          .recurrence(r.id)!
          .copyWith(paused: false, endMonth: () => DateTime(2026, 11)),
    );
    expect(store.pendingOccurrences, hasLength(1));
    expect(store.upcomingOccurrences(), isEmpty); // décembre : après la fin
    await store.updateRecurrence(
      store.recurrence(r.id)!.copyWith(stopped: true),
    );
    expect(store.recurrences, isEmpty);
    expect(store.stoppedRecurrences, hasLength(1));
    expect(store.pendingOccurrences, isEmpty);
  });

  test(
    "rendre récurrente une opération déjà saisie ne la double pas",
    () async {
      final store = await newStore();
      final op = await store.addOperation(
        type: OperationType.expense,
        amount: 150000,
        date: DateTime(2026, 11, 4),
        categoryId: 'cat-logement-loyer',
        sourceWalletId: bank,
      );
      final r = await store.addRecurrence(
        type: op.type,
        amount: op.amount,
        categoryId: op.categoryId,
        sourceWalletId: op.sourceWalletId,
        dayOfMonth: 5,
        startMonth: DateTime(2026, 11),
        linkedOperationId: op.id,
      );
      expect(store.operation(op.id)!.recurrenceId, r.id);
      expect(store.pendingOccurrences, isEmpty);
      expect(store.operations, hasLength(1));
    },
  );

  test('revenus attendus et dépenses prévues du mois', () async {
    final store = await newStore();
    await store.addRecurrence(
      type: OperationType.income,
      amount: 650000,
      categoryId: 'cat-salaires',
      targetWalletId: bank,
      dayOfMonth: 28,
      startMonth: DateTime(2026, 11),
    );
    await rent(store, day: 30);
    await store.addRecurrence(
      type: OperationType.expense,
      amount: 15000,
      categoryId: 'cat-loisirs-abonnements',
      sourceWalletId: bank,
      dayOfMonth: 10,
      startMonth: DateTime(2026, 11),
    );
    final month = DateTime(2026, 11);
    expect(store.expectedIncomes(month).single.recurrence.amount, 650000);
    // Le loyer (le 30) et l'abonnement (le 10, à confirmer) restent prévus.
    expect(store.plannedExpenses(month), 165000);
    expect(store.plannedExpenses(month, categoryId: 'cat-logement'), 150000);
    expect(store.remainingInMonth(month), hasLength(3));
  });
}
