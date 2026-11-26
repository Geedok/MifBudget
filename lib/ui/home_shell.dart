import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/budget.dart';
import '../models/operation.dart';
import '../state/budget_store.dart';
import 'budgets_screen.dart';
import 'home_screen.dart';
import 'operations_screen.dart';
import 'quick_entry_screen.dart';
import 'report_screen.dart';
import 'savings_screen.dart';

/// Ouvre la saisie (nouvelle ou modification) puis confirme par un message
/// avec « Annuler ».
Future<void> openEntry(
  BuildContext context, {
  Operation? existing,
  OperationType initialType = OperationType.expense,
  String? initialGoalId,
  String? initialWalletId,
  EntryMode mode = EntryMode.normal,
}) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  // Le message précédent masquerait le pavé numérique de la saisie.
  messenger.hideCurrentSnackBar();
  final result = await QuickEntryScreen.open(
    context,
    existing: existing,
    initialType: initialType,
    initialGoalId: initialGoalId,
    initialWalletId: initialWalletId,
    mode: mode,
  );
  if (result == null) return;
  final op = result.operation;
  String message;
  SnackBarAction? action;
  if (result.deleted) {
    message = 'Opération supprimée';
    action = SnackBarAction(
      label: 'Annuler',
      onPressed: () => store.restoreOperation(op.id),
    );
  } else if (result.created) {
    message = switch (op.type) {
      OperationType.expense =>
        'Dépense de ${formatFcfa(op.amount)} enregistrée',
      OperationType.income => 'Revenu de ${formatFcfa(op.amount)} enregistré',
      OperationType.transfer => switch (store.savingsDirection(op)) {
        > 0 => '${formatFcfa(op.amount)} mis de côté',
        < 0 => "${formatFcfa(op.amount)} retiré de l'épargne",
        _ => 'Transfert de ${formatFcfa(op.amount)} enregistré',
      },
      OperationType.savingsDeposit => '${formatFcfa(op.amount)} mis de côté',
      OperationType.savingsWithdrawal =>
        "${formatFcfa(op.amount)} retiré de l'épargne",
    };
    action = SnackBarAction(
      label: 'Annuler',
      // Une échéance récurrente annulée redevient à confirmer.
      onPressed: () => op.recurrenceId == null
          ? store.deleteOperation(op.id)
          : store.undoOccurrence(op.id),
    );
  } else {
    message = 'Opération modifiée';
  }
  if (!result.deleted) {
    final alert = budgetAlert(store, op);
    if (alert != null) message = '$message · $alert';
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: const Duration(seconds: 5),
        persist: false,
      ),
    );
}

/// Après une dépense : « Alimentation : 92 % du budget » ou « budget
/// Alimentation dépassé » quand la catégorie approche ou dépasse son
/// plafond du mois ; null sinon.
String? budgetAlert(BudgetStore store, Operation op) {
  if (op.type != OperationType.expense || op.deleted) return null;
  final category = store.topCategory(op.categoryId);
  if (category == null) return null;
  final limit = store.budgetLimit(op.date, category.id);
  if (limit == 0) return null;
  final spent = store.spentIn(op.date, category.id);
  return switch (budgetStatus(spent, limit)) {
    BudgetStatus.over => 'budget ${category.name} dépassé',
    BudgetStatus.warning =>
      '${category.name} : ${formatPercent(spent / limit)} du budget',
    BudgetStatus.ok => null,
  };
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onSeeAllOperations: () => setState(() => _tab = 1),
        onOpenReport: () => setState(() => _tab = 4),
        onOpenSavings: () => setState(() => _tab = 3),
        onOpenBudgets: () => setState(() => _tab = 2),
      ),
      const OperationsScreen(),
      const BudgetsScreen(),
      const SavingsScreen(),
      const ReportScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter une opération',
        onPressed: () => openEntry(context),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_filled),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Opérations',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            label: 'Épargnes',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Rapports'),
        ],
      ),
    );
  }
}
