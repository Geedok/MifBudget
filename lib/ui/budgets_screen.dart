import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'widgets/amount_field.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

/// Couleur, icône et libellé d'un état de budget (jamais la couleur seule).
({Color bar, Color text, IconData icon, String label}) statusStyle(
  BuildContext context,
  int spent,
  int limit,
) {
  final mif = context.mif;
  final ratio = limit == 0 ? 0.0 : spent / limit;
  return switch (budgetStatus(spent, limit)) {
    BudgetStatus.over => (
      bar: mif.statusOver,
      text: mif.statusOver,
      icon: Icons.error_outline,
      label: 'Dépassé',
    ),
    BudgetStatus.warning => (
      bar: mif.statusWarning,
      text: mif.statusWarningText,
      icon: Icons.warning_amber_rounded,
      label: formatPercent(ratio),
    ),
    BudgetStatus.ok => (
      bar: mif.statusOk,
      text: mif.text,
      icon: Icons.check_circle_outline,
      label: formatPercent(ratio),
    ),
  };
}

/// Onglet Budgets : plafonds du mois par catégorie, avec ce qui est déjà
/// dépensé.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final now = store.now();
    final month = _month ?? DateTime(now.year, now.month);
    final previous = DateTime(month.year, month.month - 1);
    final budgets = store.budgetsFor(month);
    final previousBudgets = store.budgetsFor(previous);
    final limitTotal = budgets.fold<int>(0, (s, b) => s + b.limit);
    final spentTotal = budgets.fold<int>(
      0,
      (s, b) => s + store.spentIn(month, b.categoryId),
    );
    final outside =
        store.monthSummary(month).expense -
        budgets.fold<int>(0, (s, b) => s + store.spentIn(month, b.categoryId));
    final isCurrent = month.year == now.year && month.month == now.month;
    final daysLeft = DateTime(month.year, month.month + 1, 0).day - now.day;

    Future<void> copyPrevious() async {
      final n = await store.copyPreviousBudgets(month);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'Aucun plafond à copier'
                : '$n plafond${n > 1 ? 's' : ''} copié${n > 1 ? 's' : ''} de ${monthName(previous)}',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          MonthSwitcher(
            month: month,
            now: now,
            monthsAhead: 1,
            onChanged: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: 4),
          if (budgets.isEmpty)
            MifCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Aucun budget pour ${monthName(month)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: mif.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fixez un plafond de dépenses par catégorie. '
                    "L'application propose un montant d'après vos 3 derniers "
                    'mois ; vous pouvez saisir le vôtre.',
                    style: TextStyle(fontSize: 14, color: mif.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => BudgetEditorScreen.open(context, month),
                    child: const Text('Définir les plafonds'),
                  ),
                  if (previousBudgets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: copyPrevious,
                      child: Text(
                        'Copier les plafonds de ${monthName(previous)}',
                      ),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            MifCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dépensé sur le budget du mois',
                    style: TextStyle(fontSize: 13, color: mif.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatAmount(spentTotal),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${formatFcfa(limitTotal)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: mif.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(color: mif.text),
                  ),
                  const SizedBox(height: 8),
                  ValueBar(
                    fraction: limitTotal == 0 ? 0 : spentTotal / limitTotal,
                    color: statusStyle(context, spentTotal, limitTotal).bar,
                    height: 10,
                    track: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      spentTotal > limitTotal
                          ? 'Dépassé de ${formatFcfa(spentTotal - limitTotal)}'
                          : 'Reste ${formatFcfa(limitTotal - spentTotal)}',
                      if (isCurrent)
                        daysLeft == 0
                            ? 'dernier jour du mois'
                            : '$daysLeft jour${daysLeft > 1 ? 's' : ''} avant la fin du mois',
                    ].join(' · '),
                    style: TextStyle(fontSize: 13, color: mif.textSecondary),
                  ),
                  if (outside > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Hors budget : ${formatFcfa(outside)} dans les autres catégories',
                        style: TextStyle(
                          fontSize: 13,
                          color: mif.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MifCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, b) in budgets.indexed) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    _BudgetRow(month: month, budget: b),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => BudgetEditorScreen.open(context, month),
                    child: const Text('Modifier les plafonds'),
                  ),
                ),
                if (previousBudgets.any(
                  (b) => store.budgetLimit(month, b.categoryId) == 0,
                )) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: copyPrevious,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Copier ${monthName(previous)}'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.month, required this.budget});

  final DateTime month;
  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final category = store.category(budget.categoryId);
    final spent = store.spentIn(month, budget.categoryId);
    final style = statusStyle(context, spent, budget.limit);
    final over = spent > budget.limit;
    return InkWell(
      onTap: () => BudgetEditorScreen.open(
        context,
        month,
        focusCategoryId: budget.categoryId,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryBadge(category: category, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category?.name ?? 'Catégorie supprimée',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: mif.text,
                    ),
                  ),
                ),
                Icon(style.icon, size: 16, color: style.text),
                const SizedBox(width: 4),
                Text(
                  style.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueBar(
              fraction: spent / budget.limit,
              color: style.bar,
              height: 8,
              track: true,
            ),
            const SizedBox(height: 6),
            Text(
              '${formatAmount(spent)} / ${formatAmount(budget.limit)} · '
              '${over ? '+${formatFcfa(spent - budget.limit)}' : 'reste ${formatFcfa(budget.limit - spent)}'}',
              style: TextStyle(fontSize: 12, color: mif.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saisie des plafonds du mois pour toutes les catégories de dépenses, avec
/// le montant proposé (moyenne des 3 derniers mois) sous chacune.
class BudgetEditorScreen extends StatefulWidget {
  const BudgetEditorScreen({
    super.key,
    required this.month,
    this.focusCategoryId,
  });

  final DateTime month;
  final String? focusCategoryId;

  static Future<void> open(
    BuildContext context,
    DateTime month, {
    String? focusCategoryId,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          BudgetEditorScreen(month: month, focusCategoryId: focusCategoryId),
    ),
  );

  @override
  State<BudgetEditorScreen> createState() => _BudgetEditorScreenState();
}

class _BudgetEditorScreenState extends State<BudgetEditorScreen> {
  final _controllers = <String, TextEditingController>{};
  late final List<Category> _categories;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context);
    _categories = store.topCategories(CategoryKind.expense);
    for (final c in _categories) {
      final limit = store.budgetLimit(widget.month, c.id);
      _controllers[c.id] = TextEditingController(
        text: limit == 0 ? '' : formatAmount(limit),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillSuggestions() {
    final store = StoreScope.read(context);
    var filled = 0;
    for (final c in _categories) {
      final controller = _controllers[c.id]!;
      if (controller.text.isNotEmpty) continue;
      final s = store.suggestedLimit(widget.month, c.id);
      if (s == null) continue;
      controller.text = formatAmount(s);
      filled++;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          filled == 0
              ? 'Aucune proposition : pas encore assez de dépenses saisies'
              : '$filled plafond${filled > 1 ? 's' : ''} proposé${filled > 1 ? 's' : ''}, à ajuster si besoin',
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await StoreScope.read(context).setBudgets(widget.month, {
      for (final c in _categories)
        c.id: parseAmount(_controllers[c.id]!.text) ?? 0,
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Plafonds de ${monthName(widget.month)}'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  Text(
                    "Laissez vide une catégorie sans budget. Les propositions "
                    'sont la moyenne de vos dépenses des 3 derniers mois.',
                    style: TextStyle(fontSize: 13, color: mif.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _fillSuggestions,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Proposer les plafonds'),
                    ),
                  ),
                  for (final c in _categories) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CategoryBadge(category: c, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: mif.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AmountField(
                      controller: _controllers[c.id]!,
                      label: 'Plafond',
                      autofocus: c.id == widget.focusCategoryId,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Text(
                        [
                          switch (store.suggestedLimit(widget.month, c.id)) {
                            null => 'Pas encore de proposition',
                            final s =>
                              'Proposé : ${formatFcfa(s)} (moyenne 3 mois)',
                          },
                          if (store.spentIn(widget.month, c.id) > 0)
                            'déjà dépensé ${formatFcfa(store.spentIn(widget.month, c.id))}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: mif.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: ListenableBuilder(
                listenable: Listenable.merge(_controllers.values.toList()),
                builder: (context, _) {
                  final total = _controllers.values.fold<int>(
                    0,
                    (s, c) => s + (parseAmount(c.text) ?? 0),
                  );
                  return FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      total == 0
                          ? 'Enregistrer'
                          : 'Enregistrer · total ${formatFcfa(total)}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
