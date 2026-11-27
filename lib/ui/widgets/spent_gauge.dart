import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../state/budget_store.dart';
import '../../theme.dart';
import 'charts.dart';

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
