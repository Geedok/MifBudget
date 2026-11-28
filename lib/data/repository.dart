import 'dart:convert';
import 'dart:io';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/project.dart';
import '../models/recurrence.dart';
import '../models/savings_goal.dart';
import '../models/settings.dart';
import '../models/wallet.dart';

/// Toutes les données du foyer, telles que lues au démarrage.
class BudgetData {
  BudgetData({
    this.version = schemaVersion,
    this.settings = const AppSettings(),
    List<Wallet>? wallets,
    List<Category>? categories,
    List<Operation>? operations,
    List<SavingsGoal>? goals,
    List<Project>? projects,
    List<Budget>? budgets,
    List<Recurrence>? recurrences,
  }) : wallets = wallets ?? [],
       categories = categories ?? [],
       operations = operations ?? [],
       goals = goals ?? [],
       projects = projects ?? [],
       budgets = budgets ?? [],
       recurrences = recurrences ?? [];

  /// Version du format lue dans le fichier (pour les reprises de données).
  int version;

  /// Prénoms des membres du foyer, par identifiant (synchronisation ;
  /// non enregistré localement).
  final Map<String, String> memberNames = {};
  AppSettings settings;
  final List<Wallet> wallets;
  final List<Category> categories;
  final List<Operation> operations;
  final List<SavingsGoal> goals;
  final List<Project> projects;
  final List<Budget> budgets;
  final List<Recurrence> recurrences;

  /// 2 : comptes épargne (rôle des portefeuilles), l'épargne devient un
  /// virement vers un compte épargne.
  static const schemaVersion = 2;

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'reglages': settings.toJson(),
    'portefeuilles': wallets.map((w) => w.toJson()).toList(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'operations': operations.map((o) => o.toJson()).toList(),
    'objectifsEpargne': goals.map((g) => g.toJson()).toList(),
    'projets': projects.map((p) => p.toJson()).toList(),
    'budgets': budgets.map((b) => b.toJson()).toList(),
    'recurrences': recurrences.map((r) => r.toJson()).toList(),
  };

  factory BudgetData.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) =>
        ((j[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return BudgetData(
      version: (j['version'] as num?)?.toInt() ?? 1,
      settings: AppSettings.fromJson(
        (j['reglages'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      wallets: list('portefeuilles').map(Wallet.fromJson).toList(),
      categories: list('categories').map(Category.fromJson).toList(),
      operations: list('operations').map(Operation.fromJson).toList(),
      goals: list('objectifsEpargne').map(SavingsGoal.fromJson).toList(),
      projects: list('projets').map(Project.fromJson).toList(),
      budgets: list('budgets').map(Budget.fromJson).toList(),
      recurrences: list('recurrences').map(Recurrence.fromJson).toList(),
    );
  }
}

/// Accès aux données. Une écriture par élément, pour pouvoir brancher
/// Cloud Firestore (un document par élément) à la place du stockage local.
abstract class BudgetRepository {
  Future<BudgetData> load();

  /// Appelé quand les données changent ailleurs (l'autre téléphone). Le
  /// stockage local ne change jamais tout seul.
  void onRemoteChange(void Function() callback) {}

  /// Arrête l'écoute des changements (changement de stockage).
  Future<void> close() async {}
  Future<void> saveSettings(AppSettings settings);
  Future<void> upsertWallets(List<Wallet> wallets);
  Future<void> upsertCategories(List<Category> categories);
  Future<void> upsertOperation(Operation operation);
  Future<void> upsertGoal(SavingsGoal goal);
  Future<void> upsertProject(Project project);
  Future<void> upsertBudgets(List<Budget> budgets);
  Future<void> upsertRecurrence(Recurrence recurrence);

  /// Efface définitivement une opération (seulement pour annuler aussitôt
  /// une échéance confirmée ou ignorée ; sinon, suppression douce).
  Future<void> removeOperation(String id);

  /// Suppression définitive d'un portefeuille qui n'a jamais servi.
  Future<void> removeWallet(String id);

  /// Range chaque document là où il doit être (commun au foyer ou privé)
  /// après un changement des règles de confidentialité. Rien à faire pour
  /// un stockage sur le téléphone.
  Future<void> reconcilePrivacy() async {}
}

/// Stockage en mémoire, pour les tests.
class MemoryRepository extends BudgetRepository {
  MemoryRepository([BudgetData? initial]) : data = initial ?? BudgetData();

  final BudgetData data;

  /// Toute écriture enregistre les données au format actuel.
  void _touch() => data.version = BudgetData.schemaVersion;

  @override
  Future<BudgetData> load() async => BudgetData.fromJson(
    jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
  )..version = data.version;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _touch();
    data.settings = settings;
  }

  @override
  Future<void> upsertWallets(List<Wallet> wallets) async {
    _touch();
    for (final w in wallets) {
      _upsert(data.wallets, w, (x) => x.id == w.id);
    }
  }

  @override
  Future<void> upsertCategories(List<Category> categories) async {
    _touch();
    for (final c in categories) {
      _upsert(data.categories, c, (x) => x.id == c.id);
    }
  }

  @override
  Future<void> upsertOperation(Operation operation) async {
    _touch();
    _upsert(data.operations, operation, (x) => x.id == operation.id);
  }

  @override
  Future<void> upsertGoal(SavingsGoal goal) async {
    _touch();
    _upsert(data.goals, goal, (x) => x.id == goal.id);
  }

  @override
  Future<void> upsertProject(Project project) async {
    _touch();
    _upsert(data.projects, project, (x) => x.id == project.id);
  }

  @override
  Future<void> upsertBudgets(List<Budget> budgets) async {
    _touch();
    for (final b in budgets) {
      _upsert(data.budgets, b, (x) => x.id == b.id);
    }
  }

  @override
  Future<void> upsertRecurrence(Recurrence recurrence) async {
    _touch();
    _upsert(data.recurrences, recurrence, (x) => x.id == recurrence.id);
  }

  @override
  Future<void> removeOperation(String id) async {
    _touch();
    data.operations.removeWhere((o) => o.id == id);
  }

  @override
  Future<void> removeWallet(String id) async {
    _touch();
    data.wallets.removeWhere((w) => w.id == id);
  }
}

void _upsert<T>(List<T> list, T item, bool Function(T) same) {
  final i = list.indexWhere(same);
  if (i >= 0) {
    list[i] = item;
  } else {
    list.add(item);
  }
}

/// Stockage local dans un fichier JSON sur le téléphone. Chaque écriture
/// passe par un fichier temporaire puis un renommage, pour ne jamais laisser
/// un fichier à moitié écrit.
class LocalJsonRepository extends MemoryRepository {
  LocalJsonRepository(this.file);

  final File file;
  Future<void> _pending = Future.value();

  @override
  Future<BudgetData> load() async {
    if (await file.exists()) {
      final text = await file.readAsString();
      if (text.trim().isNotEmpty) {
        final loaded = BudgetData.fromJson(
          jsonDecode(text) as Map<String, dynamic>,
        );
        data.version = loaded.version;
        data.settings = loaded.settings;
        data.wallets
          ..clear()
          ..addAll(loaded.wallets);
        data.categories
          ..clear()
          ..addAll(loaded.categories);
        data.operations
          ..clear()
          ..addAll(loaded.operations);
        data.goals
          ..clear()
          ..addAll(loaded.goals);
        data.projects
          ..clear()
          ..addAll(loaded.projects);
        data.budgets
          ..clear()
          ..addAll(loaded.budgets);
        data.recurrences
          ..clear()
          ..addAll(loaded.recurrences);
      }
    }
    return super.load();
  }

  Future<void> _write() {
    // Les écritures sont mises en file pour garder l'ordre.
    _pending = _pending.then((_) async {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
      await tmp.rename(file.path);
    });
    return _pending;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await super.saveSettings(settings);
    await _write();
  }

  @override
  Future<void> upsertWallets(List<Wallet> wallets) async {
    await super.upsertWallets(wallets);
    await _write();
  }

  @override
  Future<void> upsertCategories(List<Category> categories) async {
    await super.upsertCategories(categories);
    await _write();
  }

  @override
  Future<void> upsertOperation(Operation operation) async {
    await super.upsertOperation(operation);
    await _write();
  }

  @override
  Future<void> upsertGoal(SavingsGoal goal) async {
    await super.upsertGoal(goal);
    await _write();
  }

  @override
  Future<void> upsertProject(Project project) async {
    await super.upsertProject(project);
    await _write();
  }

  @override
  Future<void> upsertBudgets(List<Budget> budgets) async {
    await super.upsertBudgets(budgets);
    await _write();
  }

  @override
  Future<void> upsertRecurrence(Recurrence recurrence) async {
    await super.upsertRecurrence(recurrence);
    await _write();
  }

  @override
  Future<void> removeOperation(String id) async {
    await super.removeOperation(id);
    await _write();
  }

  @override
  Future<void> removeWallet(String id) async {
    await super.removeWallet(id);
    await _write();
  }
}
