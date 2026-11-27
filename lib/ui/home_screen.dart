import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/budget.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'budgets_screen.dart';
import 'personal_money.dart';
import 'recurrences_screen.dart';
import 'settings_screen.dart';
import 'wallet_form_screen.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSeeAllOperations,
    required this.onOpenReport,
    required this.onOpenSavings,
    required this.onOpenBudgets,
  });

  final VoidCallback onSeeAllOperations;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenSavings;
  final VoidCallback onOpenBudgets;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final now = store.now();
    final month = store.monthSummary(now);
    final recent = store.operations.take(5).toList();
    final name = store.settings.memberName;
    final greeting = now.hour < 18 ? 'Bonjour' : 'Bonsoir';
    final onGreen = Theme.of(context).colorScheme.onPrimary;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? greeting : '$greeting $name',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: mif.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthLabel(now),
                      style: TextStyle(fontSize: 13, color: mif.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Réglages',
                style: IconButton.styleFrom(
                  backgroundColor: mif.card,
                  side: BorderSide(color: mif.border),
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 1. Ce que j'ai à faire (seulement s'il y a quelque chose).
          const RecurringCard(showUpcoming: false),
          // 2. Ce mois-ci : l'argent disponible, entré, dépensé, reste.
          _MonthCard(
            summary: month,
            onOpenReport: onOpenReport,
            onGreen: onGreen,
          ),
          const SizedBox(height: 12),
          // 3. Les budgets en alerte.
          _BudgetAlerts(onOpenBudgets: onOpenBudgets),
          const PersonalMoneyCard(),
          _SavingsCard(onOpenSavings: onOpenSavings),
          const SizedBox(height: 12),
          // 4. Les dernières opérations.
          MifCard(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
                  child: SectionTitle(
                    'Dernières opérations',
                    trailing: recent.isEmpty
                        ? null
                        : TextButton(
                            onPressed: onSeeAllOperations,
                            child: const Text('Voir tout'),
                          ),
                  ),
                ),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Aucune opération pour l\'instant. Touchez + pour saisir votre première dépense.',
                      style: TextStyle(fontSize: 14, color: mif.textSecondary),
                    ),
                  ),
                for (final op in recent)
                  OperationTile(
                    operation: op,
                    showDate: true,
                    onTap: () => openEntry(context, existing: op),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grande carte verte : l'argent disponible, puis ce qui est entré, dépensé
/// et ce qui reste ce mois-ci. Toucher ouvre le bilan ; « Mes comptes »
/// détaille les portefeuilles.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.summary,
    required this.onOpenReport,
    required this.onGreen,
  });

  final MonthSummary summary;
  final VoidCallback onOpenReport;
  final Color onGreen;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final soft = onGreen.withValues(alpha: 0.85);
    return Material(
      color: mif.green,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle(
        style: TextStyle(fontFamily: 'Inter', color: onGreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpenReport,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Argent disponible',
                      style: TextStyle(fontSize: 13, color: soft),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatFcfa(store.available),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Figure('Entré ce mois', summary.income, onGreen),
                        _Figure('Dépensé', summary.expense, onGreen),
                        _Figure('Reste', summary.balance, onGreen),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ValueBar(
                      fraction: summary.spentRatio,
                      color: onGreen,
                      height: 6,
                      track: true,
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: onGreen.withValues(alpha: 0.2)),
            InkWell(
              onTap: () => showWalletsSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: soft,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mes comptes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: onGreen,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: soft),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des portefeuilles et de leur solde, avec « Ajouter ».
Future<void> showWalletsSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _WalletsSheet(),
);

class _WalletsSheet extends StatelessWidget {
  const _WalletsSheet();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final current = store.householdCurrentWallets;
    final savings = store.savingsWallets;
    final personal = store.personalWallets;
    Widget header(String text, int total) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: mif.textSecondary,
              ),
            ),
          ),
          Text(
            formatAmount(total),
            style: TextStyle(fontSize: 13, color: mif.textSecondary),
          ),
        ],
      ),
    );
    Widget tile(Wallet w) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(walletIcon(w.type)),
      title: Row(
        children: [
          Flexible(child: Text(w.name)),
          if (w.isPrivate) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.lock_outline,
              size: 16,
              semanticLabel: 'Privé',
              color: mif.textSecondary,
            ),
          ],
        ],
      ),
      trailing: Text(
        formatAmount(store.walletBalance(w.id)),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: mif.text,
        ),
      ),
      onTap: () => WalletFormScreen.open(context, existing: w),
    );
    int sum(List<Wallet> ws) =>
        ws.fold(0, (t, w) => t + store.walletBalance(w.id));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Mes comptes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: mif.text,
              ),
            ),
          ),
          header('Argent de tous les jours', sum(current)),
          for (final w in current) tile(w),
          if (savings.isNotEmpty) ...[
            header('Épargne', sum(savings)),
            for (final w in savings) tile(w),
          ],
          if (personal.isNotEmpty) ...[
            header('Mon argent personnel', sum(personal)),
            for (final w in personal) tile(w),
          ],
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(Icons.add, color: mif.green),
            title: Text(
              'Ajouter un portefeuille',
              style: TextStyle(color: mif.green),
            ),
            onTap: () => WalletFormScreen.open(context),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.amount, this.color);

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatAmount(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Accueil : progression de chaque épargne.
class _SavingsCard extends StatelessWidget {
  const _SavingsCard({required this.onOpenSavings});

  final VoidCallback onOpenSavings;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final accounts = store.savingsWallets;
    final goals = store.goals;
    return MifCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            accounts.isEmpty
                ? 'Épargne'
                : 'Épargne · ${formatAmount(store.totalSaved)}',
            trailing: TextButton(
              onPressed: onOpenSavings,
              child: Text(accounts.isEmpty ? 'Ajouter' : 'Voir tout'),
            ),
          ),
          if (accounts.isEmpty)
            Text(
              "Aucun compte épargne pour l'instant. Ajoutez le compte où va "
              "votre épargne, puis vos objectifs (sûreté, construction…).",
              style: TextStyle(fontSize: 14, color: mif.textSecondary),
            ),
          // Comptes épargne sans objectif : leur solde seulement.
          for (final w in accounts.where(
            (w) => store.walletGoals(w.id).isEmpty,
          ))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      w.name,
                      style: TextStyle(fontSize: 14, color: mif.text),
                    ),
                  ),
                  Text(
                    formatAmount(store.walletBalance(w.id)),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: mif.text,
                    ),
                  ),
                ],
              ),
            ),
          for (final g in goals) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: mif.text),
                  ),
                ),
                Text(
                  formatPercent(
                    g.target == 0 ? 0 : store.goalBalance(g.id) / g.target,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mif.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ValueBar(
              fraction: g.target == 0 ? 0 : store.goalBalance(g.id) / g.target,
              color: mif.green,
              height: 8,
              track: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Accueil : budgets du mois à 80 % ou plus (rien s'il n'y en a pas).
class _BudgetAlerts extends StatelessWidget {
  const _BudgetAlerts({required this.onOpenBudgets});

  final VoidCallback onOpenBudgets;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final month = store.now();
    final alerts =
        [
          for (final b in store.budgetsFor(month))
            if (budgetStatus(store.spentIn(month, b.categoryId), b.limit) !=
                BudgetStatus.ok)
              b,
        ]..sort(
          (a, b) => (store.spentIn(month, b.categoryId) / b.limit).compareTo(
            store.spentIn(month, a.categoryId) / a.limit,
          ),
        );
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MifCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'Budgets à surveiller',
              trailing: TextButton(
                onPressed: onOpenBudgets,
                child: const Text('Voir tout'),
              ),
            ),
            for (final b in alerts.take(3)) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final spent = store.spentIn(month, b.categoryId);
                  final style = statusStyle(context, spent, b.limit);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              store.category(b.categoryId)?.name ?? '',
                              style: TextStyle(fontSize: 14, color: mif.text),
                            ),
                          ),
                          Icon(style.icon, size: 16, color: style.text),
                          const SizedBox(width: 4),
                          Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: style.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ValueBar(
                        fraction: spent / b.limit,
                        color: style.bar,
                        height: 6,
                        track: true,
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
