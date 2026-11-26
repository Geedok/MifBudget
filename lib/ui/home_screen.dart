import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'settings_screen.dart';
import 'wallet_form_screen.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';
import 'widgets/income_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSeeAllOperations,
    required this.onOpenReport,
    required this.onOpenSavings,
  });

  final VoidCallback onSeeAllOperations;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenSavings;

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
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'MifBudget',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: mif.green,
                            ),
                          ),
                          TextSpan(text: ' · ${monthLabel(now)}'),
                        ],
                      ),
                      style: TextStyle(fontSize: 13, color: mif.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name.isEmpty ? greeting : '$greeting $name',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: mif.text,
                      ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: mif.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DefaultTextStyle(
              style: TextStyle(fontFamily: 'Inter', color: onGreen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disponible',
                    style: TextStyle(
                      fontSize: 13,
                      color: onGreen.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _Figure('Épargne', store.totalSaved, onGreen),
                      _Figure('Total', store.totalBalance, onGreen),
                      _Figure('Dépenses du mois', month.expense, onGreen),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _WalletTiles(),
          const SizedBox(height: 12),
          IncomeCard(onOpenReport: onOpenReport),
          const SizedBox(height: 12),
          _SavingsCard(onOpenSavings: onOpenSavings),
          const SizedBox(height: 12),
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
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
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
            'Épargne',
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
            const SizedBox(height: 4),
            Text(
              '${formatAmount(store.goalBalance(g.id))} sur ${formatFcfa(g.target)}',
              style: TextStyle(fontSize: 12, color: mif.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Comptes courants : trois tuiles côte à côte, ou une rangée qui défile
/// s'il y en a plus.
class _WalletTiles extends StatelessWidget {
  const _WalletTiles();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final wallets = store.currentWallets;
    Widget tile(Wallet w) => _WalletTile(wallet: w);
    if (wallets.length <= 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, w) in wallets.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tile(w)),
          ],
        ],
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: wallets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(width: 128, child: tile(wallets[i])),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final w = wallet;
    return Material(
      color: mif.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => WalletFormScreen.open(context, existing: w),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(walletIcon(w.type), size: 18, color: mif.textSecondary),
                  if (w.isPrivate) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      semanticLabel: 'Privé',
                      color: mif.textSecondary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                w.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: mif.textSecondary),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatAmount(store.walletBalance(w.id)),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: mif.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
