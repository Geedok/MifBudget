import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/operation.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

/// Opérations d'un mois, regroupées par jour. Toucher pour modifier,
/// glisser vers la gauche pour supprimer (annulable).
class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final now = store.now();
    final month = _month ?? DateTime(now.year, now.month);
    final ops = store.operationsInMonth(month);
    final summary = store.monthSummary(month);

    final byDay = <DateTime, List<Operation>>{};
    for (final o in ops) {
      byDay.putIfAbsent(dateOnly(o.date), () => []).add(o);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Opérations')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          MonthSwitcher(
            month: month,
            now: now,
            onChanged: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: 4),
          MifCard(
            child: Row(
              children: [
                _Total('Revenus', summary.income, mif.income),
                _Total('Dépenses', summary.expense, mif.text),
                _Total(
                  'Reste',
                  summary.balance,
                  summary.balance < 0 ? mif.terracotta : mif.text,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (ops.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'Aucune opération ce mois-ci.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: mif.textSecondary),
              ),
            ),
          for (final entry in byDay.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                dayLabel(entry.key, now: now),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mif.textSecondary,
                ),
              ),
            ),
            MifCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final op in entry.value)
                    Dismissible(
                      key: ValueKey(op.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Theme.of(context).colorScheme.error,
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                      onDismissed: (_) => _delete(context, op),
                      child: OperationTile(
                        operation: op,
                        onTap: () => openEntry(context, existing: op),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _delete(BuildContext context, Operation op) {
    final store = StoreScope.read(context);
    store.deleteOperation(op.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${operationTitle(store, op)} supprimée'),
          persist: false,
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => store.restoreOperation(op.id),
          ),
        ),
      );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.amount, this.color);

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.mif.textSecondary),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatAmount(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}
