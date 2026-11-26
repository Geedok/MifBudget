import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';
import 'trends_view.dart';
import 'widgets/income_card.dart';

/// Bilan d'un mois : revenus par source, comparaison avec les dépenses et
/// avec les mois précédents.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime? _month;
  bool _trends = false;
  static const _maxExpenseCategories = 6;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = store.now();
    final month = _month ?? DateTime(now.year, now.month);
    final previous = DateTime(month.year, month.month - 1);
    final summary = store.monthSummary(month);
    final incomes = store.totalsByCategory(month, CategoryKind.income);
    final previousIncomes = {
      for (final t in store.totalsByCategory(previous, CategoryKind.income))
        t.category?.id: t.amount,
    };
    final expenses = store.totalsByCategory(month, CategoryKind.expense);
    final incomeOps = store
        .operationsInMonth(month)
        .where((o) => o.type == OperationType.income)
        .toList();

    void setMonth(DateTime m) => setState(() => _month = m);

    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Bilan du mois')),
              ButtonSegment(value: true, label: Text('Tendances')),
            ],
            selected: {_trends},
            onSelectionChanged: (v) => setState(() => _trends = v.first),
          ),
          const SizedBox(height: 8),
          if (_trends)
            TrendsView(
              onOpenMonth: (m) => setState(() {
                _month = m;
                _trends = false;
              }),
            )
          else
            ..._monthView(
              context,
              store,
              month,
              now,
              summary,
              incomes,
              previousIncomes,
              previous,
              expenses,
              incomeOps,
              setMonth,
            ),
        ],
      ),
    );
  }

  List<Widget> _monthView(
    BuildContext context,
    BudgetStore store,
    DateTime month,
    DateTime now,
    MonthSummary summary,
    List<CategoryTotal> incomes,
    Map<String?, int> previousIncomes,
    DateTime previous,
    List<CategoryTotal> expenses,
    List<Operation> incomeOps,
    ValueChanged<DateTime> setMonth,
  ) {
    final mif = context.mif;
    return [
      MonthSwitcher(month: month, now: now, onChanged: setMonth),
      const SizedBox(height: 4),
      MifCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Figure('Revenus', summary.income),
                _Figure('Dépenses', summary.expense),
                _Figure('Reste', summary.balance),
              ],
            ),
            if (summary.income > 0 || summary.expense > 0) ...[
              const SizedBox(height: 16),
              SpentGauge(summary: summary, showRest: false),
            ],
            if (summary.saved != 0) ...[
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: summary.saved > 0
                          ? 'Mis de côté ce mois-ci : '
                          : "Retiré de l'épargne ce mois-ci : ",
                    ),
                    TextSpan(
                      text: formatFcfa(summary.saved.abs()),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 13, color: mif.text),
              ),
            ],
          ],
        ),
      ),
      _Section(
        title: 'Revenus par source',
        child: incomes.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aucun revenu en ${monthName(month)}.',
                    style: TextStyle(fontSize: 14, color: mif.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        openEntry(context, initialType: OperationType.income),
                    icon: const Icon(Icons.add),
                    label: const Text('Saisir un revenu'),
                  ),
                ],
              )
            : Column(
                children: [
                  for (final t in incomes)
                    _CategoryLine(
                      total: t,
                      of: summary.income,
                      color: mif.chartIncome,
                      note: deltaLabel(
                        t.amount,
                        previousIncomes[t.category?.id] ?? 0,
                        previous,
                      ),
                      showSubs: true,
                    ),
                ],
              ),
      ),
      _Section(
        title: 'Revenus et dépenses sur 6 mois',
        child: IncomeExpenseMonths(
          months: store.recentMonths(month),
          selected: month,
          onSelected: setMonth,
        ),
      ),
      if (expenses.isNotEmpty)
        _Section(
          title: 'Dépenses par catégorie',
          child: Column(
            children: [
              for (final t in expenses.take(_maxExpenseCategories))
                _CategoryLine(
                  total: t,
                  of: summary.expense,
                  color: mif.chartExpense,
                ),
              if (expenses.length > _maxExpenseCategories)
                _OthersLine(
                  amount: expenses
                      .skip(_maxExpenseCategories)
                      .fold(0, (s, t) => s + t.amount),
                  count: expenses.length - _maxExpenseCategories,
                  of: summary.expense,
                ),
            ],
          ),
        ),
      if (incomeOps.isNotEmpty)
        _Section(
          title: 'Détail des revenus',
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              for (final op in incomeOps)
                OperationTile(
                  operation: op,
                  showDate: true,
                  onTap: () => openEntry(context, existing: op),
                ),
            ],
          ),
        ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.padding});

  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: SectionTitle(title),
      ),
      MifCard(padding: padding, child: child),
    ],
  );
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.amount);

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.mif.textSecondary),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatAmount(amount),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.mif.text,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Une catégorie : montant, part du total, jauge, et éventuellement le
/// détail par sous-catégorie.
class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.total,
    required this.of,
    required this.color,
    this.note,
    this.showSubs = false,
  });

  final CategoryTotal total;
  final int of;
  final Color color;
  final String? note;
  final bool showSubs;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final top = total.category;
    // Le détail n'a d'intérêt que s'il ajoute une information.
    final subs =
        showSubs &&
            (total.subs.length > 1 ||
                (total.subs.length == 1 &&
                    total.subs.first.category?.id != top?.id))
        ? total.subs
        : const <CategoryTotal>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(category: top, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top?.name ?? 'Sans catégorie',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: mif.text,
                      ),
                    ),
                    if (note != null)
                      Text(
                        note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: mif.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(total.amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: mif.text,
                    ),
                  ),
                  Text(
                    formatPercent(of == 0 ? 0 : total.amount / of),
                    style: TextStyle(fontSize: 12, color: mif.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ValueBar(
            fraction: of == 0 ? 0 : total.amount / of,
            color: color,
            height: 6,
            track: true,
          ),
          for (final s in subs)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.category?.id == top?.id
                          ? 'Sans précision'
                          : s.category?.name ?? 'Sans catégorie',
                      style: TextStyle(fontSize: 13, color: mif.textSecondary),
                    ),
                  ),
                  Text(
                    formatAmount(s.amount),
                    style: TextStyle(fontSize: 13, color: mif.text),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OthersLine extends StatelessWidget {
  const _OthersLine({
    required this.amount,
    required this.count,
    required this.of,
  });

  final int amount;
  final int count;
  final int of;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count autre(s) catégorie(s)',
              style: TextStyle(fontSize: 13, color: mif.textSecondary),
            ),
          ),
          Text(
            '${formatAmount(amount)} · ${formatPercent(of == 0 ? 0 : amount / of)}',
            style: TextStyle(fontSize: 13, color: mif.text),
          ),
        ],
      ),
    );
  }
}
