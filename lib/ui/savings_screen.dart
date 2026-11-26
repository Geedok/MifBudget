import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/operation.dart';
import '../models/savings_goal.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'goal_form_screen.dart';
import 'home_shell.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

/// Onglet Épargnes : total mis de côté, puis une carte par épargne avec sa
/// progression et les boutons Verser / Retirer.
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final goals = store.goals;
    final now = store.now();
    final month = store.monthSummary(now);
    final totalTarget = goals.fold(0, (s, g) => s + g.target);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Épargnes'),
        actions: [
          TextButton.icon(
            onPressed: () => GoalFormScreen.open(context),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (goals.isEmpty)
            const _EmptySavings()
          else ...[
            MifCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mis de côté',
                    style: TextStyle(fontSize: 13, color: mif.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatFcfa(store.totalSaved),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: mif.text,
                    ),
                  ),
                  if (totalTarget > 0) ...[
                    Text(
                      'sur des cibles de ${formatFcfa(totalTarget)}',
                      style: TextStyle(fontSize: 13, color: mif.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ValueBar(
                      fraction: store.totalSaved / totalTarget,
                      color: mif.green,
                      height: 8,
                      track: true,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _Figure(
                        label: 'Ce mois-ci',
                        value: month.saved == 0
                            ? '0'
                            : formatSigned(month.saved),
                      ),
                      _Figure(
                        label: 'Disponible hors épargne',
                        value: formatAmount(store.available),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            for (final g in goals) ...[
              const SizedBox(height: 12),
              GoalCard(
                goal: g,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GoalDetailScreen(goalId: g.id),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

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
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.mif.text,
          ),
        ),
      ],
    ),
  );
}

/// Premier passage : proposer les deux épargnes prévues.
class _EmptySavings extends StatelessWidget {
  const _EmptySavings();

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    Widget suggestion(String name, String icon) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => GoalFormScreen.open(
          context,
          suggestedName: name,
          suggestedIcon: icon,
        ),
        icon: Icon(goalIcon(icon)),
        label: Text(name),
      ),
    );
    return MifCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Créez vos épargnes',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: mif.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Une épargne met de l'argent de côté sans le sortir du portefeuille : "
            "il n'est simplement plus compté dans le disponible. "
            'Donnez-lui un montant cible et, si vous voulez, une date.',
            style: TextStyle(fontSize: 14, color: mif.textSecondary),
          ),
          const SizedBox(height: 8),
          suggestion('Épargne de sûreté', 'surete'),
          suggestion('Épargne de construction', 'construction'),
          suggestion('Autre épargne', 'epargne'),
        ],
      ),
    );
  }
}

/// Carte d'une épargne : montant / cible, progression, conseils, et les
/// boutons Verser / Retirer.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap});

  final SavingsGoal goal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final balance = store.goalBalance(goal.id);
    final ratio = goal.target == 0 ? 0.0 : balance / goal.target;
    final reached = goal.target > 0 && balance >= goal.target;
    final notes = <String>[];
    if (!reached && goal.target > 0) {
      notes.add('Il reste ${formatFcfa(goal.target - balance)}');
    }
    final date = goal.targetDate;
    if (date != null && !reached) {
      final t = store.now();
      final past = date.year * 12 + date.month < t.year * 12 + t.month;
      final perMonth = store.monthlyNeeded(goal);
      notes.add(
        past
            ? 'Date cible dépassée (${monthLabel(date).toLowerCase()})'
            : 'Date cible ${monthLabel(date).toLowerCase()}'
                  '${perMonth == null ? '' : ' · ${formatFcfa(perMonth)} par mois'}',
      );
    }
    if (goal.icon == 'surete') {
      final avg = store.averageMonthlyExpense();
      if (avg > 0 && balance > 0) {
        final months = (balance / avg).toStringAsFixed(1).replaceAll('.', ',');
        notes.add('Couvre environ $months mois de dépenses');
      }
    }
    final wallet = store.wallet(goal.walletId);
    if (wallet != null) notes.add('Sur ${wallet.name}');

    return Material(
      color: mif.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryBadge(
                    category: null,
                    icon: goalIcon(goal.icon),
                    color: mif.green,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: mif.text,
                      ),
                    ),
                  ),
                  Text(
                    formatPercent(ratio),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: mif.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatAmount(balance),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${formatFcfa(goal.target)}',
                      style: TextStyle(fontSize: 14, color: mif.textSecondary),
                    ),
                  ],
                ),
                style: TextStyle(color: mif.text),
              ),
              const SizedBox(height: 8),
              ValueBar(
                fraction: ratio,
                color: mif.green,
                height: 10,
                track: true,
              ),
              const SizedBox(height: 8),
              if (reached)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: mif.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Objectif atteint',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mif.text,
                      ),
                    ),
                  ],
                ),
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    n,
                    style: TextStyle(fontSize: 13, color: mif.textSecondary),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => openEntry(
                        context,
                        initialType: OperationType.savingsDeposit,
                        initialGoalId: goal.id,
                      ),
                      child: const Text('Verser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: balance <= 0
                          ? null
                          : () => openEntry(
                              context,
                              initialType: OperationType.savingsWithdrawal,
                              initialGoalId: goal.id,
                            ),
                      child: const Text('Retirer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Détail d'une épargne : sa carte et l'historique des versements et
/// retraits.
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final goal = store.goal(goalId);
    if (goal == null) return const Scaffold();
    final ops = store.goalOperations(goalId);
    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final result = await GoalFormScreen.open(context, existing: goal);
              if (result != null && result.archived) navigator.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          GoalCard(goal: goal),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: SectionTitle('Historique'),
          ),
          MifCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final op in ops)
                  OperationTile(
                    operation: op,
                    showDate: true,
                    onTap: () => openEntry(context, existing: op),
                  ),
                if (goal.startAmount > 0)
                  ListTile(
                    leading: CategoryBadge(
                      category: null,
                      icon: goalIcon(goal.icon),
                      color: mif.green,
                    ),
                    title: const Text('Montant de départ'),
                    subtitle: Text(
                      'À la création, ${dayLabel(goal.createdAt, now: store.now()).toLowerCase()}',
                    ),
                    trailing: Text(
                      formatAmount(goal.startAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: mif.textSecondary,
                      ),
                    ),
                  ),
                if (ops.isEmpty && goal.startAmount == 0)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aucun versement pour le moment.',
                      style: TextStyle(fontSize: 14, color: mif.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
