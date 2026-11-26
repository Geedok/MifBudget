import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/operation.dart';
import '../state/budget_store.dart';
import 'home_screen.dart';
import 'operations_screen.dart';
import 'placeholder_screen.dart';
import 'quick_entry_screen.dart';
import 'report_screen.dart';

/// Ouvre la saisie (nouvelle ou modification) puis confirme par un message
/// avec « Annuler ».
Future<void> openEntry(
  BuildContext context, {
  Operation? existing,
  OperationType initialType = OperationType.expense,
}) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  // Le message précédent masquerait le pavé numérique de la saisie.
  messenger.hideCurrentSnackBar();
  final result = await QuickEntryScreen.open(
    context,
    existing: existing,
    initialType: initialType,
  );
  if (result == null) return;
  final op = result.operation;
  final String message;
  SnackBarAction? action;
  if (result.deleted) {
    message = 'Opération supprimée';
    action = SnackBarAction(
      label: 'Annuler',
      onPressed: () => store.restoreOperation(op.id),
    );
  } else if (result.created) {
    message = '${op.type.label} de ${formatFcfa(op.amount)} enregistrée';
    action = SnackBarAction(
      label: 'Annuler',
      onPressed: () => store.deleteOperation(op.id),
    );
  } else {
    message = 'Opération modifiée';
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
      ),
      const OperationsScreen(),
      const PlaceholderScreen(
        title: 'Budgets',
        icon: Icons.pie_chart_outline,
        message: 'Les plafonds mensuels par catégorie arriveront dans une prochaine étape.',
      ),
      const PlaceholderScreen(
        title: 'Épargnes',
        icon: Icons.savings_outlined,
        message: "Le suivi de l'épargne de sûreté, de l'épargne de construction et de vos autres objectifs arrive à l'étape 3.",
      ),
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
