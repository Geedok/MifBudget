import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../core/format.dart';
import '../data/defaults.dart';
import '../data/repository.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/savings_goal.dart';
import '../models/settings.dart';
import '../models/wallet.dart';

class MonthSummary {
  const MonthSummary({
    required this.income,
    required this.expense,
    this.saved = 0,
    this.month,
  });

  /// Premier jour du mois concerné (si connu).
  final DateTime? month;
  final int income;
  final int expense;

  /// Mis de côté dans le mois : versements moins retraits d'épargne.
  final int saved;
  int get balance => income - expense;

  /// Part des revenus déjà dépensée (0 si aucun revenu).
  double get spentRatio => income == 0 ? 0 : expense / income;
}

/// Total d'une catégorie principale sur un mois, avec le détail par
/// sous-catégorie (l'argent saisi directement sur la catégorie principale
/// apparaît sous son propre nom).
class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.count,
    this.subs = const [],
  });

  /// Null pour les opérations sans catégorie connue.
  final Category? category;
  final int amount;

  /// Nombre d'opérations.
  final int count;
  final List<CategoryTotal> subs;
}

/// État de l'application : charge les données, calcule soldes et totaux,
/// et enregistre chaque changement dans le dépôt.
class BudgetStore extends ChangeNotifier {
  BudgetStore._(this._repo, this._data, this._clock);

  static Future<BudgetStore> open(
    BudgetRepository repo, {
    DateTime Function()? clock,
  }) async {
    final data = await repo.load();
    return BudgetStore._(repo, data, clock ?? DateTime.now);
  }

  final BudgetRepository _repo;
  final BudgetData _data;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  DateTime now() => _clock();

  // ---------------------------------------------------------------- Lecture

  AppSettings get settings => _data.settings;

  List<Wallet> get wallets =>
      _data.wallets.where((w) => !w.archived).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Wallet? wallet(String? id) {
    for (final w in _data.wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  Category? category(String? id) {
    for (final c in _data.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// La catégorie principale (la parente d'une sous-catégorie).
  Category? topCategory(String? id) {
    final c = category(id);
    if (c == null || c.parentId == null) return c;
    return category(c.parentId);
  }

  List<Category> topCategories(CategoryKind kind) =>
      _data.categories
          .where((c) => c.kind == kind && c.parentId == null && !c.archived)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Category> subcategories(String parentId) =>
      _data.categories
          .where((c) => c.parentId == parentId && !c.archived)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Opérations non supprimées, les plus récentes d'abord.
  List<Operation> get operations =>
      _data.operations.where((o) => !o.deleted).toList()..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });

  Operation? operation(String id) {
    for (final o in _data.operations) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<Operation> operationsInMonth(DateTime month) => operations
      .where((o) => o.date.year == month.year && o.date.month == month.month)
      .toList();

  /// Solde = solde de départ + entrées − sorties.
  int walletBalance(String walletId) {
    final w = wallet(walletId);
    var balance = w?.openingBalance ?? 0;
    for (final o in _data.operations) {
      // Une épargne reste dans son portefeuille : elle ne change pas le solde.
      if (o.deleted || o.type.isSavings) continue;
      if (o.targetWalletId == walletId) balance += o.amount;
      if (o.sourceWalletId == walletId) balance -= o.amount;
    }
    return balance;
  }

  int get totalBalance =>
      wallets.fold(0, (sum, w) => sum + walletBalance(w.id));

  MonthSummary monthSummary(DateTime month) {
    var income = 0;
    var expense = 0;
    var saved = 0;
    for (final o in operationsInMonth(month)) {
      switch (o.type) {
        case OperationType.income:
          income += o.amount;
        case OperationType.expense:
          expense += o.amount;
        case OperationType.savingsDeposit:
          saved += o.amount;
        case OperationType.savingsWithdrawal:
          saved -= o.amount;
        case OperationType.transfer:
          break;
      }
    }
    return MonthSummary(
      income: income,
      expense: expense,
      saved: saved,
      month: DateTime(month.year, month.month),
    );
  }

  // ---------------------------------------------------------------- Épargne

  /// Objectifs d'épargne actifs, dans l'ordre choisi.
  List<SavingsGoal> get goals =>
      _data.goals.where((g) => !g.archived).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  SavingsGoal? goal(String? id) {
    for (final g in _data.goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Montant épargné = montant de départ + versements − retraits.
  int goalBalance(String goalId) {
    var balance = goal(goalId)?.startAmount ?? 0;
    for (final o in _data.operations) {
      if (o.deleted || o.savingsGoalId != goalId) continue;
      if (o.type == OperationType.savingsDeposit) balance += o.amount;
      if (o.type == OperationType.savingsWithdrawal) balance -= o.amount;
    }
    return balance;
  }

  /// Total mis de côté dans les objectifs actifs.
  int get totalSaved => goals.fold(0, (sum, g) => sum + goalBalance(g.id));

  /// Argent disponible : portefeuilles moins l'argent mis de côté.
  int get available => totalBalance - totalSaved;

  /// Versement mensuel nécessaire pour atteindre la cible à la date cible
  /// (mois en cours compris) ; null sans date cible ou si c'est atteint.
  int? monthlyNeeded(SavingsGoal g) {
    final date = g.targetDate;
    if (date == null) return null;
    final remaining = g.target - goalBalance(g.id);
    if (remaining <= 0) return null;
    final t = now();
    final months = (date.year - t.year) * 12 + date.month - t.month + 1;
    if (months <= 0) return remaining;
    return (remaining / months).ceil();
  }

  /// Dépenses mensuelles moyennes des 3 derniers mois complets (0 si aucune).
  int averageMonthlyExpense({int months = 3}) {
    final t = now();
    var total = 0;
    var counted = 0;
    for (var i = 1; i <= months; i++) {
      final m = monthSummary(DateTime(t.year, t.month - i));
      if (m.expense == 0) continue;
      total += m.expense;
      counted++;
    }
    return counted == 0 ? 0 : total ~/ counted;
  }

  Future<SavingsGoal> addGoal({
    required String name,
    required int target,
    DateTime? targetDate,
    String? walletId,
    int startAmount = 0,
    String icon = 'epargne',
  }) async {
    final t = now();
    final g = SavingsGoal(
      id: _uuid.v4(),
      name: name.trim(),
      target: target,
      targetDate: targetDate == null
          ? null
          : DateTime(targetDate.year, targetDate.month),
      walletId: walletId,
      startAmount: startAmount,
      icon: icon,
      sortOrder: _data.goals.length,
      createdAt: t,
      updatedAt: t,
    );
    _data.goals.add(g);
    notifyListeners();
    await _repo.upsertGoal(g);
    return g;
  }

  Future<void> updateGoal(SavingsGoal g) async {
    final updated = g.copyWith(updatedAt: now());
    final i = _data.goals.indexWhere((x) => x.id == g.id);
    if (i >= 0) _data.goals[i] = updated;
    notifyListeners();
    await _repo.upsertGoal(updated);
  }

  /// Opérations d'un objectif, les plus récentes d'abord.
  List<Operation> goalOperations(String goalId) =>
      operations.where((o) => o.savingsGoalId == goalId).toList();

  /// Résumés des [count] mois se terminant par [month], du plus ancien au
  /// plus récent.
  List<MonthSummary> recentMonths(DateTime month, {int count = 6}) => [
    for (var i = count - 1; i >= 0; i--)
      monthSummary(DateTime(month.year, month.month - i)),
  ];

  /// Revenus (ou dépenses) du mois regroupés par catégorie principale, du
  /// plus gros au plus petit.
  List<CategoryTotal> totalsByCategory(DateTime month, CategoryKind kind) {
    final type = kind == CategoryKind.income
        ? OperationType.income
        : OperationType.expense;
    final tops = <String?, Map<String?, (int, int)>>{};
    for (final o in operationsInMonth(month)) {
      if (o.type != type) continue;
      final cat = category(o.categoryId);
      final top = topCategory(o.categoryId);
      final subs = tops.putIfAbsent(top?.id, () => {});
      final key = cat?.id;
      final prev = subs[key] ?? (0, 0);
      subs[key] = (prev.$1 + o.amount, prev.$2 + 1);
    }
    final result = <CategoryTotal>[];
    for (final MapEntry(key: topId, value: subs) in tops.entries) {
      final subTotals = [
        for (final MapEntry(key: id, value: (amount, count)) in subs.entries)
          CategoryTotal(category: category(id), amount: amount, count: count),
      ]..sort((a, b) => b.amount.compareTo(a.amount));
      result.add(
        CategoryTotal(
          category: category(topId),
          amount: subTotals.fold(0, (sum, t) => sum + t.amount),
          count: subTotals.fold(0, (sum, t) => sum + t.count),
          subs: subTotals,
        ),
      );
    }
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  /// Catégories principales les plus utilisées ces 90 derniers jours (puis
  /// les plus récentes en cas d'égalité), complétées par l'ordre par défaut.
  List<Category> frequentCategories(CategoryKind kind, {int count = 7}) {
    final since = dateOnly(now()).subtract(const Duration(days: 90));
    final uses = <String, int>{};
    final lastUse = <String, DateTime>{};
    for (final o in operations) {
      if (o.date.isBefore(since)) continue;
      final top = topCategory(o.categoryId);
      if (top == null || top.kind != kind || top.archived) continue;
      uses[top.id] = (uses[top.id] ?? 0) + 1;
      final last = lastUse[top.id];
      if (last == null || o.createdAt.isAfter(last)) {
        lastUse[top.id] = o.createdAt;
      }
    }
    final all = topCategories(kind);
    final used = all.where((c) => uses.containsKey(c.id)).toList()
      ..sort((a, b) {
        final byCount = uses[b.id]!.compareTo(uses[a.id]!);
        return byCount != 0
            ? byCount
            : lastUse[b.id]!.compareTo(lastUse[a.id]!);
      });
    final rest = all.where((c) => !uses.containsKey(c.id));
    return [...used, ...rest].take(count).toList();
  }

  /// Portefeuille de la dernière opération de ce type, pour le présélectionner.
  String? lastWalletFor(OperationType type) {
    final ops = _data.operations.where((o) => !o.deleted && o.type == type);
    Operation? last;
    for (final o in ops) {
      if (last == null || o.createdAt.isAfter(last.createdAt)) last = o;
    }
    if (last == null) return null;
    final id = type == OperationType.income
        ? last.targetWalletId
        : last.sourceWalletId;
    return wallet(id)?.archived == false ? id : null;
  }

  // ------------------------------------------------------------- Écriture

  Future<void> completeSetup({
    required String memberName,
    int cash = 0,
    int bank = 0,
    int mobileMoney = 0,
  }) async {
    final t = now();
    if (_data.categories.isEmpty) {
      final cats = defaultCategories(t);
      _data.categories.addAll(cats);
      await _repo.upsertCategories(cats);
    }
    final ws = defaultWallets(
      t,
      cash: cash,
      bank: bank,
      mobileMoney: mobileMoney,
    );
    for (final w in ws) {
      final i = _data.wallets.indexWhere((x) => x.id == w.id);
      if (i >= 0) {
        _data.wallets[i] = w;
      } else {
        _data.wallets.add(w);
      }
    }
    await _repo.upsertWallets(ws);
    _data.settings = _data.settings.copyWith(
      setupDone: true,
      memberId: _data.settings.memberId.isEmpty
          ? _uuid.v4()
          : _data.settings.memberId,
      memberName: memberName.trim(),
    );
    await _repo.saveSettings(_data.settings);
    notifyListeners();
  }

  Future<Operation> addOperation({
    required OperationType type,
    required int amount,
    required DateTime date,
    String? categoryId,
    String? sourceWalletId,
    String? targetWalletId,
    String? savingsGoalId,
    String note = '',
  }) async {
    final t = now();
    final op = Operation(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      date: dateOnly(date),
      categoryId: categoryId,
      sourceWalletId: sourceWalletId,
      targetWalletId: targetWalletId,
      savingsGoalId: savingsGoalId,
      note: note.trim(),
      authorId: settings.memberId,
      createdAt: t,
      updatedAt: t,
    );
    _data.operations.add(op);
    notifyListeners();
    await _repo.upsertOperation(op);
    return op;
  }

  Future<void> updateOperation(Operation op) async {
    final updated = op.copyWith(updatedAt: now(), date: dateOnly(op.date));
    _replace(updated);
    notifyListeners();
    await _repo.upsertOperation(updated);
  }

  /// Suppression douce : l'opération est gardée et peut être restaurée.
  Future<void> deleteOperation(String id) async {
    final op = operation(id);
    if (op == null) return;
    final t = now();
    final deleted = op.copyWith(
      deleted: true,
      deletedAt: () => t,
      updatedAt: t,
    );
    _replace(deleted);
    notifyListeners();
    await _repo.upsertOperation(deleted);
  }

  Future<void> restoreOperation(String id) async {
    final op = operation(id);
    if (op == null) return;
    final restored = op.copyWith(
      deleted: false,
      deletedAt: () => null,
      updatedAt: now(),
    );
    _replace(restored);
    notifyListeners();
    await _repo.upsertOperation(restored);
  }

  void _replace(Operation op) {
    final i = _data.operations.indexWhere((o) => o.id == op.id);
    if (i >= 0) _data.operations[i] = op;
  }

  Future<void> setTheme(ThemeChoice theme) async {
    _data.settings = _data.settings.copyWith(theme: theme);
    notifyListeners();
    await _repo.saveSettings(_data.settings);
  }

  Future<void> setMemberName(String name) async {
    _data.settings = _data.settings.copyWith(memberName: name.trim());
    notifyListeners();
    await _repo.saveSettings(_data.settings);
  }

  Future<void> updateWallet(Wallet wallet) async {
    final updated = wallet.copyWith(updatedAt: now());
    final i = _data.wallets.indexWhere((w) => w.id == wallet.id);
    if (i >= 0) _data.wallets[i] = updated;
    notifyListeners();
    await _repo.upsertWallets([updated]);
  }
}

/// Donne accès au [BudgetStore] dans l'arbre des widgets et reconstruit les
/// écrans quand les données changent.
class StoreScope extends InheritedNotifier<BudgetStore> {
  const StoreScope({
    super.key,
    required BudgetStore store,
    required super.child,
  }) : super(notifier: store);

  static BudgetStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Accès sans abonnement aux changements (pour les actions).
  static BudgetStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
