import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/repository.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/project.dart';
import '../models/recurrence.dart';
import '../models/savings_goal.dart';
import '../models/settings.dart';
import '../models/wallet.dart';

/// Noms des collections d'un foyer dans Firestore.
class Paths {
  static const households = 'foyers';
  static const invitations = 'invitations';
  static const wallets = 'portefeuilles';
  static const categories = 'categories';
  static const operations = 'operations';
  static const goals = 'objectifsEpargne';
  static const projects = 'projets';
  static const budgets = 'budgets';
  static const recurrences = 'recurrences';

  /// Données privées d'un membre : foyers/{id}/prive/{membre}/…
  static const private = 'prive';
}

/// Une opération est privée si c'est une dépense perso non rendue visible,
/// ou (hors dépense perso) si elle ne touche que des portefeuilles privés (ex. du porte-monnaie
/// vers le Mobile Money perso). Le versement d'argent personnel (d'un
/// portefeuille commun vers un portefeuille privé) reste visible du foyer.
bool isPrivateOperation(Operation op, bool Function(String id) privateWallet) {
  // Une dépense perso suit le choix fait à la saisie (privée ou visible).
  if (op.personal) return !op.visibleToPartner;
  final ids = [op.sourceWalletId, op.targetWalletId].whereType<String>();
  return ids.isNotEmpty && ids.every(privateWallet);
}

/// Données du foyer partagées par Cloud Firestore (avec son cache hors
/// ligne) ; les réglages restent sur le téléphone ([local]).
///
/// Les écritures ne sont jamais attendues : Firestore les applique tout de
/// suite à son cache et les envoie quand le réseau revient. Les écouteurs
/// reflètent les changements de l'autre téléphone dans [data].
class FirestoreRepository extends BudgetRepository {
  FirestoreRepository({
    required this.firestore,
    required this.householdId,
    required this.memberId,
    required this.local,
  });

  final FirebaseFirestore firestore;
  final String householdId;
  final String memberId;

  /// Stockage local, pour les réglages de ce téléphone.
  final BudgetRepository local;

  final BudgetData data = BudgetData();
  final _subscriptions = <StreamSubscription<Object?>>[];
  void Function()? _onChange;

  // Documents reçus, par emplacement (commun ou privé), pour fusionner.
  final _sharedWallets = <String, Wallet>{};
  final _privateWallets = <String, Wallet>{};
  final _sharedOps = <String, Operation>{};
  final _privateOps = <String, Operation>{};
  final _categories = <String, Category>{};
  final _goals = <String, SavingsGoal>{};
  final _projects = <String, Project>{};
  final _budgets = <String, Budget>{};
  final _recurrences = <String, Recurrence>{};

  DocumentReference<Map<String, dynamic>> get _household =>
      firestore.collection(Paths.households).doc(householdId);

  CollectionReference<Map<String, dynamic>> _shared(String name) =>
      _household.collection(name);

  CollectionReference<Map<String, dynamic>> _private(String name) =>
      _household.collection(Paths.private).doc(memberId).collection(name);

  bool _isPrivateWallet(String id) =>
      _privateWallets.containsKey(id) ||
      data.wallets.any((w) => w.id == id && w.isPrivate);

  @override
  void onRemoteChange(void Function() callback) => _onChange = callback;

  @override
  Future<BudgetData> load() async {
    final localData = await local.load();
    data.settings = localData.settings;
    final firstSnapshots = <Future<void>>[];

    void listen<T>(
      Query<Map<String, dynamic>> query,
      Map<String, T> into,
      T Function(Map<String, dynamic>) parse,
    ) {
      final first = Completer<void>();
      firstSnapshots.add(first.future);
      _subscriptions.add(
        query.snapshots().listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              final doc = change.doc;
              if (change.type == DocumentChangeType.removed) {
                into.remove(doc.id);
              } else {
                final json = doc.data();
                if (json == null) continue;
                try {
                  into[doc.id] = parse({...json, 'id': doc.id});
                } catch (_) {
                  // Document illisible (version plus récente ?) : ignoré.
                }
              }
            }
            _rebuild();
            if (!first.isCompleted) {
              first.complete();
            } else {
              _onChange?.call();
            }
          },
          onError: (Object _) {
            if (!first.isCompleted) first.complete();
          },
        ),
      );
    }

    listen(_shared(Paths.wallets), _sharedWallets, Wallet.fromJson);
    listen(_private(Paths.wallets), _privateWallets, Wallet.fromJson);
    listen(_shared(Paths.operations), _sharedOps, Operation.fromJson);
    listen(_private(Paths.operations), _privateOps, Operation.fromJson);
    listen(_shared(Paths.categories), _categories, Category.fromJson);
    listen(_shared(Paths.goals), _goals, SavingsGoal.fromJson);
    listen(_shared(Paths.projects), _projects, Project.fromJson);
    listen(_shared(Paths.budgets), _budgets, Budget.fromJson);
    listen(_shared(Paths.recurrences), _recurrences, Recurrence.fromJson);

    // Prénoms des membres.
    final foyerFirst = Completer<void>();
    firstSnapshots.add(foyerFirst.future);
    _subscriptions.add(
      _household.snapshots().listen(
        (doc) {
          final names = (doc.data()?['noms'] as Map?)?.cast<String, Object?>();
          data.memberNames
            ..clear()
            ..addAll({
              for (final MapEntry(:key, :value) in (names ?? {}).entries)
                if (value is String) key: value,
            });
          if (!foyerFirst.isCompleted) {
            foyerFirst.complete();
          } else {
            _onChange?.call();
          }
        },
        onError: (Object _) {
          if (!foyerFirst.isCompleted) foyerFirst.complete();
        },
      ),
    );

    // Le cache répond vite, même hors ligne ; sans cache ni réseau, on
    // n'attend pas indéfiniment.
    await Future.wait(firstSnapshots)
        .timeout(const Duration(seconds: 15), onTimeout: () => const []);
    return data;
  }

  /// Recompose les listes de [data] (le privé l'emporte sur le commun pour
  /// un même identifiant).
  void _rebuild() {
    void fill<T>(List<T> list, Iterable<T> values) => list
      ..clear()
      ..addAll(values);
    fill(data.wallets, {..._sharedWallets, ..._privateWallets}.values);
    fill(data.operations, {..._sharedOps, ..._privateOps}.values);
    fill(data.categories, _categories.values);
    fill(data.goals, _goals.values);
    fill(data.projects, _projects.values);
    fill(data.budgets, _budgets.values);
    fill(data.recurrences, _recurrences.values);
  }

  /// Écriture locale immédiate, envoi au serveur dès que possible.
  void _set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> json,
  ) {
    unawaited(ref.set(json).catchError((Object _) {}));
  }

  void _delete(DocumentReference<Map<String, dynamic>> ref) {
    unawaited(ref.delete().catchError((Object _) {}));
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    data.settings = settings;
    await local.saveSettings(settings);
  }

  @override
  Future<void> upsertWallets(List<Wallet> wallets) async {
    final changedPrivacy = <String>{};
    for (final w in wallets) {
      final wasPrivate = _privateWallets.containsKey(w.id);
      if (w.isPrivate) {
        _privateWallets[w.id] = w;
        _sharedWallets.remove(w.id);
        _set(_private(Paths.wallets).doc(w.id), w.toJson());
        _delete(_shared(Paths.wallets).doc(w.id));
      } else {
        _sharedWallets[w.id] = w;
        _privateWallets.remove(w.id);
        _set(_shared(Paths.wallets).doc(w.id), w.toJson());
        if (wasPrivate) _delete(_private(Paths.wallets).doc(w.id));
      }
      if (wasPrivate != w.isPrivate) changedPrivacy.add(w.id);
    }
    _rebuild();
    // Un portefeuille qui devient privé (ou public) emporte ses opérations.
    if (changedPrivacy.isNotEmpty) {
      for (final op in data.operations.toList()) {
        if (changedPrivacy.contains(op.sourceWalletId) ||
            changedPrivacy.contains(op.targetWalletId)) {
          await upsertOperation(op);
        }
      }
    }
  }

  @override
  Future<void> upsertCategories(List<Category> categories) async {
    for (final c in categories) {
      _categories[c.id] = c;
      _set(_shared(Paths.categories).doc(c.id), c.toJson());
    }
    _rebuild();
  }

  @override
  Future<void> upsertOperation(Operation operation) async {
    final id = operation.id;
    if (isPrivateOperation(operation, _isPrivateWallet)) {
      _privateOps[id] = operation;
      final wasShared = _sharedOps.remove(id) != null;
      _set(_private(Paths.operations).doc(id), operation.toJson());
      if (wasShared) _delete(_shared(Paths.operations).doc(id));
    } else {
      _sharedOps[id] = operation;
      final wasPrivate = _privateOps.remove(id) != null;
      _set(_shared(Paths.operations).doc(id), operation.toJson());
      if (wasPrivate) _delete(_private(Paths.operations).doc(id));
    }
    _rebuild();
  }

  @override
  Future<void> removeOperation(String id) async {
    _sharedOps.remove(id);
    _privateOps.remove(id);
    _delete(_shared(Paths.operations).doc(id));
    _delete(_private(Paths.operations).doc(id));
    _rebuild();
  }

  @override
  Future<void> upsertGoal(SavingsGoal goal) async {
    _goals[goal.id] = goal;
    _set(_shared(Paths.goals).doc(goal.id), goal.toJson());
    _rebuild();
  }

  @override
  Future<void> upsertProject(Project project) async {
    _projects[project.id] = project;
    _set(_shared(Paths.projects).doc(project.id), project.toJson());
    _rebuild();
  }

  @override
  Future<void> upsertBudgets(List<Budget> budgets) async {
    for (final b in budgets) {
      _budgets[b.id] = b;
      _set(_shared(Paths.budgets).doc(b.id), b.toJson());
    }
    _rebuild();
  }

  @override
  Future<void> upsertRecurrence(Recurrence recurrence) async {
    _recurrences[recurrence.id] = recurrence;
    _set(_shared(Paths.recurrences).doc(recurrence.id), recurrence.toJson());
    _rebuild();
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _onChange = null;
  }
}
