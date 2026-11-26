import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/category.dart';
import '../../models/operation.dart';
import '../../state/budget_store.dart';
import '../../theme.dart';
import '../home_shell.dart';
import 'charts.dart';
import 'common.dart';

/// Accueil : ce qui est entré ce mois-ci, d'où, et ce qui en a été dépensé.
class IncomeCard extends StatelessWidget {
  const IncomeCard({super.key, required this.onOpenReport});

  final VoidCallback onOpenReport;

  static const _maxSources = 3;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final now = store.now();
    final month = DateTime(now.year, now.month);
    final previous = DateTime(now.year, now.month - 1);
    final summary = store.monthSummary(month);
    final sources = store.totalsByCategory(month, CategoryKind.income);
    final delta = deltaLabel(
      summary.income,
      store.monthSummary(previous).income,
      previous,
    );

    return Material(
      color: mif.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenReport,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Revenus de ${monthName(month)}',
                trailing: Icon(Icons.chevron_right, color: mif.textSecondary),
              ),
              if (summary.income == 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Aucun revenu saisi en ${monthName(month)}.',
                  style: TextStyle(fontSize: 14, color: mif.textSecondary),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () =>
                      openEntry(context, initialType: OperationType.income),
                  icon: const Icon(Icons.add),
                  label: const Text('Saisir un revenu'),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  formatFcfa(summary.income),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: mif.text,
                  ),
                ),
                if (delta != null)
                  Text(
                    delta,
                    style: TextStyle(fontSize: 12, color: mif.textSecondary),
                  ),
                const SizedBox(height: 12),
                for (final s in sources.take(_maxSources))
                  _SourceLine(total: s, income: summary.income),
                if (sources.length > _maxSources)
                  Text(
                    '+ ${sources.length - _maxSources} autre(s) source(s)',
                    style: TextStyle(fontSize: 12, color: mif.textSecondary),
                  ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 12),
                SpentGauge(summary: summary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.total, required this.income});

  final CategoryTotal total;
  final int income;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total.category?.name ?? 'Sans catégorie',
                  style: TextStyle(fontSize: 14, color: mif.text),
                ),
              ),
              Text(
                formatAmount(total.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: mif.text,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  formatPercent(total.amount / income),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: mif.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ValueBar(
            fraction: total.amount / income,
            color: mif.chartIncome,
            height: 6,
            track: true,
          ),
        ],
      ),
    );
  }
}

/// « Dépensé : 190 000 FCFA, soit 29 % des revenus » avec sa jauge, et le
/// reste (ou le dépassement).
class SpentGauge extends StatelessWidget {
  const SpentGauge({super.key, required this.summary, this.showRest = true});

  final MonthSummary summary;

  /// Afficher la ligne « Reste » (inutile quand le reste est déjà affiché).
  final bool showRest;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final over = summary.expense > summary.income;
    final style = TextStyle(fontSize: 13, color: mif.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Dépensé : '),
              TextSpan(
                text: formatFcfa(summary.expense),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (summary.income > 0)
                TextSpan(
                  text:
                      ', soit ${formatPercent(summary.spentRatio)} des revenus',
                ),
            ],
          ),
          style: style,
        ),
        const SizedBox(height: 6),
        ValueBar(
          fraction: summary.spentRatio,
          color: mif.chartExpense,
          height: 10,
          track: true,
        ),
        if (over || showRest) const SizedBox(height: 6),
        if (over)
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: mif.terracotta),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Les dépenses dépassent les revenus de ${formatFcfa(-summary.balance)}',
                  style: style.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          )
        else if (showRest)
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Reste : '),
                TextSpan(
                  text: formatFcfa(summary.balance),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: style,
          ),
      ],
    );
  }
}
