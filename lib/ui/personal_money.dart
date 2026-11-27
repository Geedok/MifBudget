import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/projection.dart';
import '../models/operation.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'widgets/amount_field.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

/// Accueil : ce qui reste d'argent personnel (visible par soi seul).
class PersonalMoneyCard extends StatelessWidget {
  const PersonalMoneyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    if (!store.settings.personalMoney && store.personalWallets.isEmpty) {
      return const SizedBox.shrink();
    }
    final month = store.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: mif.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => PersonalMoneyScreen.open(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: mif.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mon argent personnel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: mif.text,
                        ),
                      ),
                      Text(
                        'Dépensé ce mois : ${formatFcfa(store.personalSpent(month))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: mif.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatAmount(store.personalBalance),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: mif.text,
                  ),
                ),
                Icon(Icons.chevron_right, color: mif.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Mon argent personnel » : reste, dépenses du mois par catégorie, mois
/// par mois, et mes dépenses. Visible par soi seul.
class PersonalMoneyScreen extends StatefulWidget {
  const PersonalMoneyScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PersonalMoneyScreen()));

  @override
  State<PersonalMoneyScreen> createState() => _PersonalMoneyScreenState();
}

class _PersonalMoneyScreenState extends State<PersonalMoneyScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final now = store.now();
    final month = _month ?? DateTime(now.year, now.month);
    final received = store.personalReceived(month);
    final spent = store.personalSpent(month);
    final byCategory = store.personalByCategory(month);
    final expenses = store.personalExpenses(month);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final heroBg = dark ? mif.card : mif.text;
    final heroFg = dark ? mif.text : mif.background;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon argent personnel'),
        actions: [
          IconButton(
            tooltip: "Réglages de l'argent personnel",
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => PersonalMoneySetupScreen.open(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: mif.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Visible par vous seul',
                style: TextStyle(fontSize: 13, color: mif.textSecondary),
              ),
            ],
          ),
          MonthSwitcher(
            month: month,
            now: now,
            onChanged: (m) => setState(() => _month = m),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: heroBg,
              borderRadius: BorderRadius.circular(20),
              border: dark ? Border.all(color: mif.border) : null,
            ),
            child: DefaultTextStyle(
              style: TextStyle(fontFamily: 'Inter', color: heroFg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reste',
                    style: TextStyle(
                      fontSize: 13,
                      color: heroFg.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatAmount(store.personalBalance),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (received > 0)
                          TextSpan(
                            text:
                                ' · reçu ${formatFcfa(received)} en ${monthName(month)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: heroFg.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (received > 0) ...[
                    const SizedBox(height: 10),
                    ValueBar(
                      fraction: spent / received,
                      color: dark ? mif.chartExpense : const Color(0xFFF0A06A),
                      height: 8,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${formatFcfa(spent)} dépensés en ${monthName(month)} · '
                    'seul le versement mensuel est visible du foyer',
                    style: TextStyle(
                      fontSize: 12,
                      color: heroFg.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MifCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final w in store.personalWallets)
                  ListTile(
                    dense: true,
                    leading: Icon(walletIcon(w.type)),
                    title: Text(w.name),
                    trailing: Text(
                      formatAmount(store.walletBalance(w.id)),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: mif.text,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (byCategory.isNotEmpty) ...[
            _Header('Par catégorie'),
            MifCard(
              child: Column(
                children: [
                  for (final t in byCategory)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.category?.name ?? 'Sans catégorie',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mif.text,
                                  ),
                                ),
                              ),
                              Text(
                                formatAmount(t.amount),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mif.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ValueBar(
                            fraction: spent == 0 ? 0 : t.amount / spent,
                            color: mif.chartExpense,
                            height: 6,
                            track: true,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          _Header('Mois par mois'),
          MifCard(
            child: _PersonalMonths(
              // 6 mois au plus, à partir du premier mois saisi.
              months: store.personalMonths(
                month,
                count: store.firstActivityMonth == null
                    ? 1
                    : (monthsBetween(store.firstActivityMonth!, month) + 1)
                          .clamp(1, 6)
                          .toInt(),
              ),
              selected: month,
              onSelected: (m) => setState(() => _month = m),
            ),
          ),
          _Header('Mes dépenses'),
          MifCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final op in expenses) _PersonalExpenseTile(operation: op),
                if (expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aucune dépense personnelle en ${monthName(month)}. '
                      'Payez avec votre portefeuille personnel dans la saisie '
                      'rapide : vous seul la verrez.',
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

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: SectionTitle(text),
  );
}

/// Reçu et dépensé en argent personnel, mois par mois (même présentation
/// que les revenus et dépenses du foyer, avec ses propres libellés).
class _PersonalMonths extends StatelessWidget {
  const _PersonalMonths({
    required this.months,
    required this.selected,
    required this.onSelected,
  });

  final List<MonthSummary> months;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    // Les mois d'avant le premier mouvement d'argent personnel sont omis.
    final first = this.months.indexWhere((m) => m.income > 0 || m.expense > 0);
    final months = first <= 0 ? this.months : this.months.sublist(first);
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
            LegendItem(color: mif.chartIncome, label: 'Reçu'),
            LegendItem(color: mif.chartExpense, label: 'Dépensé'),
          ],
        ),
        const SizedBox(height: 8),
        for (final m in months)
          InkWell(
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
                        fontWeight:
                            m.month!.month == selected.month &&
                                m.month!.year == selected.year
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: mif.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        ValueBar(
                          fraction: max == 0 ? 0 : m.income / max,
                          color: mif.chartIncome,
                        ),
                        const SizedBox(height: 2),
                        ValueBar(
                          fraction: max == 0 ? 0 : m.expense / max,
                          color: mif.chartExpense,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatAmount(m.income),
                          style: TextStyle(fontSize: 12, color: mif.text),
                        ),
                        Text(
                          formatAmount(m.expense),
                          style: TextStyle(fontSize: 12, color: mif.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Réglages → Argent personnel : montant, jour, portefeuille commun d'où
/// part le versement, portefeuille personnel qui le reçoit.
class PersonalMoneySetupScreen extends StatefulWidget {
  const PersonalMoneySetupScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PersonalMoneySetupScreen(),
    ),
  );

  @override
  State<PersonalMoneySetupScreen> createState() =>
      _PersonalMoneySetupScreenState();
}

class _PersonalMoneySetupScreenState extends State<PersonalMoneySetupScreen> {
  late final TextEditingController _amount;
  late int _day;
  String? _fromId;
  String? _toId;
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context);
    final r = store.allowance;
    _amount = TextEditingController(
      text: r == null ? '' : formatAmount(r.amount),
    );
    _day = r?.dayOfMonth ?? 1;
    _fromId =
        r?.sourceWalletId ??
        store.householdCurrentWallets.map((w) => w.id).firstOrNull;
    _toId =
        r?.targetWalletId ?? store.personalWallets.map((w) => w.id).firstOrNull;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _createPurse() async {
    final store = StoreScope.read(context);
    final w = await store.addWallet(
      name: 'Porte-monnaie',
      type: WalletType.cash,
      shared: false,
    );
    setState(() => _toId = w.id);
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text) ?? 0;
    if (amount <= 0 || _fromId == null || _toId == null || _saving) return;
    setState(() => _saving = true);
    await StoreScope.read(context).setupPersonalMoney(
      amount: amount,
      dayOfMonth: _day,
      fromWalletId: _fromId!,
      toWalletId: _toId!,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _disable() async {
    final store = StoreScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Désactiver l'argent personnel ?"),
        content: const Text(
          "Le versement mensuel s'arrête. Vos portefeuilles personnels et "
          "l'historique restent.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.disablePersonalMoney();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final enabled = store.settings.personalMoney;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: mif.textSecondary),
      ),
    );
    Widget chips(
      List<Wallet> wallets,
      String? selected,
      ValueChanged<String> on,
    ) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final w in wallets)
          ChoiceChip(
            avatar: Icon(walletIcon(w.type), size: 18),
            label: Text(w.name),
            selected: w.id == selected,
            showCheckmark: false,
            onSelected: (_) => on(w.id),
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Argent personnel'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Chaque mois, un montant passe du budget du foyer à votre '
              'portefeuille personnel. Le foyer voit ce versement, mais ni '
              'vos dépenses personnelles ni ce qui vous reste.',
              style: TextStyle(fontSize: 14, color: mif.textSecondary),
            ),
            const SizedBox(height: 20),
            AmountField(controller: _amount, label: 'Montant mensuel'),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                'Le versement vous est proposé à confirmer chaque mois, avec '
                'un montant modifiable.',
                style: TextStyle(fontSize: 12, color: mif.textSecondary),
              ),
            ),
            label('Jour du versement'),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Jour précédent',
                  onPressed: _day > 1 ? () => setState(() => _day--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    'le ${_day == 1 ? '1er' : _day} de chaque mois',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: mif.text,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Jour suivant',
                  onPressed: _day < 31 ? () => setState(() => _day++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            label('Depuis (portefeuille du foyer)'),
            chips(
              store.householdCurrentWallets,
              _fromId,
              (id) => setState(() => _fromId = id),
            ),
            label('Vers (votre portefeuille personnel)'),
            if (store.personalWallets.isNotEmpty)
              chips(
                store.personalWallets,
                _toId,
                (id) => setState(() => _toId = id),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _createPurse,
                icon: const Icon(Icons.add),
                label: const Text('Créer « Porte-monnaie » (espèces)'),
              ),
            ),
            Text(
              'Vous pouvez avoir plusieurs portefeuilles personnels (porte-'
              'monnaie, Mobile Money perso) : votre reste est leur total, et '
              'passer de l\'un à l\'autre est un simple transfert.',
              style: TextStyle(fontSize: 12, color: mif.textSecondary),
            ),
            const SizedBox(height: 28),
            ListenableBuilder(
              listenable: _amount,
              builder: (context, _) {
                final ready =
                    (parseAmount(_amount.text) ?? 0) > 0 &&
                    _fromId != null &&
                    _toId != null;
                return FilledButton(
                  onPressed: ready && !_saving ? _save : null,
                  child: Text(
                    enabled ? 'Enregistrer' : "Activer l'argent personnel",
                  ),
                );
              },
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _disable,
                child: const Text("Désactiver l'argent personnel"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une dépense personnelle : sa note (ou sa catégorie), le portefeuille et
/// le jour. Toucher pour la modifier.
class _PersonalExpenseTile extends StatelessWidget {
  const _PersonalExpenseTile({required this.operation});

  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final op = operation;
    return InkWell(
      onTap: () => openEntry(context, existing: op),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CategoryBadge(category: store.topCategory(op.categoryId)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    op.note.isNotEmpty ? op.note : operationTitle(store, op),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: mif.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      ?store.wallet(op.sourceWalletId)?.name,
                      dayLabel(op.date, now: store.now()).toLowerCase(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: mif.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatSigned(-op.amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: mif.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
