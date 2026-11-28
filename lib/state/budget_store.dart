import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../core/format.dart';
import '../core/projection.dart';
import '../data/defaults.dart';
import '../data/repository.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/project.dart';
import '../models/recurrence.dart';
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

/// Moyennes mensuelles sur les derniers mois complets.
class MonthlyAverages {
  const MonthlyAverages({
    required this.income,
    required this.expense,
    required this.saved,
    required this.months,
  });

  final int income;
  final int expense;

  /// Capacité d'épargne réelle : ce qui part vers les comptes épargne.
  final int saved;

  /// Nombre de mois pris en compte (0 : pas encore de mois complet).
  final int months;

  /// Ce qui reste en moyenne après les dépenses (épargne possible).
  int get leftover => income - expense;

  /// Part des revenus mise de côté.
  double get savingsRate => income == 0 ? 0 : saved / income;
}

/// Dépense (ou revenu) moyenne d'une catégorie sur les derniers mois,
/// comparée à la période précédente de même durée.
class CategoryTrend {
  const CategoryTrend({
    required this.category,
    required this.recent,
    required this.previous,
  });

  final Category? category;
  final int recent;
  final int previous;

  /// Évolution relative (null si rien sur la période précédente).
  double? get change => previous == 0 ? null : (recent - previous) / previous;
}

/// Échéance mensuelle d'une récurrence.
class Occurrence {
  const Occurrence(this.recurrence, this.month);

  final Recurrence recurrence;

  /// Premier jour du mois concerné.
  final DateTime month;

  DateTime get date => recurrence.dateIn(month);
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
    final store = BudgetStore._(repo, data, clock ?? DateTime.now);
    if (data.version < 2) await store._migrateToSavingsAccounts();
    await store._alignPersonalMoney();
    await store.processAutomaticRecurrences();
    // Changements venus de l'autre téléphone : rafraîchir l'affichage et
    // enregistrer les échéances automatiques éventuellement arrivées.
    repo.onRemoteChange(() {
      store.notifyListeners();
      store.processAutomaticRecurrences();
    });
    return store;
  }

  /// Version 0.3.0 → comptes épargne. Les épargnes étaient des enveloppes
  /// dans les portefeuilles courants : on crée un portefeuille « Compte
  /// épargne », on y rattache les objectifs, et chaque montant de départ,
  /// versement ou retrait devient un virement vers (ou depuis) ce compte.
  /// Le disponible reste donc le même qu'avant.
  Future<void> _migrateToSavingsAccounts() async {
    final legacyOps = _data.operations.where((o) => o.type.isSavings).toList();
    // Objectifs encore rattachés à un portefeuille courant (ancien modèle).
    final legacyGoals = _data.goals
        .where((g) => !(wallet(g.walletId)?.isSavings ?? false))
        .toList();
    if (legacyGoals.isEmpty && legacyOps.isEmpty) {
      _data.version = BudgetData.schemaVersion;
      return;
    }
    final t = now();
    final account = Wallet(
      id: _uuid.v4(),
      name: 'Compte épargne',
      type: WalletType.bank,
      role: WalletRole.savings,
      sortOrder: _data.wallets.length,
      updatedAt: t,
    );
    _data.wallets.add(account);
    await _repo.upsertWallets([account]);
    final fallback = wallets.where((w) => !w.isSavings).firstOrNull?.id;

    for (final legacy in legacyGoals) {
      final i = _data.goals.indexWhere((x) => x.id == legacy.id);
      final g = _data.goals[i];
      final from = g.walletId ?? fallback;
      if (g.startAmount > 0) {
        final op = Operation(
          id: _uuid.v4(),
          type: OperationType.transfer,
          amount: g.startAmount,
          date: dateOnly(g.createdAt),
          sourceWalletId: from,
          targetWalletId: account.id,
          savingsGoalId: g.id,
          note: "Reprise de l'épargne existante",
          authorId: settings.memberId,
          createdAt: t,
          updatedAt: t,
        );
        _data.operations.add(op);
        await _repo.upsertOperation(op);
      }
      _data.goals[i] = g.copyWith(
        walletId: () => account.id,
        startAmount: 0,
        updatedAt: t,
      );
      await _repo.upsertGoal(_data.goals[i]);
    }

    for (final o in legacyOps) {
      final deposit = o.type == OperationType.savingsDeposit;
      final other =
          (deposit ? o.sourceWalletId : o.targetWalletId) ??
          goal(o.savingsGoalId)?.walletId ??
          fallback;
      final converted = o.copyWith(
        type: OperationType.transfer,
        sourceWalletId: () => deposit ? other : account.id,
        targetWalletId: () => deposit ? account.id : other,
        updatedAt: t,
      );
      _replace(converted);
      await _repo.upsertOperation(converted);
    }
    _data.version = BudgetData.schemaVersion;
  }

  /// Version 1.0.3 : seul l'argent personnel est privé. Les portefeuilles
  /// personnels d'épargne deviennent des comptes du foyer, un revenu reçu
  /// sur un portefeuille personnel devient personnel, et chaque document est
  /// rangé selon la nouvelle règle. Sans effet quand tout est déjà en ordre.
  Future<void> _alignPersonalMoney() async {
    final me = settings.memberId;
    final t = now();
    final toHousehold = <Wallet>[];
    for (final (i, w) in _data.wallets.indexed) {
      if (w.shared || !w.isSavings) continue;
      if (w.ownerId != null && w.ownerId != me) continue;
      _data.wallets[i] = w.copyWith(
        shared: true,
        ownerId: () => null,
        private: false,
        updatedAt: t,
      );
      toHousehold.add(_data.wallets[i]);
    }
    if (toHousehold.isNotEmpty) await _repo.upsertWallets(toHousehold);
    for (final o in _data.operations.toList()) {
      if (o.type != OperationType.income || o.personal) continue;
      if (!isPersonalWallet(o.targetWalletId)) continue;
      final personal = o.copyWith(personal: true, updatedAt: t);
      _replace(personal);
      await _repo.upsertOperation(personal);
    }
    await _repo.reconcilePrivacy();
  }

  final BudgetRepository _repo;
  final BudgetData _data;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  DateTime now() => _clock();

  // ---------------------------------------------------------------- Lecture

  AppSettings get settings => _data.settings;

  BudgetRepository get repository => _repo;

  /// Prénom d'un membre du foyer (null si inconnu ou si c'est moi).
  String? memberName(String? id) =>
      id == null || id == settings.memberId ? null : _data.memberNames[id];

  /// Toutes les données (pour les copier vers le foyer partagé).
  BudgetData get data => _data;

  Future<void> updateSettings(AppSettings s) async {
    _data.settings = s;
    notifyListeners();
    await _repo.saveSettings(s);
  }

  /// Portefeuilles actifs : les courants d'abord, puis l'épargne.
  List<Wallet> get wallets =>
      _data.wallets.where((w) => !w.archived).toList()..sort((a, b) {
        final byRole = a.role.index.compareTo(b.role.index);
        return byRole != 0 ? byRole : a.sortOrder.compareTo(b.sortOrder);
      });

  List<Wallet> get currentWallets =>
      wallets.where((w) => !w.isSavings).toList();

  /// Portefeuilles courants communs au foyer (ceux du disponible).
  List<Wallet> get householdCurrentWallets =>
      currentWallets.where((w) => w.shared).toList();

  /// Mes portefeuilles personnels (porte-monnaie, Mobile Money perso…).
  List<Wallet> get personalWallets => wallets
      .where(
        (w) =>
            !w.shared &&
            !w.isSavings &&
            (w.ownerId == null || w.ownerId == settings.memberId),
      )
      .toList();

  bool isPersonalWallet(String? id) => personalWallets.any((w) => w.id == id);

  List<Wallet> get savingsWallets => wallets.where((w) => w.isSavings).toList();

  /// Tous les portefeuilles, archivés compris.
  List<Wallet> get allWallets => List.unmodifiable(_data.wallets);

  /// Sens d'un virement par rapport à l'épargne : +1 vers un compte
  /// épargne, −1 depuis un compte épargne, 0 sinon.
  int savingsDirection(Operation o) {
    if (o.type != OperationType.transfer) return 0;
    final from = wallet(o.sourceWalletId)?.isSavings ?? false;
    final to = wallet(o.targetWalletId)?.isSavings ?? false;
    if (to && !from) return 1;
    if (from && !to) return -1;
    return 0;
  }

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

  /// Catégories principales archivées (pour pouvoir les restaurer).
  List<Category> archivedTopCategories(CategoryKind kind) =>
      _data.categories
          .where((c) => c.kind == kind && c.parentId == null && c.archived)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Sous-catégories archivées d'une catégorie.
  List<Category> archivedSubcategories(String parentId) =>
      _data.categories
          .where((c) => c.parentId == parentId && c.archived)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Un nom déjà pris par une catégorie active de même niveau (sans tenir
  /// compte des majuscules ni des espaces autour).
  bool categoryNameTaken(
    String name, {
    required CategoryKind kind,
    String? parentId,
    String? exceptId,
  }) {
    final n = name.trim().toLowerCase();
    return _data.categories.any(
      (c) =>
          c.id != exceptId &&
          !c.archived &&
          c.kind == kind &&
          c.parentId == parentId &&
          c.name.trim().toLowerCase() == n,
    );
  }

  /// Nombre d'opérations (non supprimées) d'une catégorie et de ses
  /// sous-catégories.
  int categoryUsage(String categoryId) => operations
      .where(
        (o) =>
            o.categoryId == categoryId ||
            category(o.categoryId)?.parentId == categoryId,
      )
      .length;

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
      // Anciennes enveloppes (avant la reprise) : sans effet sur le solde.
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
    bool savingsWallet(String? id) => wallet(id)?.isSavings ?? false;
    for (final o in operationsInMonth(month)) {
      if (o.type == OperationType.income && !o.personal) income += o.amount;
      if (o.type == OperationType.expense && !o.personal) expense += o.amount;
      if (o.type.isSavings) continue;
      // Épargne du mois : ce que les comptes épargne ont reçu moins ce qui
      // en est sorti (hors virements d'un compte épargne à un autre).
      final into = savingsWallet(o.targetWalletId);
      final outOf = savingsWallet(o.sourceWalletId);
      if (into && !outOf) saved += o.amount;
      if (outOf && !into) saved -= o.amount;
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

  /// Objectifs actifs rattachés à un compte épargne.
  List<SavingsGoal> walletGoals(String walletId) =>
      goals.where((g) => g.walletId == walletId).toList();

  /// Entrées moins sorties du compte de l'objectif, marquées pour lui.
  int _taggedFlow(SavingsGoal g) {
    var flow = 0;
    for (final o in _data.operations) {
      if (o.deleted || o.savingsGoalId != g.id || o.type.isSavings) continue;
      if (o.targetWalletId == g.walletId) flow += o.amount;
      if (o.sourceWalletId == g.walletId) flow -= o.amount;
    }
    return flow;
  }

  /// Montant épargné pour un objectif. Seul sur son compte, il en a tout le
  /// solde ; à plusieurs, chacun a sa part de départ plus les mouvements
  /// marqués pour lui.
  int goalBalance(String goalId) {
    final g = goal(goalId);
    if (g == null) return 0;
    final walletId = g.walletId;
    if (walletId != null && !g.archived && walletGoals(walletId).length == 1) {
      return walletBalance(walletId);
    }
    return g.startAmount + _taggedFlow(g);
  }

  /// Part d'un compte épargne qui n'est attribuée à aucun objectif.
  int unallocated(String walletId) {
    final gs = walletGoals(walletId);
    if (gs.length <= 1) return gs.isEmpty ? walletBalance(walletId) : 0;
    return walletBalance(walletId) -
        gs.fold(0, (sum, g) => sum + goalBalance(g.id));
  }

  /// Total des comptes épargne.
  int get totalSaved =>
      savingsWallets.fold(0, (sum, w) => sum + walletBalance(w.id));

  /// Argent disponible du foyer : portefeuilles courants communs (l'argent
  /// personnel n'en fait pas partie).
  int get available =>
      householdCurrentWallets.fold(0, (sum, w) => sum + walletBalance(w.id));

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

  /// Quand un compte qui n'avait qu'un objectif en reçoit un deuxième, le
  /// premier garde ce qu'il avait (tout le solde) moins la part de départ
  /// [given] attribuée au nouveau.
  Future<void> _splitSoleGoal(String walletId, int given) async {
    final existing = walletGoals(walletId);
    if (existing.length != 1) return;
    final g = existing.first;
    final keep = walletBalance(walletId) - given - _taggedFlow(g);
    final updated = g.copyWith(startAmount: keep, updatedAt: now());
    _data.goals[_data.goals.indexWhere((x) => x.id == g.id)] = updated;
    await _repo.upsertGoal(updated);
  }

  // ------------------------------------------------- Tendances et projections

  /// Premier mois où une opération a été saisie (les mois d'avant ne
  /// comptent pas dans les moyennes).
  DateTime? get firstActivityMonth {
    DateTime? first;
    for (final o in operations) {
      if (first == null || o.date.isBefore(first)) first = o.date;
    }
    return first == null ? null : DateTime(first.year, first.month);
  }

  /// Les [count] derniers mois complets (avant le mois en cours) depuis le
  /// début de l'utilisation, du plus ancien au plus récent.
  List<DateTime> lastCompleteMonths(int count) {
    final t = now();
    final start = firstActivityMonth;
    if (start == null) return const [];
    return [for (var i = count; i >= 1; i--) DateTime(t.year, t.month - i)]
        .where((m) => !m.isBefore(start))
        .toList();
  }

  /// Moyennes des [months] derniers mois complets.
  MonthlyAverages averages({int months = 3}) {
    final list = lastCompleteMonths(months).map(monthSummary).toList();
    return MonthlyAverages(
      income: average(list.map((m) => m.income)),
      expense: average(list.map((m) => m.expense)),
      saved: average(list.map((m) => m.saved)),
      months: list.length,
    );
  }

  /// Ce qui est entré sur un objectif pendant un mois, moins ce qui en est
  /// sorti (tout le compte s'il y est seul, sinon les mouvements marqués).
  int goalFlowInMonth(SavingsGoal g, DateTime month) {
    final walletId = g.walletId;
    final sole = walletId != null && walletGoals(walletId).length == 1;
    var flow = 0;
    for (final o in operationsInMonth(month)) {
      if (o.type.isSavings) continue;
      if (!sole && o.savingsGoalId != g.id) continue;
      if (o.targetWalletId == walletId) flow += o.amount;
      if (o.sourceWalletId == walletId) flow -= o.amount;
    }
    return flow;
  }

  /// Rythme d'épargne d'un objectif : moyenne mensuelle des 3 derniers mois
  /// complets, ou le mois en cours s'il n'y en a pas encore.
  int goalPace(SavingsGoal g, {int months = 3}) {
    final list = lastCompleteMonths(months);
    if (list.isEmpty) return goalFlowInMonth(g, now());
    return average(list.map((m) => goalFlowInMonth(g, m)));
  }

  /// Mois où la cible sera atteinte au rythme actuel (null si l'objectif
  /// n'avance pas ; le mois en cours si c'est déjà atteint).
  DateTime? goalReachDate(SavingsGoal g) =>
      reachDate(now(), g.target - goalBalance(g.id), goalPace(g));

  /// Moyenne mensuelle par catégorie sur les [months] derniers mois
  /// complets, comparée aux [months] mois d'avant.
  List<CategoryTrend> categoryTrends(CategoryKind kind, {int months = 3}) {
    final recent = lastCompleteMonths(months);
    if (recent.isEmpty) return const [];
    final t = now();
    final start = firstActivityMonth!;
    final before = [
      for (var i = 2 * months; i > months; i--) DateTime(t.year, t.month - i),
    ].where((m) => !m.isBefore(start)).toList();
    Map<String?, int> totals(List<DateTime> ms) {
      final map = <String?, int>{};
      for (final m in ms) {
        for (final c in totalsByCategory(m, kind)) {
          map[c.category?.id] = (map[c.category?.id] ?? 0) + c.amount;
        }
      }
      return map;
    }

    final r = totals(recent);
    final p = totals(before);
    return [
      for (final id in {...r.keys, ...p.keys})
        CategoryTrend(
          category: category(id),
          recent: ((r[id] ?? 0) / recent.length).round(),
          previous: before.isEmpty ? 0 : ((p[id] ?? 0) / before.length).round(),
        ),
    ]..sort((a, b) => b.recent.compareTo(a.recent));
  }

  // ------------------------------------------------------------ Récurrences

  /// Récurrences non arrêtées (en pause comprises), par jour du mois.
  List<Recurrence> get recurrences =>
      _data.recurrences.where((r) => !r.stopped).toList()
        ..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));

  List<Recurrence> get stoppedRecurrences =>
      _data.recurrences.where((r) => r.stopped).toList();

  Recurrence? recurrence(String? id) {
    for (final r in _data.recurrences) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// L'échéance d'un mois a-t-elle déjà été traitée (enregistrée, ou
  /// ignorée, ce qui laisse une opération supprimée) ?
  bool isHandled(Recurrence r, DateTime month) => _data.operations.any(
    (o) =>
        o.recurrenceId == r.id &&
        o.date.year == month.year &&
        o.date.month == month.month,
  );

  /// Une récurrence qui touche un portefeuille absent de ce téléphone (le
  /// portefeuille privé de l'autre membre) ne regarde que son propriétaire.
  bool _concernsMe(Recurrence r) => [
    r.sourceWalletId,
    r.targetWalletId,
  ].whereType<String>().every((id) => wallet(id) != null);

  /// Échéances passées ou du jour, pas encore traitées.
  List<Occurrence> dueOccurrences() {
    final today = dateOnly(now());
    final result = <Occurrence>[];
    for (final r in _data.recurrences) {
      if (!r.active || !_concernsMe(r)) continue;
      var m = DateTime(r.startMonth.year, r.startMonth.month);
      while (!r.dateIn(m).isAfter(today)) {
        if (r.covers(m) && !isHandled(r, m)) result.add(Occurrence(r, m));
        m = DateTime(m.year, m.month + 1);
      }
    }
    return result..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Échéances à confirmer (les automatiques sont enregistrées seules).
  List<Occurrence> get pendingOccurrences =>
      dueOccurrences().where((o) => !o.recurrence.automatic).toList();

  /// Échéances des [days] prochains jours (après aujourd'hui).
  List<Occurrence> upcomingOccurrences({int days = 30}) {
    final today = dateOnly(now());
    final limit = today.add(Duration(days: days));
    final result = <Occurrence>[];
    for (final r in _data.recurrences) {
      if (!r.active || !_concernsMe(r)) continue;
      for (var i = 0; i <= 2; i++) {
        final m = DateTime(today.year, today.month + i);
        final d = r.dateIn(m);
        if (!d.isAfter(today) || d.isAfter(limit)) continue;
        if (r.covers(m) && !isHandled(r, m)) result.add(Occurrence(r, m));
      }
    }
    return result..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Échéances d'un mois pas encore enregistrées (à venir ou à confirmer).
  List<Occurrence> remainingInMonth(DateTime month) {
    final m = DateTime(month.year, month.month);
    return [
      for (final r in _data.recurrences)
        if (r.active && r.covers(m) && !isHandled(r, m)) Occurrence(r, m),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Opération correspondant à une échéance (pas encore enregistrée).
  Operation draftFor(Occurrence o) {
    final r = o.recurrence;
    final t = now();
    return Operation(
      id: r.operationIdFor(o.month),
      type: r.type,
      amount: r.amount,
      date: o.date,
      categoryId: r.categoryId,
      sourceWalletId: r.sourceWalletId,
      targetWalletId: r.targetWalletId,
      savingsGoalId: r.savingsGoalId,
      projectId: r.projectId,
      recurrenceId: r.id,
      note: r.note,
      authorId: settings.memberId,
      createdAt: t,
      updatedAt: t,
    );
  }

  /// Enregistre l'échéance (montant éventuellement ajusté).
  Future<Operation> confirmOccurrence(Occurrence o, {int? amount}) {
    final d = draftFor(o);
    return addOperation(
      id: d.id,
      type: d.type,
      amount: amount ?? d.amount,
      date: d.date,
      categoryId: d.categoryId,
      sourceWalletId: d.sourceWalletId,
      targetWalletId: d.targetWalletId,
      savingsGoalId: d.savingsGoalId,
      projectId: d.projectId,
      recurrenceId: d.recurrenceId,
      note: d.note,
    );
  }

  /// Ignore l'échéance du mois : une opération supprimée la marque comme
  /// traitée (et peut être restaurée).
  Future<void> skipOccurrence(Occurrence o) async {
    final d = draftFor(o);
    await addOperation(
      id: d.id,
      type: d.type,
      amount: d.amount,
      date: d.date,
      categoryId: d.categoryId,
      sourceWalletId: d.sourceWalletId,
      targetWalletId: d.targetWalletId,
      savingsGoalId: d.savingsGoalId,
      projectId: d.projectId,
      recurrenceId: d.recurrenceId,
      note: d.note,
      deleted: true,
    );
  }

  /// Annule aussitôt une échéance confirmée ou ignorée : l'opération est
  /// effacée et l'échéance redevient à confirmer.
  Future<void> undoOccurrence(String operationId) async {
    _data.operations.removeWhere((o) => o.id == operationId);
    notifyListeners();
    await _repo.removeOperation(operationId);
  }

  /// Enregistre les échéances automatiques en retard (au démarrage et
  /// après une modification) ; renvoie le nombre d'opérations créées.
  Future<int> processAutomaticRecurrences() async {
    final due = dueOccurrences().where((o) => o.recurrence.automatic);
    var n = 0;
    for (final o in due) {
      await confirmOccurrence(o);
      n++;
    }
    return n;
  }

  /// Nouvelle récurrence. Si [linkedOperationId] est donné, cette opération
  /// devient l'échéance de son mois (pour ne pas l'enregistrer deux fois).
  Future<Recurrence> addRecurrence({
    required OperationType type,
    required int amount,
    String? categoryId,
    String? sourceWalletId,
    String? targetWalletId,
    String? savingsGoalId,
    String? projectId,
    String note = '',
    required int dayOfMonth,
    required DateTime startMonth,
    DateTime? endMonth,
    bool automatic = false,
    String? linkedOperationId,
  }) async {
    final t = now();
    final r = Recurrence(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      sourceWalletId: sourceWalletId,
      targetWalletId: targetWalletId,
      savingsGoalId: savingsGoalId,
      projectId: projectId,
      note: note.trim(),
      dayOfMonth: dayOfMonth.clamp(1, 31),
      startMonth: DateTime(startMonth.year, startMonth.month),
      endMonth: endMonth == null
          ? null
          : DateTime(endMonth.year, endMonth.month),
      automatic: automatic,
      createdAt: t,
      updatedAt: t,
    );
    _data.recurrences.add(r);
    await _repo.upsertRecurrence(r);
    final linked = linkedOperationId == null
        ? null
        : operation(linkedOperationId);
    if (linked != null) {
      await updateOperation(linked.copyWith(recurrenceId: () => r.id));
    }
    notifyListeners();
    await processAutomaticRecurrences();
    return r;
  }

  Future<void> updateRecurrence(Recurrence r) async {
    final updated = r.copyWith(updatedAt: now());
    final i = _data.recurrences.indexWhere((x) => x.id == r.id);
    if (i >= 0) _data.recurrences[i] = updated;
    notifyListeners();
    await _repo.upsertRecurrence(updated);
    await processAutomaticRecurrences();
  }

  /// Revenus récurrents du mois pas encore reçus.
  List<Occurrence> expectedIncomes(DateTime month) =>
      remainingInMonth(month)
          .where((o) => o.recurrence.type == OperationType.income)
          .toList();

  /// Dépenses récurrentes du mois pas encore enregistrées (toutes ou d'une
  /// catégorie principale).
  int plannedExpenses(DateTime month, {String? categoryId}) =>
      remainingInMonth(month)
          .where(
            (o) =>
                o.recurrence.type == OperationType.expense &&
                (categoryId == null ||
                    topCategory(o.recurrence.categoryId)?.id == categoryId),
          )
          .fold(0, (sum, o) => sum + o.recurrence.amount);

  // ------------------------------------------------------ Argent personnel

  /// Ce qui reste d'argent personnel : total de mes portefeuilles personnels.
  int get personalBalance =>
      personalWallets.fold(0, (sum, w) => sum + walletBalance(w.id));

  /// Argent arrivé sur mes portefeuilles personnels depuis ailleurs pendant
  /// le mois (versement mensuel, dépôt…).
  int personalReceived(DateTime month) {
    var total = 0;
    for (final o in operationsInMonth(month)) {
      if (isPersonalWallet(o.targetWalletId) &&
          !isPersonalWallet(o.sourceWalletId)) {
        total += o.amount;
      }
    }
    return total;
  }

  /// Mes dépenses personnelles du mois.
  List<Operation> personalExpenses(DateTime month) =>
      operationsInMonth(month)
          .where((o) => o.type == OperationType.expense && o.personal)
          .toList();

  int personalSpent(DateTime month) =>
      personalExpenses(month).fold(0, (sum, o) => sum + o.amount);

  /// Dépenses personnelles du mois par catégorie principale.
  List<CategoryTotal> personalByCategory(DateTime month) {
    final totals = <String?, (int, int)>{};
    for (final o in personalExpenses(month)) {
      final id = topCategory(o.categoryId)?.id;
      final prev = totals[id] ?? (0, 0);
      totals[id] = (prev.$1 + o.amount, prev.$2 + 1);
    }
    return [
      for (final MapEntry(key: id, value: (amount, count)) in totals.entries)
        CategoryTotal(category: category(id), amount: amount, count: count),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Reçu (revenus) et dépensé (dépenses) en argent personnel, mois par mois.
  List<MonthSummary> personalMonths(DateTime month, {int count = 6}) => [
    for (var i = count - 1; i >= 0; i--)
      () {
        final m = DateTime(month.year, month.month - i);
        return MonthSummary(
          income: personalReceived(m),
          expense: personalSpent(m),
          month: m,
        );
      }(),
  ];

  /// Récurrence du versement mensuel (si l'argent personnel est activé).
  Recurrence? get allowance => recurrence(settings.allowanceRecurrenceId);

  /// Active (ou modifie) l'argent personnel : versement mensuel « à
  /// confirmer » d'un portefeuille commun vers un portefeuille personnel,
  /// compté comme dépense du foyer dans la catégorie Argent personnel.
  Future<void> setupPersonalMoney({
    required int amount,
    required int dayOfMonth,
    required String fromWalletId,
    required String toWalletId,
  }) async {
    final existing = allowance;
    final categoryId = category('cat-argent-personnel')?.id;
    if (existing != null && !existing.stopped) {
      await updateRecurrence(
        existing.copyWith(
          amount: amount,
          dayOfMonth: dayOfMonth,
          sourceWalletId: () => fromWalletId,
          targetWalletId: () => toWalletId,
        ),
      );
    } else {
      final t = dateOnly(now());
      final r = await addRecurrence(
        type: OperationType.expense,
        amount: amount,
        categoryId: categoryId,
        sourceWalletId: fromWalletId,
        targetWalletId: toWalletId,
        note: 'Argent personnel',
        dayOfMonth: dayOfMonth,
        // Le jour est passé ce mois-ci : on commence le mois prochain.
        startMonth: dayOfMonth >= t.day
            ? DateTime(t.year, t.month)
            : DateTime(t.year, t.month + 1),
      );
      _data.settings = _data.settings.copyWith(
        allowanceRecurrenceId: () => r.id,
      );
    }
    _data.settings = _data.settings.copyWith(personalMoney: true);
    notifyListeners();
    await _repo.saveSettings(_data.settings);
  }

  /// Désactive l'argent personnel : le versement mensuel s'arrête ; les
  /// portefeuilles et l'historique restent.
  Future<void> disablePersonalMoney() async {
    final r = allowance;
    if (r != null && !r.stopped) {
      await updateRecurrence(r.copyWith(stopped: true));
    }
    _data.settings = _data.settings.copyWith(
      personalMoney: false,
      allowanceRecurrenceId: () => null,
    );
    notifyListeners();
    await _repo.saveSettings(_data.settings);
  }

  // ----------------------------------------------------------------- Budgets

  /// Plafond d'une catégorie pour un mois (0 : pas de budget).
  int budgetLimit(DateTime month, String categoryId) {
    final id = Budget.idFor(monthKey(month), categoryId);
    for (final b in _data.budgets) {
      if (b.id == id) return b.limit;
    }
    return 0;
  }

  /// Budgets du mois (plafond > 0), dans l'ordre des catégories.
  List<Budget> budgetsFor(DateTime month) {
    final key = monthKey(month);
    final order = {
      for (final (i, c) in topCategories(CategoryKind.expense).indexed) c.id: i,
    };
    return _data.budgets.where((b) => b.month == key && b.limit > 0).toList()
      ..sort(
        (a, b) =>
            (order[a.categoryId] ?? 999).compareTo(order[b.categoryId] ?? 999),
      );
  }

  /// Dépenses du mois dans une catégorie principale (sous-catégories
  /// comprises).
  int spentIn(DateTime month, String categoryId) {
    var spent = 0;
    for (final o in operationsInMonth(month)) {
      if (o.type != OperationType.expense || o.personal) continue;
      if (topCategory(o.categoryId)?.id == categoryId) spent += o.amount;
    }
    return spent;
  }

  /// Plafond proposé : moyenne des dépenses de la catégorie sur les 3 mois
  /// précédant [month] (depuis le premier mois saisi), arrondie au millier
  /// supérieur ; null sans historique.
  int? suggestedLimit(DateTime month, String categoryId) {
    final start = firstActivityMonth;
    if (start == null) return null;
    final months = [
      for (var i = 3; i >= 1; i--) DateTime(month.year, month.month - i),
    ].where((m) => !m.isBefore(start)).toList();
    if (months.isEmpty) return null;
    final avg = average(months.map((m) => spentIn(m, categoryId)));
    if (avg <= 0) return null;
    return (avg / 1000).ceil() * 1000;
  }

  Future<void> setBudgets(DateTime month, Map<String, int> limits) async {
    final key = monthKey(month);
    final t = now();
    final changed = [
      for (final MapEntry(key: categoryId, value: limit) in limits.entries)
        if (budgetLimit(month, categoryId) != limit)
          Budget(
            categoryId: categoryId,
            month: key,
            limit: limit,
            updatedAt: t,
          ),
    ];
    if (changed.isEmpty) return;
    for (final b in changed) {
      final i = _data.budgets.indexWhere((x) => x.id == b.id);
      if (i >= 0) {
        _data.budgets[i] = b;
      } else {
        _data.budgets.add(b);
      }
    }
    notifyListeners();
    await _repo.upsertBudgets(changed);
  }

  /// Copie les plafonds du mois précédent sur [month] (sans écraser ceux
  /// déjà fixés) ; renvoie le nombre de plafonds copiés.
  Future<int> copyPreviousBudgets(DateTime month) async {
    final previous = DateTime(month.year, month.month - 1);
    final toCopy = {
      for (final b in budgetsFor(previous))
        if (budgetLimit(month, b.categoryId) == 0) b.categoryId: b.limit,
    };
    await setBudgets(month, toCopy);
    return toCopy.length;
  }

  // ----------------------------------------------------------------- Projets

  /// Projets non archivés : en cours, puis prévus, puis terminés.
  List<Project> get projects =>
      _data.projects.where((p) => !p.archived).toList()..sort((a, b) {
        int rank(Project p) => switch (p.status) {
          ProjectStatus.active => 0,
          ProjectStatus.planned => 1,
          ProjectStatus.done => 2,
        };
        final byStatus = rank(a).compareTo(rank(b));
        return byStatus != 0 ? byStatus : a.sortOrder.compareTo(b.sortOrder);
      });

  /// Projets auxquels on peut rattacher une dépense.
  List<Project> get openProjects =>
      projects.where((p) => p.status != ProjectStatus.done).toList();

  Project? project(String? id) {
    for (final p in _data.projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Operation> projectOperations(String projectId) =>
      operations.where((o) => o.projectId == projectId).toList();

  /// Dépenses rattachées au projet.
  int projectSpent(String projectId) =>
      projectOperations(projectId)
          .where((o) => o.type == OperationType.expense)
          .fold(0, (sum, o) => sum + o.amount);

  /// Ce qui manque encore pour financer le projet : budget − déjà dépensé −
  /// épargne de l'objectif qui le finance.
  int projectToFund(Project p) {
    final saved = p.goalId == null ? 0 : goalBalance(p.goalId!);
    final missing = p.budget - projectSpent(p.id) - saved;
    return missing < 0 ? 0 : missing;
  }

  /// Mois où le projet sera financé au rythme de son objectif d'épargne.
  DateTime? projectFundingDate(Project p) {
    final g = goal(p.goalId);
    if (g == null) return null;
    return reachDate(now(), projectToFund(p), goalPace(g));
  }

  Future<Project> addProject({
    required String name,
    required int budget,
    DateTime? targetDate,
    String? goalId,
    ProjectStatus status = ProjectStatus.planned,
  }) async {
    final t = now();
    final p = Project(
      id: _uuid.v4(),
      name: name.trim(),
      budget: budget,
      targetDate: targetDate == null
          ? null
          : DateTime(targetDate.year, targetDate.month),
      goalId: goalId,
      status: status,
      sortOrder: _data.projects.length,
      createdAt: t,
      updatedAt: t,
    );
    _data.projects.add(p);
    notifyListeners();
    await _repo.upsertProject(p);
    return p;
  }

  Future<void> updateProject(Project p) async {
    final updated = p.copyWith(updatedAt: now());
    final i = _data.projects.indexWhere((x) => x.id == p.id);
    if (i >= 0) _data.projects[i] = updated;
    notifyListeners();
    await _repo.upsertProject(updated);
  }

  Future<SavingsGoal> addGoal({
    required String name,
    required int target,
    DateTime? targetDate,
    String? walletId,
    int startAmount = 0,
    String icon = 'epargne',
  }) async {
    if (walletId != null) await _splitSoleGoal(walletId, startAmount);
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
    final before = goal(g.id);
    final movedTo = g.walletId;
    if (!g.archived && movedTo != null && before?.walletId != movedTo) {
      await _splitSoleGoal(movedTo, g.startAmount);
    }
    final updated = g.copyWith(updatedAt: now());
    final i = _data.goals.indexWhere((x) => x.id == g.id);
    if (i >= 0) _data.goals[i] = updated;
    notifyListeners();
    await _repo.upsertGoal(updated);
  }

  /// Mouvements d'un objectif, les plus récents d'abord : ceux marqués pour
  /// lui, ou tous ceux de son compte s'il y est seul.
  List<Operation> goalOperations(String goalId) {
    final g = goal(goalId);
    if (g == null) return const [];
    final walletId = g.walletId;
    final sole = walletId != null && walletGoals(walletId).length == 1;
    return operations
        .where(
          (o) =>
              o.savingsGoalId == goalId ||
              (sole &&
                  (o.sourceWalletId == walletId ||
                      o.targetWalletId == walletId)),
        )
        .toList();
  }

  /// Mouvements d'un portefeuille, les plus récents d'abord.
  List<Operation> walletOperations(String walletId) => operations
      .where(
        (o) => o.sourceWalletId == walletId || o.targetWalletId == walletId,
      )
      .toList();

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
      if (o.type != type || o.personal) continue;
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
    String? projectId,
    String? recurrenceId,
    String? id,
    String note = '',
    bool deleted = false,
    bool personal = false,
  }) async {
    final t = now();
    final op = Operation(
      id: id ?? _uuid.v4(),
      type: type,
      amount: amount,
      date: dateOnly(date),
      categoryId: categoryId,
      sourceWalletId: sourceWalletId,
      targetWalletId: targetWalletId,
      savingsGoalId: savingsGoalId,
      projectId: projectId,
      recurrenceId: recurrenceId,
      deleted: deleted,
      deletedAt: deleted ? t : null,
      personal: personal,
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

  Future<Wallet> addWallet({
    required String name,
    required WalletType type,
    WalletRole role = WalletRole.current,
    int openingBalance = 0,
    bool shared = true,
  }) async {
    final w = Wallet(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      // L'argent personnel est toujours de l'argent courant.
      role: shared ? role : WalletRole.current,
      openingBalance: openingBalance,
      shared: shared,
      ownerId: shared ? null : settings.memberId,
      private: !shared,
      sortOrder: _data.wallets.length,
      updatedAt: now(),
    );
    _data.wallets.add(w);
    notifyListeners();
    await _repo.upsertWallets([w]);
    return w;
  }

  /// Nouvelle catégorie (ou sous-catégorie si [parentId] est donné : elle
  /// prend alors le type, le groupe, l'icône et la couleur de sa parente).
  Future<Category> addCategory({
    required String name,
    required CategoryKind kind,
    CategoryGroup? group,
    String? parentId,
    String icon = 'divers',
    int color = 0xFF6E7A74,
  }) async {
    final parent = category(parentId);
    final siblings = _data.categories.where(
      (c) => c.parentId == parentId && c.kind == (parent?.kind ?? kind),
    );
    final c = Category(
      id: _uuid.v4(),
      name: name.trim(),
      kind: parent?.kind ?? kind,
      group: parent != null ? parent.group : group,
      parentId: parentId,
      icon: parent?.icon ?? icon,
      color: parent?.color ?? color,
      sortOrder: siblings.fold(
        0,
        (m, c) => c.sortOrder >= m ? c.sortOrder + 1 : m,
      ),
      updatedAt: now(),
    );
    _data.categories.add(c);
    notifyListeners();
    await _repo.upsertCategories([c]);
    return c;
  }

  /// Modifie une catégorie. Pour une catégorie principale, le groupe,
  /// l'icône et la couleur sont reportés sur ses sous-catégories.
  Future<void> updateCategory(Category c) async {
    final t = now();
    final changed = <Category>[c.copyWith(updatedAt: t)];
    if (!c.isSub) {
      for (final sub in _data.categories.where((x) => x.parentId == c.id)) {
        if (sub.group == c.group &&
            sub.icon == c.icon &&
            sub.color == c.color) {
          continue;
        }
        changed.add(
          sub.copyWith(
            group: () => c.group,
            icon: c.icon,
            color: c.color,
            updatedAt: t,
          ),
        );
      }
    }
    for (final x in changed) {
      final i = _data.categories.indexWhere((y) => y.id == x.id);
      if (i >= 0) _data.categories[i] = x;
    }
    notifyListeners();
    await _repo.upsertCategories(changed);
  }

  /// Portefeuilles archivés (à remettre en service depuis les Réglages).
  List<Wallet> get archivedWallets =>
      _data.wallets.where((w) => w.archived).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Un portefeuille qui n'a jamais servi (aucune opération, même
  /// supprimée, aucun objectif, aucune récurrence) peut être supprimé pour
  /// de bon ; sinon on l'archive pour ne pas fausser l'historique.
  bool walletUnused(String id) =>
      !_data.operations.any(
        (o) => o.sourceWalletId == id || o.targetWalletId == id,
      ) &&
      !_data.goals.any((g) => g.walletId == id) &&
      !_data.recurrences.any(
        (r) => r.sourceWalletId == id || r.targetWalletId == id,
      ) &&
      (wallet(id)?.openingBalance ?? 0) == 0;

  /// Supprime un portefeuille inutilisé, ou l'archive s'il a déjà servi.
  /// Rend true s'il a été supprimé pour de bon.
  Future<bool> removeWallet(String id) async {
    final w = wallet(id);
    if (w == null) return false;
    if (!walletUnused(id)) {
      await updateWallet(w.copyWith(archived: true));
      return false;
    }
    _data.wallets.removeWhere((x) => x.id == id);
    notifyListeners();
    await _repo.removeWallet(id);
    return true;
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
