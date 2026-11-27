import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/models/settings.dart';
import 'package:mifbudget/models/wallet.dart';
import 'package:mifbudget/state/budget_store.dart';
import 'package:mifbudget/sync/firestore_repository.dart';
import 'package:mifbudget/sync/household_service.dart';

const bank = DefaultIds.walletBank;
const cash = DefaultIds.walletCash;

void main() {
  final clock = DateTime(2026, 11, 27, 10);
  late FakeFirebaseFirestore db;
  late Directory dir;

  setUp(() async {
    db = FakeFirebaseFirestore();
    dir = await Directory.systemTemp.createTemp('mifbudget-sync');
  });
  tearDown(() => dir.delete(recursive: true));

  /// Le téléphone d'Eudokia avant la synchronisation : données locales.
  Future<BudgetStore> localPhone() async {
    final store = await BudgetStore.open(
      LocalJsonRepository(File('${dir.path}/eudokia-local.json')),
      clock: () => clock,
    );
    await store.completeSetup(memberName: 'Eudokia', bank: 500000, cash: 20000);
    return store;
  }

  /// Un téléphone branché sur le foyer.
  Future<BudgetStore> sharedPhone(
    String householdId,
    String uid,
    String name,
  ) => BudgetStore.open(
    FirestoreRepository(
      firestore: db,
      householdId: householdId,
      memberId: uid,
      local: MemoryRepository(
        BudgetData(
          settings: AppSettings(
            setupDone: true,
            memberId: uid,
            memberName: name,
            householdId: householdId,
          ),
        ),
      ),
    ),
    clock: () => clock,
  );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('créer le foyer copie les données, invitation puis adhésion', () async {
    final local = await localPhone();
    final purse = await local.addWallet(
      name: 'Porte-monnaie',
      type: WalletType.cash,
      shared: false,
      private: true,
    );
    await local.addOperation(
      type: OperationType.expense,
      amount: 15000,
      date: clock,
      categoryId: 'cat-alimentation-marche',
      sourceWalletId: cash,
    );
    await local.addOperation(
      type: OperationType.expense,
      amount: 3000,
      date: clock,
      categoryId: 'cat-loisirs',
      sourceWalletId: purse.id,
      personal: true,
      visibleToPartner: false,
    );
    final service = HouseholdService(firestoreOverride: db);
    final householdId = await service.createHousehold(
      data: local.data,
      memberId: 'uid-eudokia',
      memberName: 'Eudokia',
      oldMemberId: local.settings.memberId,
    );
    final foyer = await db.collection('foyers').doc(householdId).get();
    expect(foyer.data()!['membres'], ['uid-eudokia']);
    // Données communes et privées rangées à part, auteur remplacé.
    final shared = await db.collection('foyers/$householdId/operations').get();
    expect(shared.docs.single.data()['montant'], 15000);
    expect(shared.docs.single.data()['auteur'], 'uid-eudokia');
    final private = await db
        .collection('foyers/$householdId/prive/uid-eudokia/operations')
        .get();
    expect(private.docs.single.data()['montant'], 3000);
    final privateWallets = await db
        .collection('foyers/$householdId/prive/uid-eudokia/portefeuilles')
        .get();
    expect(privateWallets.docs.single.data()['proprietaire'], 'uid-eudokia');
    expect(
      (await db.collection('foyers/$householdId/categories').get()).docs,
      hasLength(local.data.categories.length),
    );

    final code = await service.createInvitation(
      householdId: householdId,
      memberId: 'uid-eudokia',
      now: clock,
    );
    expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{8}$')));
    await expectLater(
      service.joinHousehold(code: 'ABC', memberId: 'x', memberName: 'x'),
      throwsA(isA<HouseholdException>()),
    );
    final joined = await service.joinHousehold(
      code: code.toLowerCase(),
      memberId: 'uid-awa',
      memberName: 'Awa',
      now: clock,
    );
    expect(joined, householdId);
    final after = (await db.collection('foyers').doc(householdId).get())
        .data()!;
    expect(after['membres'], ['uid-eudokia', 'uid-awa']);
    expect(after['noms'], {'uid-eudokia': 'Eudokia', 'uid-awa': 'Awa'});
    // Code à usage unique.
    expect(
      (await db.collection('invitations').doc(code).get()).exists,
      isFalse,
    );
  });

  test('code expiré refusé', () async {
    final service = HouseholdService(firestoreOverride: db);
    final code = await service.createInvitation(
      householdId: 'f1',
      memberId: 'a',
      now: DateTime(2026, 1, 1),
    );
    await expectLater(
      service.joinHousehold(
        code: code,
        memberId: 'b',
        memberName: 'B',
        now: clock,
      ),
      throwsA(
        isA<HouseholdException>().having(
          (e) => e.message,
          'message',
          contains('expiré'),
        ),
      ),
    );
  });

  test(
    "deux téléphones : ce que l'un saisit apparaît chez l'autre, sauf le privé",
    () async {
      final local = await localPhone();
      final service = HouseholdService(firestoreOverride: db);
      final householdId = await service.createHousehold(
        data: local.data,
        memberId: 'uid-eudokia',
        memberName: 'Eudokia',
        oldMemberId: local.settings.memberId,
      );
      await service.joinHousehold(
        code: await service.createInvitation(
          householdId: householdId,
          memberId: 'uid-eudokia',
          now: clock,
        ),
        memberId: 'uid-awa',
        memberName: 'Awa',
        now: clock,
      );

      final eudokia = await sharedPhone(householdId, 'uid-eudokia', 'Eudokia');
      final awa = await sharedPhone(householdId, 'uid-awa', 'Awa');
      expect(awa.wallets.map((w) => w.name), [
        'Espèces',
        'Banque',
        'Mobile Money',
      ]);
      expect(awa.walletBalance(bank), 500000);
      expect(awa.memberName('uid-eudokia'), 'Eudokia');
      expect(eudokia.memberName('uid-eudokia'), isNull); // moi

      var notified = 0;
      awa.addListener(() => notified++);
      final op = await eudokia.addOperation(
        type: OperationType.expense,
        amount: 18500,
        date: clock,
        categoryId: 'cat-logement-electricite',
        sourceWalletId: bank,
      );
      await settle();
      expect(awa.operations.single.id, op.id);
      expect(awa.operations.single.authorId, 'uid-eudokia');
      expect(awa.walletBalance(bank), 481500);
      expect(notified, greaterThan(0));

      // Argent personnel privé d'Eudokia : invisible chez Awa.
      final purse = await eudokia.addWallet(
        name: 'Porte-monnaie',
        type: WalletType.cash,
        shared: false,
        private: true,
      );
      // Versement (visible) puis dépense perso privée.
      await eudokia.addOperation(
        type: OperationType.expense,
        amount: 30000,
        date: clock,
        categoryId: 'cat-argent-personnel',
        sourceWalletId: bank,
        targetWalletId: purse.id,
      );
      await eudokia.addOperation(
        type: OperationType.expense,
        amount: 8000,
        date: clock,
        categoryId: 'cat-loisirs-sorties',
        sourceWalletId: purse.id,
        personal: true,
        visibleToPartner: false,
      );
      await eudokia.addOperation(
        type: OperationType.expense,
        amount: 4000,
        date: clock,
        categoryId: 'cat-famille',
        sourceWalletId: purse.id,
        personal: true,
      );
      await settle();
      expect(eudokia.personalBalance, 18000);
      expect(awa.wallets.map((w) => w.name), isNot(contains('Porte-monnaie')));
      final seenByAwa = awa.operations.map((o) => o.amount).toList();
      expect(seenByAwa, containsAll([18500, 30000, 4000]));
      expect(seenByAwa, isNot(contains(8000)));
      // Les chiffres du foyer sont les mêmes des deux côtés.
      expect(
        awa.monthSummary(clock).expense,
        eudokia.monthSummary(clock).expense,
      );
      expect(awa.walletBalance(bank), 451500);

      // Rendre visible une dépense privée la fait apparaître chez Awa.
      final hidden = eudokia.operations.firstWhere((o) => o.amount == 8000);
      await eudokia.updateOperation(hidden.copyWith(visibleToPartner: true));
      await settle();
      expect(awa.operations.map((o) => o.amount), contains(8000));
      expect(
        (await db
                .collection('foyers/$householdId/prive/uid-eudokia/operations')
                .get())
            .docs,
        isEmpty,
      );

      // Suppression douce chez Awa, vue chez Eudokia.
      await awa.deleteOperation(op.id);
      await settle();
      expect(eudokia.operation(op.id)!.deleted, isTrue);
      expect(eudokia.walletBalance(bank), 451500 + 18500);

      await eudokia.repository.close();
      await awa.repository.close();
    },
  );

  test(
    'récurrence automatique : même identifiant sur les deux téléphones',
    () async {
      final local = await localPhone();
      final service = HouseholdService(firestoreOverride: db);
      final householdId = await service.createHousehold(
        data: local.data,
        memberId: 'uid-eudokia',
        memberName: 'Eudokia',
        oldMemberId: local.settings.memberId,
      );
      final eudokia = await sharedPhone(householdId, 'uid-eudokia', 'Eudokia');
      await eudokia.addRecurrence(
        type: OperationType.expense,
        amount: 150000,
        categoryId: 'cat-logement-loyer',
        sourceWalletId: bank,
        dayOfMonth: 5,
        startMonth: DateTime(2026, 11),
        automatic: true,
      );
      final awa = await sharedPhone(householdId, 'uid-awa', 'Awa');
      await awa.processAutomaticRecurrences();
      await settle();
      expect(
        (await db.collection('foyers/$householdId/operations').get()).docs,
        hasLength(1),
      );
      expect(awa.operations, hasLength(1));
      expect(eudokia.operations, hasLength(1));
      await eudokia.repository.close();
      await awa.repository.close();
    },
  );

  test('isPrivateOperation', () {
    Operation op({
      String? from,
      String? to,
      bool personal = false,
      bool visible = true,
    }) => Operation(
      id: 'o',
      type: OperationType.expense,
      amount: 1,
      date: clock,
      sourceWalletId: from,
      targetWalletId: to,
      personal: personal,
      visibleToPartner: visible,
      authorId: 'a',
      createdAt: clock,
      updatedAt: clock,
    );
    bool priv(String id) => id.startsWith('p');
    expect(
      isPrivateOperation(op(from: 'p1', personal: true, visible: false), priv),
      isTrue,
    );
    expect(isPrivateOperation(op(from: 'p1', personal: true), priv), isFalse);
    expect(isPrivateOperation(op(from: 'p1', to: 'p2'), priv), isTrue);
    expect(isPrivateOperation(op(from: 'c1', to: 'p1'), priv), isFalse);
    expect(isPrivateOperation(op(from: 'c1'), priv), isFalse);
    expect(isPrivateOperation(op(), priv), isFalse);
  });

  // Timestamp importé pour les données d'invitation.
  test('Timestamp', () => expect(Timestamp.fromDate(clock).toDate(), clock));
}
