import 'dart:convert';
import 'dart:io';

import '../models/category.dart';
import '../models/operation.dart';
import '../models/settings.dart';
import '../models/wallet.dart';

/// Toutes les données du foyer, telles que lues au démarrage.
class BudgetData {
  BudgetData({
    this.settings = const AppSettings(),
    List<Wallet>? wallets,
    List<Category>? categories,
    List<Operation>? operations,
  }) : wallets = wallets ?? [],
       categories = categories ?? [],
       operations = operations ?? [];

  AppSettings settings;
  final List<Wallet> wallets;
  final List<Category> categories;
  final List<Operation> operations;

  static const schemaVersion = 1;

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'reglages': settings.toJson(),
    'portefeuilles': wallets.map((w) => w.toJson()).toList(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'operations': operations.map((o) => o.toJson()).toList(),
  };

  factory BudgetData.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) =>
        ((j[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return BudgetData(
      settings: AppSettings.fromJson(
        (j['reglages'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      wallets: list('portefeuilles').map(Wallet.fromJson).toList(),
      categories: list('categories').map(Category.fromJson).toList(),
      operations: list('operations').map(Operation.fromJson).toList(),
    );
  }
}

/// Accès aux données. Une écriture par élément, pour pouvoir brancher
/// Cloud Firestore (un document par élément) à la place du stockage local.
abstract class BudgetRepository {
  Future<BudgetData> load();
  Future<void> saveSettings(AppSettings settings);
  Future<void> upsertWallets(List<Wallet> wallets);
  Future<void> upsertCategories(List<Category> categories);
  Future<void> upsertOperation(Operation operation);
}

/// Stockage en mémoire, pour les tests.
class MemoryRepository implements BudgetRepository {
  MemoryRepository([BudgetData? initial]) : data = initial ?? BudgetData();

  final BudgetData data;

  @override
  Future<BudgetData> load() async => BudgetData.fromJson(
    jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
  );

  @override
  Future<void> saveSettings(AppSettings settings) async =>
      data.settings = settings;

  @override
  Future<void> upsertWallets(List<Wallet> wallets) async {
    for (final w in wallets) {
      _upsert(data.wallets, w, (x) => x.id == w.id);
    }
  }

  @override
  Future<void> upsertCategories(List<Category> categories) async {
    for (final c in categories) {
      _upsert(data.categories, c, (x) => x.id == c.id);
    }
  }

  @override
  Future<void> upsertOperation(Operation operation) async =>
      _upsert(data.operations, operation, (x) => x.id == operation.id);
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
}
