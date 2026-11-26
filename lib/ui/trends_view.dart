import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/projection.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

/// Tendances : moyennes et capacité d'épargne, 12 mois de revenus, dépenses
/// et épargne, dépenses moyennes par catégorie, et projections des objectifs
/// et des projets.
class TrendsView extends StatelessWidget {
  const TrendsView({super.key, required this.onOpenMonth});

  /// Ouvre le bilan d'un mois touché dans un graphique.
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final now = store.now();
    final avg = store.averages();
    final months = store.lastCompleteMonths(3);
    // 12 mois au plus, à partir du premier mois saisi.
    final start = store.firstActivityMonth;
    final span = start == null
        ? 1
        : (monthsBetween(start, now) + 1).clamp(1, 12).toInt();
    final year = store.recentMonths(now, count: span);
    final trends = store.categoryTrends(CategoryKind.expense).take(8).toList();
    final goals = store.goals;
    final projects = store.openProjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: "Capacité d'épargne",
          child: avg.months == 0
              ? Text(
                  'Les moyennes apparaîtront après un premier mois complet '
                  'de saisie.',
                  style: TextStyle(fontSize: 14, color: mif.textSecondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moyenne par mois, ${_period(months)}',
                      style: TextStyle(fontSize: 12, color: mif.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Figure('Revenus', formatAmount(avg.income)),
                        _Figure('Dépenses', formatAmount(avg.expense)),
                        _Figure('Épargne', formatAmount(avg.saved)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Sentence(
                      lead: 'Vous mettez de côté ',
                      strong: '${formatFcfa(avg.saved)} par mois',
                      tail: avg.income > 0
                          ? ', soit ${formatPercent(avg.savingsRate)} des revenus.'
                          : '.',
                    ),
                    const SizedBox(height: 4),
                    _Sentence(
                      lead: 'Après les dépenses, il reste en moyenne ',
                      strong: formatFcfa(avg.leftover),
                      tail: avg.leftover > avg.saved
                          ? ' : ${formatFcfa(avg.leftover - avg.saved)} de plus '
                                'pourraient aller à l\'épargne.'
                          : '.',
                    ),
                  ],
                ),
        ),
        _Section(
          title: span < 12
              ? 'Revenus et dépenses mois par mois'
              : 'Revenus et dépenses sur 12 mois',
          child: IncomeExpenseMonths(
            months: year,
            selected: now,
            onSelected: onOpenMonth,
          ),
        ),
        _Section(
          title: 'Épargne mois par mois',
          child: _SavedMonths(months: year, onSelected: onOpenMonth),
        ),
        if (trends.isNotEmpty)
          _Section(
            title: 'Dépenses moyennes par catégorie',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Par mois, ${_period(months)}, comparé aux 3 mois d\'avant',
                  style: TextStyle(fontSize: 12, color: mif.textSecondary),
                ),
                const SizedBox(height: 4),
                for (final t in trends)
                  _TrendLine(trend: t, max: trends.first.recent),
              ],
            ),
          ),
        if (goals.isNotEmpty || projects.isNotEmpty)
          _Section(
            title: 'Projections',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final g in goals) _GoalProjection(goal: g),
                for (final p in projects)
                  _ProjectionLine(
                    title: p.name,
                    lines: [
                      if (store.projectToFund(p) == 0)
                        'Financé'
                      else ...[
                        'Reste à financer : ${formatFcfa(store.projectToFund(p))}',
                        if (p.goalId == null)
                          "Rattachez-le à un objectif d'épargne pour estimer une date"
                        else if (store.projectFundingDate(p) == null)
                          "Son objectif d'épargne n'avance pas au rythme actuel"
                        else
                          'Financé vers ${monthLabel(store.projectFundingDate(p)!).toLowerCase()}'
                              '${_versus(store.projectFundingDate(p)!, p.targetDate)}',
                      ],
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  'Estimations au rythme des 3 derniers mois complets.',
                  style: TextStyle(fontSize: 12, color: mif.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// « d'août à octobre 2026 ».
String _period(List<DateTime> months) {
  if (months.isEmpty) return '';
  if (months.length == 1) return 'en ${monthLabel(months.first).toLowerCase()}';
  final first = monthName(months.first);
  final last = monthLabel(months.last).toLowerCase();
  final de = RegExp('^[aeiouéâ]').hasMatch(first) ? "d'" : 'de ';
  return '$de$first à $last';
}

/// « (2 mois avant la date cible) », « (5 mois après la date cible) ».
String _versus(DateTime estimate, DateTime? target) {
  if (target == null) return '';
  final diff = monthsBetween(estimate, target);
  if (diff == 0) return ' (à la date cible)';
  return diff > 0
      ? ' ($diff mois avant la date cible)'
      : ' (${-diff} mois après la date cible)';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: SectionTitle(title),
      ),
      MifCard(child: child),
    ],
  );
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label;
  final String value;

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
            value,
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

class _Sentence extends StatelessWidget {
  const _Sentence({required this.lead, required this.strong, this.tail = ''});

  final String lead;
  final String strong;
  final String tail;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: lead),
        TextSpan(
          text: strong,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        TextSpan(text: tail),
      ],
    ),
    style: TextStyle(fontSize: 14, color: context.mif.text),
  );
}

/// Épargne de chaque mois : une barre par mois (une seule série), le montant
/// écrit à droite.
class _SavedMonths extends StatelessWidget {
  const _SavedMonths({required this.months, required this.onSelected});

  final List<MonthSummary> months;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final max = months.fold<int>(0, (m, s) => s.saved > m ? s.saved : m);
    return Column(
      children: [
        for (final m in months)
          Semantics(
            label: '${monthLabel(m.month!)} : épargne ${formatFcfa(m.saved)}',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelected(m.month!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        shortMonth(m.month!),
                        style: TextStyle(
                          fontSize: 12,
                          color: mif.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ValueBar(
                        fraction: max == 0 || m.saved <= 0 ? 0 : m.saved / max,
                        color: mif.green,
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        m.saved == 0 ? '0' : formatSigned(m.saved),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: mif.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.trend, required this.max});

  final CategoryTrend trend;
  final int max;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final change = trend.change;
    final changeText = change == null
        ? 'nouveau'
        : change.abs() < 0.005
        ? 'stable'
        : '${change > 0 ? '+' : '−'}${formatPercent(change.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              CategoryBadge(category: trend.category, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trend.category?.name ?? 'Sans catégorie',
                  style: TextStyle(fontSize: 14, color: mif.text),
                ),
              ),
              Text(
                formatAmount(trend.recent),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: mif.text,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  changeText,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: mif.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: ValueBar(
              fraction: max == 0 ? 0 : trend.recent / max,
              color: mif.chartExpense,
              height: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalProjection extends StatelessWidget {
  const _GoalProjection({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final remaining = goal.target - store.goalBalance(goal.id);
    final pace = store.goalPace(goal);
    final date = store.goalReachDate(goal);
    return _ProjectionLine(
      title: goal.name,
      lines: [
        if (remaining <= 0)
          'Objectif atteint'
        else ...[
          'Reste ${formatFcfa(remaining)} · rythme ${pace > 0 ? '${formatFcfa(pace)} par mois' : 'nul'}',
          if (date == null)
            "N'avance pas au rythme actuel"
          else
            'Atteint vers ${monthLabel(date).toLowerCase()}'
                '${_versus(date, goal.targetDate)}',
        ],
      ],
    );
  }
}

class _ProjectionLine extends StatelessWidget {
  const _ProjectionLine({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: mif.text,
            ),
          ),
          for (final l in lines)
            Text(l, style: TextStyle(fontSize: 13, color: mif.textSecondary)),
        ],
      ),
    );
  }
}
