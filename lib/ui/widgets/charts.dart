import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../state/budget_store.dart';
import '../../theme.dart';

/// « ‹ Novembre 2026 › » : change de mois, sans aller après le mois en cours.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.now,
    required this.onChanged,
  });

  final DateTime month;
  final DateTime now;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final isCurrent = month.year == now.year && month.month == now.month;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Mois précédent',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        SizedBox(
          width: 170,
          child: Text(
            monthLabel(month),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.mif.text,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Mois suivant',
          icon: const Icon(Icons.chevron_right),
          onPressed: isCurrent
              ? null
              : () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}

/// Barre horizontale fine : extrémité de la valeur arrondie (4 px), départ
/// droit. Avec [track], un fond montre le total (jauge).
class ValueBar extends StatelessWidget {
  const ValueBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 8,
    this.track = false,
  });

  final double fraction;
  final Color color;
  final double height;
  final bool track;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    const r = Radius.circular(4);
    return Container(
      height: height,
      decoration: track
          ? BoxDecoration(
              color: context.mif.track,
              borderRadius: const BorderRadius.all(r),
            )
          : null,
      alignment: Alignment.centerLeft,
      child: f == 0
          ? null
          : FractionallySizedBox(
              widthFactor: f,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: track
                      ? const BorderRadius.all(r)
                      : const BorderRadius.horizontal(right: r),
                ),
              ),
            ),
    );
  }
}

class LegendItem extends StatelessWidget {
  const LegendItem({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: context.mif.textSecondary),
      ),
    ],
  );
}

/// Revenus et dépenses mois par mois : deux barres par mois, valeurs écrites
/// à droite. Toucher un mois le sélectionne.
class IncomeExpenseMonths extends StatelessWidget {
  const IncomeExpenseMonths({
    super.key,
    required this.months,
    required this.selected,
    this.onSelected,
  });

  final List<MonthSummary> months;
  final DateTime selected;
  final ValueChanged<DateTime>? onSelected;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final max = months.fold<int>(
      0,
      (m, s) => [m, s.income, s.expense].reduce((a, b) => a > b ? a : b),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            LegendItem(color: mif.chartIncome, label: 'Revenus'),
            LegendItem(color: mif.chartExpense, label: 'Dépenses'),
          ],
        ),
        const SizedBox(height: 8),
        for (final m in months)
          _MonthRow(
            summary: m,
            max: max,
            selected:
                m.month!.year == selected.year &&
                m.month!.month == selected.month,
            onTap: onSelected == null ? null : () => onSelected!(m.month!),
          ),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.summary,
    required this.max,
    required this.selected,
    this.onTap,
  });

  final MonthSummary summary;
  final int max;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final weight = selected ? FontWeight.w700 : FontWeight.w500;
    double f(int v) => max == 0 ? 0 : v / max;
    Widget value(int v) => SizedBox(
      width: 84,
      child: Text(
        formatAmount(v),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: weight,
          color: mif.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Semantics(
      label:
          '${monthLabel(summary.month!)} : revenus ${formatFcfa(summary.income)}, dépenses ${formatFcfa(summary.expense)}',
      selected: selected,
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: selected
              ? BoxDecoration(
                  color: mif.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  shortMonth(summary.month!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: weight,
                    color: selected ? mif.text : mif.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    ValueBar(
                      fraction: f(summary.income),
                      color: mif.chartIncome,
                    ),
                    const SizedBox(height: 2),
                    ValueBar(
                      fraction: f(summary.expense),
                      color: mif.chartExpense,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [value(summary.income), value(summary.expense)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
