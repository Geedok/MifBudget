import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mifbudget/app.dart';
import 'package:mifbudget/core/format.dart';
import 'package:mifbudget/data/defaults.dart';
import 'package:mifbudget/data/repository.dart';
import 'package:mifbudget/models/operation.dart';
import 'package:mifbudget/state/budget_store.dart';
import 'package:mifbudget/sync/app_controller.dart';
import 'package:mifbudget/sync/firestore_repository.dart';
import 'package:mifbudget/sync/household_service.dart';

/// Service dont la connexion Google est simulée (pas de fenêtre Google en
/// test) : le compte est déjà « connecté ».
class FakeHouseholdService extends HouseholdService {
  FakeHouseholdService({
    required super.authOverride,
    required super.firestoreOverride,
  });

  @override
  Future<User> signInWithGoogle() async => auth.currentUser!;
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await initializeDateFormatting('fr_FR');
  });

  late Directory dir;
  setUp(
    () async => dir = await Directory.systemTemp.createTemp('mifbudget-flow'),
  );
  tearDown(() => dir.delete(recursive: true));

  FakeHouseholdService service(
    FakeFirebaseFirestore db,
    String uid,
    String name,
  ) => FakeHouseholdService(
    authOverride: MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: uid,
        email: '$uid@exemple.com',
        displayName: '$name Test',
      ),
    ),
    firestoreOverride: db,
  );

  test('créer le foyer sur un téléphone, le rejoindre sur l\'autre', () async {
    final db = FakeFirebaseFirestore();
    // Téléphone d'Eudokia : données locales existantes.
    final fileE = File('${dir.path}/eudokia.json');
    final local = await BudgetStore.open(LocalJsonRepository(fileE));
    await local.completeSetup(memberName: 'Eudokia', bank: 500000);
    await local.addOperation(
      type: OperationType.expense,
      amount: 15000,
      date: DateTime.now(),
      categoryId: 'cat-alimentation',
      sourceWalletId: DefaultIds.walletBank,
    );
    await local.repository.close();

    final eudokia = await AppController.open(
      fileE,
      service(db, 'uid-e', 'Eudokia'),
    );
    expect(eudokia.shared, isFalse);
    await eudokia.createHousehold();
    expect(eudokia.shared, isTrue);
    expect(eudokia.store.repository, isA<FirestoreRepository>());
    expect(eudokia.store.settings.memberId, 'uid-e');
    expect(eudokia.store.settings.email, 'uid-e@exemple.com');
    expect(eudokia.store.operations.single.amount, 15000);
    expect(eudokia.store.operations.single.authorId, 'uid-e');
    // Copie de sauvegarde et fichier local réduit aux réglages.
    expect(File('${dir.path}/mifbudget-avant-foyer.json').existsSync(), isTrue);
    final reopenedLocal = await LocalJsonRepository(fileE).load();
    expect(reopenedLocal.operations, isEmpty);
    expect(reopenedLocal.settings.householdId, isNotNull);

    final code = await eudokia.invite();

    // Téléphone d'Awa : première ouverture, rejoint avec le code.
    final fileA = File('${dir.path}/awa.json');
    final awa = await AppController.open(fileA, service(db, 'uid-a', 'Awa'));
    expect(awa.store.settings.setupDone, isFalse);
    await awa.joinHousehold(code);
    expect(awa.store.settings.setupDone, isTrue);
    expect(awa.store.settings.memberName, 'Awa');
    expect(awa.store.walletBalance(DefaultIds.walletBank), 485000);
    expect(awa.store.memberName('uid-e'), 'Eudokia');

    // Awa saisit, Eudokia voit.
    await awa.store.addOperation(
      type: OperationType.expense,
      amount: 2000,
      date: DateTime.now(),
      categoryId: 'cat-transport',
      sourceWalletId: DefaultIds.walletBank,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(eudokia.store.walletBalance(DefaultIds.walletBank), 483000);
    expect(
      eudokia.store.memberName(eudokia.store.operations.first.authorId),
      'Awa',
    );

    // Réouverture d'Eudokia : directement sur le foyer.
    await eudokia.store.repository.close();
    final again = await AppController.open(
      fileE,
      service(db, 'uid-e', 'Eudokia'),
    );
    expect(again.shared, isTrue);
    expect(again.store.operations, hasLength(2));
    await again.store.repository.close();
    await awa.store.repository.close();
  });

  test('foyer sans compte connecté : reconnexion demandée', () async {
    final db = FakeFirebaseFirestore();
    final file = File('${dir.path}/e.json');
    final c = await AppController.open(file, service(db, 'uid-e', 'Eudokia'));
    await c.store.completeSetup(memberName: 'Eudokia');
    await c.createHousehold();
    await c.store.repository.close();
    final signedOut = FakeHouseholdService(
      authOverride: MockFirebaseAuth(),
      firestoreOverride: db,
    );
    final reopened = await AppController.open(file, signedOut);
    expect(reopened.needsSignIn, isTrue);
    expect(reopened.shared, isFalse);
  });

  testWidgets('code de verrouillage demandé à la réouverture', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final store = await BudgetStore.open(MemoryRepository());
    await store.completeSetup(memberName: 'Eudokia');
    await tester.pumpWidget(MifBudgetApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Code de verrouillage'));
    await tester.pumpAndSettle();
    for (final d in ['1', '9', '8', '4', '1', '9', '8', '4']) {
      await tester.tap(find.byKey(Key('pin-$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(store.settings.locked, isTrue);
    expect(store.settings.pinHash, isNot(contains('1984')));

    // Nouvelle ouverture de l'application.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MifBudgetApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez votre code'), findsOneWidget);
    for (final d in ['0', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('pin-$d')));
    }
    await tester.pump();
    expect(find.text('Code incorrect, réessayez'), findsOneWidget);
    for (final d in ['1', '9', '8', '4']) {
      await tester.tap(find.byKey(Key('pin-$d')));
    }
    await tester.pumpAndSettle();
    expect(find.text('Saisissez votre code'), findsNothing);
    expect(
      find.text('Bonjour Eudokia').evaluate().isNotEmpty ||
          find.text('Bonsoir Eudokia').evaluate().isNotEmpty,
      isTrue,
    );
    expect(nbsp, isNotEmpty);
  });
}
