import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../data/repository.dart';
import '../models/settings.dart';
import '../state/budget_store.dart';
import 'firestore_repository.dart';
import 'household_service.dart';

/// Tient le [BudgetStore] de l'application et le fait passer du stockage
/// local au foyer partagé (Firestore) au moment de la connexion.
class AppController extends ChangeNotifier {
  AppController._(
    this.file,
    this.store,
    this.service, {
    this.needsSignIn = false,
  });

  /// Fichier local (réglages, et données tant qu'il n'y a pas de foyer).
  final File file;
  final HouseholdService service;
  BudgetStore store;

  /// Le téléphone appartient à un foyer mais le compte n'est plus connecté.
  bool needsSignIn;

  /// Ouvre le stockage adapté : le foyer partagé si ce téléphone en a un et
  /// que le compte est connecté, sinon les données locales.
  static Future<AppController> open(File file, HouseholdService service) async {
    final local = LocalJsonRepository(file);
    final localData = await local.load();
    final householdId = localData.settings.householdId;
    final user = service.currentUser;
    if (householdId != null && user != null) {
      final store = await BudgetStore.open(
        _firestoreRepo(service, file, householdId, user.uid),
      );
      return AppController._(file, store, service);
    }
    final store = await BudgetStore.open(LocalJsonRepository(file));
    return AppController._(
      file,
      store,
      service,
      needsSignIn: householdId != null,
    );
  }

  static FirestoreRepository _firestoreRepo(
    HouseholdService service,
    File file,
    String householdId,
    String memberId,
  ) => FirestoreRepository(
    firestore: service.firestore,
    householdId: householdId,
    memberId: memberId,
    local: LocalJsonRepository(file),
  );

  bool get shared => store.settings.householdId != null && !needsSignIn;

  /// Connexion Google puis création du foyer avec les données actuelles.
  Future<void> createHousehold() async {
    final user = await service.signInWithGoogle();
    final settings = store.settings;
    final name = settings.memberName.isNotEmpty
        ? settings.memberName
        : (user.displayName ?? '').split(' ').first;
    final householdId = await service.createHousehold(
      data: store.data,
      memberId: user.uid,
      memberName: name,
      oldMemberId: settings.memberId,
    );
    await _switchTo(
      householdId,
      user.uid,
      settings.copyWith(
        setupDone: true,
        memberId: user.uid,
        memberName: name,
        householdId: () => householdId,
        email: () => user.email,
      ),
    );
  }

  /// Connexion Google puis entrée dans le foyer de l'invitation [code]. Les
  /// données de ce téléphone sont gardées dans une copie de sauvegarde.
  Future<void> joinHousehold(String code) async {
    final user = await service.signInWithGoogle();
    final settings = store.settings;
    final name = settings.memberName.isNotEmpty
        ? settings.memberName
        : (user.displayName ?? '').split(' ').first;
    final householdId = await service.joinHousehold(
      code: code,
      memberId: user.uid,
      memberName: name,
    );
    await _switchTo(
      householdId,
      user.uid,
      settings.copyWith(
        setupDone: true,
        memberId: user.uid,
        memberName: name,
        householdId: () => householdId,
        email: () => user.email,
        // L'argent personnel d'avant ne concerne que l'ancien stockage.
        personalMoney: false,
        allowanceRecurrenceId: () => null,
      ),
    );
  }

  /// Reconnexion d'un téléphone qui appartient déjà à un foyer.
  Future<void> signInAgain() async {
    final user = await service.signInWithGoogle();
    final householdId = store.settings.householdId!;
    await _switchTo(
      householdId,
      user.uid,
      store.settings.copyWith(memberId: user.uid, email: () => user.email),
    );
  }

  Future<String> invite() => service.createInvitation(
    householdId: store.settings.householdId!,
    memberId: store.settings.memberId,
  );

  Future<void> _switchTo(
    String householdId,
    String memberId,
    AppSettings settings,
  ) async {
    // Copie de sauvegarde des données locales d'avant le foyer.
    if (await file.exists() && !needsSignIn) {
      final backup = File('${file.parent.path}/mifbudget-avant-foyer.json');
      if (!await backup.exists()) await file.copy(backup.path);
    }
    // Le fichier local ne garde plus que les réglages.
    final local = LocalJsonRepository(file);
    await local.saveSettings(settings);
    await store.repository.close();
    store = await BudgetStore.open(
      FirestoreRepository(
        firestore: service.firestore,
        householdId: householdId,
        memberId: memberId,
        local: LocalJsonRepository(file),
      ),
    );
    needsSignIn = false;
    notifyListeners();
  }

  /// Pour les tests : un contrôleur autour d'un store déjà ouvert.
  @visibleForTesting
  factory AppController.forStore(
    BudgetStore store, {
    required File file,
    required HouseholdService service,
  }) => AppController._(file, store, service);

  /// Firestore utilisé (pour les tests).
  FirebaseFirestore get firestore => service.firestore;
}

/// Donne accès au contrôleur (absent dans les tests sans synchronisation).
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
}
