import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/category.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/wallet.dart';
import 'package:mifbudget/state/budget_store.dart';

const bank = DefaultIds.walletBank;

void main() {
  final clock = DateTime(2026, 11, 27, 10);
  final nov = DateTime(2026, 11);

  Future<(BudgetStore, Wallet, Wallet)> setup() async {
    final store = await BudgetStore.open(
      MemoryRepository(),
      clock: () => clock,
    );
    await store.completeSetup(memberName: 'Eudokia', bank: 500000);
    final purse = await store.addWallet(
      name: 'Porte-monnaie',
      type: WalletType.cash,
      shared: false,
      private: true,
    );
    final momo = await store.addWallet(
      name: 'Mobile Money perso',
      type: WalletType.mobileMoney,
      shared: false,
      private: true,
    );
    return (store, purse, momo);
  }

  test(
    'versement mensuel : dépense du foyer qui alimente le porte-monnaie',
    () async {
      final (store, purse, _) = await setup();
      expect(store.personalWallets, hasLength(2));
      // Les portefeuilles personnels ne font pas partie du disponible.
      expect(
        store.householdCurrentWallets.map((w) => w.id),
        isNot(contains(purse.id)),
      );

      await store.setupPersonalMoney(
        amount: 30000,
        dayOfMonth: 27,
        fromWalletId: bank,
        toWalletId: purse.id,
      );
      expect(store.settings.personalMoney, isTrue);
      final r = store.allowance!;
      expect(r.automatic, isFalse);
      expect(r.type, OperationType.expense);
      expect(r.categoryId, 'cat-argent-personnel');
      expect(r.startMonth, nov); // le 27 : aujourd'hui, ce mois-ci

      // À confirmer, montant ajustable.
      final pending = store.pendingOccurrences.single;
      await store.confirmOccurrence(pending, amount: 35000);
      expect(store.walletBalance(purse.id), 35000);
      expect(store.walletBalance(bank), 465000);
      expect(store.available, 465000);
      expect(store.personalBalance, 35000);
      expect(store.personalReceived(nov), 35000);
      // Le versement compte dans les dépenses du foyer.
      expect(store.monthSummary(nov).expense, 35000);
      expect(store.spentIn(nov, 'cat-argent-personnel'), 35000);
    },
  );

  test('les dépenses personnelles ne comptent pas pour le foyer', () async {
    final (store, purse, momo) = await setup();
    await store.addOperation(
      type: OperationType.transfer,
      amount: 30000,
      date: clock,
      sourceWalletId: bank,
      targetWalletId: purse.id,
    );
    await store.addOperation(
      type: OperationType.expense,
      amount: 8000,
      date: clock,
      categoryId: 'cat-loisirs-sorties',
      sourceWalletId: purse.id,
      personal: true,
      visibleToPartner: false,
    );
    await store.addOperation(
      type: OperationType.expense,
      amount: 4000,
      date: clock,
      categoryId: 'cat-famille',
      sourceWalletId: purse.id,
      personal: true,
    );
    // Porte-monnaie → Mobile Money perso : le reste ne bouge pas.
    await store.addOperation(
      type: OperationType.transfer,
      amount: 10000,
      date: clock,
      sourceWalletId: purse.id,
      targetWalletId: momo.id,
    );
    expect(store.personalBalance, 18000);
    expect(store.personalReceived(nov), 30000);
    expect(store.personalSpent(nov), 12000);
    expect(store.personalByCategory(nov).map((t) => t.category!.name), [
      'Loisirs',
      'Famille et solidarité',
    ]);
    // Rien de tout cela dans les chiffres du foyer.
    expect(store.monthSummary(nov).expense, 0);
    expect(store.spentIn(nov, 'cat-loisirs'), 0);
    expect(store.totalsByCategory(nov, CategoryKind.expense), isEmpty);
  });

  test('facture du foyer payée avec le Mobile Money perso', () async {
    final (store, _, momo) = await setup();
    // De l'argent du foyer déposé sur le Mobile Money perso…
    await store.addOperation(
      type: OperationType.transfer,
      amount: 18500,
      date: clock,
      sourceWalletId: bank,
      targetWalletId: momo.id,
    );
    // … pour payer l'électricité : une dépense du foyer.
    await store.addOperation(
      type: OperationType.expense,
      amount: 18500,
      date: clock,
      categoryId: 'cat-logement-electricite',
      sourceWalletId: momo.id,
    );
    expect(store.monthSummary(nov).expense, 18500);
    expect(store.spentIn(nov, 'cat-logement'), 18500);
    expect(store.personalSpent(nov), 0);
    expect(store.personalBalance, 0);
  });

  test("désactiver l'argent personnel arrête le versement", () async {
    final (store, purse, _) = await setup();
    await store.setupPersonalMoney(
      amount: 30000,
      dayOfMonth: 1,
      fromWalletId: bank,
      toWalletId: purse.id,
    );
    // Le 1er est passé : premier versement en décembre.
    expect(store.allowance!.startMonth, DateTime(2026, 12));
    expect(store.pendingOccurrences, isEmpty);
    await store.setupPersonalMoney(
      amount: 40000,
      dayOfMonth: 1,
      fromWalletId: bank,
      toWalletId: purse.id,
    );
    expect(store.recurrences, hasLength(1));
    expect(store.allowance!.amount, 40000);
    await store.disablePersonalMoney();
    expect(store.settings.personalMoney, isFalse);
    expect(store.allowance, isNull);
    expect(store.recurrences, isEmpty);
    expect(store.personalWallets, hasLength(2));
  });
}
