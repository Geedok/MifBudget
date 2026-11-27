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
      expect(seenByAwa, containsAll([18500, 30000]));
      expect(seenByAwa, isNot(contains(8000)));
      expect(seenByAwa, isNot(contains(4000)));
      // Les chiffres du foyer sont les mêmes des deux côtés.
      expect(
        awa.monthSummary(clock).expense,
        eudokia.monthSummary(clock).expense,
      );
      expect(awa.walletBalance(bank), 451500);

      // Une facture du foyer payée avec le porte-monnaie : visible chez Awa
      // et comptée des deux côtés.
      await eudokia.addOperation(
        type: OperationType.expense,
        amount: 5000,
        date: clock,
        categoryId: 'cat-logement',
        sourceWalletId: purse.id,
      );
      // Un cadeau reçu sur le porte-monnaie : à Eudokia seul.
      await eudokia.addOperation(
        type: OperationType.income,
        amount: 2000,
        date: clock,
        categoryId: 'cat-autres-revenus',
        targetWalletId: purse.id,
        personal: true,
      );
      await settle();
      expect(awa.operations.map((o) => o.amount), contains(5000));
      expect(awa.operations.map((o) => o.amount), isNot(contains(2000)));
      expect(
        awa.monthSummary(clock).expense,
        eudokia.monthSummary(clock).expense,
      );
      expect(
        awa.monthSummary(clock).income,
        eudokia.monthSummary(clock).income,
      );
      expect(eudokia.personalReceived(clock), 32000);

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

  test('isPrivateOperation : seul l\'argent personnel est privé', () {
    Operation op({
      OperationType type = OperationType.expense,
      String? from,
      String? to,
      bool personal = false,
    }) => Operation(
      id: 'o',
      type: type,
      amount: 1,
      date: clock,
      sourceWalletId: from,
      targetWalletId: to,
      personal: personal,
      authorId: 'a',
      createdAt: clock,
      updatedAt: clock,
    );
    bool priv(String id) => id.startsWith('p');
    const transfer = OperationType.transfer;
    const income = OperationType.income;
    // Dépense pour moi, revenu reçu sur mon argent personnel.
    expect(isPrivateOperation(op(from: 'p1', personal: true), priv), isTrue);
    expect(
      isPrivateOperation(op(type: income, to: 'p1', personal: true), priv),
      isTrue,
    );
    // Dépense du foyer payée avec un portefeuille personnel.
    expect(isPrivateOperation(op(from: 'p1'), priv), isFalse);
    // Entre mes portefeuilles personnels.
    expect(
      isPrivateOperation(op(type: transfer, from: 'p1', to: 'p2'), priv),
      isTrue,
    );
    // Du foyer vers mon argent personnel (versement, dépôt) : visible.
    expect(isPrivateOperation(op(from: 'c1', to: 'p1'), priv), isFalse);
    expect(
      isPrivateOperation(op(type: transfer, from: 'c1', to: 'p1'), priv),
      isFalse,
    );
    expect(isPrivateOperation(op(from: 'c1'), priv), isFalse);
    expect(isPrivateOperation(op(), priv), isFalse);
  });

  test('reprise 1.0.3 : l\'argent personnel devient privé, l\'épargne perso '
      'passe au foyer', () async {
    final local = await localPhone();
    final service = HouseholdService(firestoreOverride: db);
    final householdId = await service.createHousehold(
      data: local.data,
      memberId: 'uid-eudokia',
      memberName: 'Eudokia',
      oldMemberId: local.settings.memberId,
    );
    // Données écrites par la version 1.0.2 : un Mobile Money perso
    // visible, une dépense perso visible, une épargne perso, un revenu
    // reçu sur le Mobile Money perso.
    final foyer = db.collection('foyers').doc(householdId);
    Map<String, dynamic> wallet(String id, String role) => {
      'id': id,
      'nom': id,
      'type': 'mobile_money',
      'role': role,
      'soldeDepart': 0,
      'commun': false,
      'proprietaire': 'uid-eudokia',
      'prive': false,
      'archive': false,
      'ordre': 9,
      'modifieLe': clock.toIso8601String(),
    };
    Map<String, dynamic> operation(
      String id,
      String type,
      Map<String, dynamic> extra,
    ) => {
      'id': id,
      'type': type,
      'montant': 1000,
      'date': clock.toIso8601String(),
      'note': '',
      'auteur': 'uid-eudokia',
      'creeLe': clock.toIso8601String(),
      'modifieLe': clock.toIso8601String(),
      ...extra,
    };
    await foyer
        .collection('portefeuilles')
        .doc('momo')
        .set(wallet('momo', 'courant'));
    await foyer
        .collection('portefeuilles')
        .doc('tirelire')
        .set(wallet('tirelire', 'epargne'));
    await foyer
        .collection('operations')
        .doc('d1')
        .set(
          operation('d1', 'depense', {
            'portefeuilleSource': 'momo',
            'personnelle': true,
            'visibleParAutre': true,
          }),
        );
    await foyer
        .collection('operations')
        .doc('r1')
        .set(operation('r1', 'revenu', {'portefeuilleCible': 'momo'}));

    final eudokia = await sharedPhone(householdId, 'uid-eudokia', 'Eudokia');
    await settle();
    Future<Set<String>> ids(String path) async =>
        (await db.collection(path).get()).docs.map((d) => d.id).toSet();
    final shared = 'foyers/$householdId';
    final mine = '$shared/prive/uid-eudokia';
    expect(await ids('$mine/portefeuilles'), {'momo'});
    expect(await ids('$shared/portefeuilles'), contains('tirelire'));
    expect(await ids('$shared/portefeuilles'), isNot(contains('momo')));
    expect(await ids('$mine/operations'), containsAll(['d1', 'r1']));
    expect(await ids('$shared/operations'), isNot(contains('d1')));
    expect(eudokia.operation('r1')!.personal, isTrue);
    expect(eudokia.monthSummary(clock).income, 0);
    final tirelire = eudokia.wallet('tirelire')!;
    expect(tirelire.shared, isTrue);
    expect(tirelire.ownerId, isNull);
    // Rouvrir ne change plus rien.
    await eudokia.repository.close();
    final again = await sharedPhone(householdId, 'uid-eudokia', 'Eudokia');
    await settle();
    expect(await ids('$mine/operations'), containsAll(['d1', 'r1']));
    await again.repository.close();
  });

  // Timestamp importé pour les données d'invitation.
  test('Timestamp', () => expect(Timestamp.fromDate(clock).toDate(), clock));
}
