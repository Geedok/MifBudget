import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'settings_screen.dart';
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
                  if (store.available < 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Plus d\'argent mis de côté que dans les portefeuilles : '
                      'vérifiez les soldes de départ dans les Réglages.',
                      style: TextStyle(
                        fontSize: 12,
                        color: onGreen.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _Figure('Portefeuilles', store.totalBalance, onGreen),
                      _Figure('Mis de côté', store.totalSaved, onGreen),
                      _Figure('Dépenses du mois', month.expense, onGreen),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, w) in store.wallets.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: MifCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          walletIcon(w.type),
                          size: 18,
                          color: mif.textSecondary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          w.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: mif.textSecondary,
                          ),
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
              ],
            ],
          ),
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
    final goals = store.goals;
    return MifCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Épargnes',
            trailing: TextButton(
              onPressed: onOpenSavings,
              child: Text(goals.isEmpty ? 'Créer' : 'Voir tout'),
            ),
          ),
          if (goals.isEmpty)
            Text(
              "Aucune épargne pour l'instant. Créez l'épargne de sûreté et l'épargne de construction.",
              style: TextStyle(fontSize: 14, color: mif.textSecondary),
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
