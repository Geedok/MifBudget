import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/operation.dart';
import '../models/savings_goal.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'goal_form_screen.dart';
import 'wallet_form_screen.dart';
import 'home_shell.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

/// Onglet Épargnes : le total des comptes épargne, puis chaque compte avec
/// ses objectifs (progression, Verser / Retirer) et sa part non répartie.
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final accounts = store.savingsWallets;
    final month = store.monthSummary(store.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Épargnes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (accounts.isEmpty)
            const _NoSavingsAccount()
          else ...[
            MifCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total épargné',
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Figure(
                        label: 'Mis de côté ce mois-ci',
                        value: month.saved == 0
                            ? '0'
                            : formatSigned(month.saved),
                      ),
                      _Figure(
                        label: 'Disponible (comptes courants)',
                        value: formatAmount(store.available),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            for (final w in accounts) _AccountSection(wallet: w),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => WalletFormScreen.open(
                context,
                initialRole: WalletRole.savings,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un compte épargne'),
            ),
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

/// Aucun compte épargne : expliquer et proposer d'en ajouter un.
class _NoSavingsAccount extends StatelessWidget {
  const _NoSavingsAccount();

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return MifCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajoutez votre compte épargne',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: mif.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Épargner, c'est virer de l'argent d'un compte courant vers un "
            'compte épargne. Ajoutez le compte où va votre épargne, puis vos '
            'objectifs (sûreté, construction…) : sur un même compte ou sur '
            'des comptes différents.',
            style: TextStyle(fontSize: 14, color: mif.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                WalletFormScreen.open(context, initialRole: WalletRole.savings),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un compte épargne'),
          ),
        ],
      ),
    );
  }
}

/// Un compte épargne : son solde, ses objectifs et la part non répartie.
class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final goals = store.walletGoals(wallet.id);
    final unallocated = store.unallocated(wallet.id);
    Widget suggestion(String name, String icon) => ActionChip(
      avatar: Icon(goalIcon(icon), size: 18),
      label: Text(name),
      onPressed: () => GoalFormScreen.open(
        context,
        suggestedName: name,
        suggestedIcon: icon,
        walletId: wallet.id,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
          child: Row(
            children: [
              Icon(walletIcon(wallet.type), size: 20, color: mif.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wallet.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: mif.text,
                  ),
                ),
              ),
              if (wallet.isPrivate)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.lock_outline,
                    size: 16,
                    semanticLabel: 'Privé',
                    color: mif.textSecondary,
                  ),
                ),
              Text(
                formatFcfa(store.walletBalance(wallet.id)),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: mif.text,
                ),
              ),
              IconButton(
                tooltip: 'Modifier le compte',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () =>
                    WalletFormScreen.open(context, existing: wallet),
              ),
            ],
          ),
        ),
        if (goals.isEmpty)
          MifCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Aucun objectif sur ce compte. Ajoutez-en un pour suivre "
                  'la progression vers une cible :',
                  style: TextStyle(fontSize: 14, color: mif.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    suggestion('Épargne de sûreté', 'surete'),
                    suggestion('Épargne de construction', 'construction'),
                    suggestion('Autre objectif', 'epargne'),
                  ],
                ),
                const SizedBox(height: 8),
                _MoveButtons(walletId: wallet.id),
              ],
            ),
          ),
        for (final (i, g) in goals.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          GoalCard(
            goal: g,
            showWallet: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g.id)),
            ),
          ),
        ],
        if (goals.length > 1 && unallocated != 0) ...[
          const SizedBox(height: 12),
          MifCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Non réparti',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: mif.text,
                        ),
                      ),
                      Text(
                        "Argent du compte qui n'est attribué à aucun objectif.",
                        style: TextStyle(
                          fontSize: 12,
                          color: mif.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatAmount(unallocated),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: mif.text,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (goals.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  GoalFormScreen.open(context, walletId: wallet.id),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un objectif sur ce compte'),
            ),
          ),
      ],
    );
  }
}

/// Verser / Retirer, depuis un compte épargne ou un objectif.
class _MoveButtons extends StatelessWidget {
  const _MoveButtons({required this.walletId, this.goalId, this.canWithdraw});

  final String walletId;
  final String? goalId;
  final bool? canWithdraw;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final withdraw = canWithdraw ?? store.walletBalance(walletId) > 0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: shape,
            ),
            onPressed: () => openEntry(
              context,
              initialType: OperationType.savingsDeposit,
              initialGoalId: goalId,
              initialWalletId: walletId,
            ),
            child: const Text('Verser'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: shape,
            ),
            onPressed: withdraw
                ? () => openEntry(
                    context,
                    initialType: OperationType.savingsWithdrawal,
                    initialGoalId: goalId,
                    initialWalletId: walletId,
                  )
                : null,
            child: const Text('Retirer'),
          ),
        ),
      ],
    );
  }
}

/// Carte d'une épargne : montant / cible, progression, conseils, et les
/// boutons Verser / Retirer.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.showWallet = true,
  });

  final SavingsGoal goal;
  final VoidCallback? onTap;

  /// Rappeler le compte épargne (inutile sous l'en-tête du compte).
  final bool showWallet;

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
    if (wallet != null && showWallet) notes.add('Sur ${wallet.name}');

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
              if (goal.walletId != null)
                _MoveButtons(
                  walletId: goal.walletId!,
                  goalId: goal.id,
                  canWithdraw: balance > 0,
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
                if (goal.startAmount != 0 &&
                    goal.walletId != null &&
                    store.walletGoals(goal.walletId!).length > 1)
                  ListTile(
                    leading: CategoryBadge(
                      category: null,
                      icon: goalIcon(goal.icon),
                      color: mif.green,
                    ),
                    title: const Text('Part de départ'),
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
                if (ops.isEmpty)
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
