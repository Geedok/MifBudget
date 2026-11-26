import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/savings_goal.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'wallet_form_screen.dart';
import 'widgets/amount_field.dart';
import 'widgets/common.dart';

/// Création ou modification d'un objectif d'épargne : nom, icône, cible,
/// date cible facultative, compte épargne, et sa part du compte quand
/// celui-ci a plusieurs objectifs.
class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({
    super.key,
    this.existing,
    this.suggestedName,
    this.suggestedIcon,
    this.walletId,
  });

  final SavingsGoal? existing;
  final String? suggestedName;
  final String? suggestedIcon;

  /// Compte épargne proposé.
  final String? walletId;

  static Future<SavingsGoal?> open(
    BuildContext context, {
    SavingsGoal? existing,
    String? suggestedName,
    String? suggestedIcon,
    String? walletId,
  }) => Navigator.of(context).push<SavingsGoal>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GoalFormScreen(
        existing: existing,
        suggestedName: suggestedName,
        suggestedIcon: suggestedIcon,
        walletId: walletId,
      ),
    ),
  );

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _start;
  DateTime? _targetDate;
  String? _walletId;
  late String _icon;
  bool _saving = false;
  bool _initialized = false;

  bool get _editing => widget.existing != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context);
    final e = widget.existing;
    String amount(int v) => v == 0 ? '' : formatAmount(v);
    _name = TextEditingController(text: e?.name ?? widget.suggestedName ?? '');
    _target = TextEditingController(text: amount(e?.target ?? 0));
    _start = TextEditingController(text: amount(e?.startAmount ?? 0));
    _targetDate = e?.targetDate;
    _icon = e?.icon ?? widget.suggestedIcon ?? 'epargne';
    _walletId =
        e?.walletId ??
        widget.walletId ??
        store.savingsWallets.map((w) => w.id).firstOrNull;
  }

  /// Les autres objectifs du compte choisi.
  List<SavingsGoal> _others(BudgetStore store) => _walletId == null
      ? const []
      : store
            .walletGoals(_walletId!)
            .where((g) => g.id != widget.existing?.id)
            .toList();

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _start.dispose();
    super.dispose();
  }

  String? get _missing {
    if (_walletId == null) return 'Choisir un compte épargne';
    if (_name.text.trim().isEmpty) return 'Donner un nom';
    if ((parseAmount(_target.text) ?? 0) <= 0) return 'Saisir le montant cible';
    return null;
  }

  Future<void> _pickDate() async {
    final now = StoreScope.read(context).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year + 1, now.month),
      firstDate: DateTime(now.year, now.month),
      lastDate: DateTime(now.year + 30, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Date cible (seul le mois compte)',
    );
    if (picked != null) {
      setState(() => _targetDate = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _save() async {
    if (_missing != null || _saving) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final target = parseAmount(_target.text)!;
    // La part de départ ne sert que si le compte a d'autres objectifs.
    final start = _others(store).isEmpty ? 0 : parseAmount(_start.text) ?? 0;
    final SavingsGoal result;
    if (_editing) {
      result = widget.existing!.copyWith(
        name: _name.text.trim(),
        target: target,
        startAmount: start,
        targetDate: () => _targetDate,
        walletId: () => _walletId,
        icon: _icon,
      );
      await store.updateGoal(result);
    } else {
      result = await store.addGoal(
        name: _name.text,
        target: target,
        startAmount: start,
        targetDate: _targetDate,
        walletId: _walletId,
        icon: _icon,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _archive() async {
    final store = StoreScope.read(context);
    final g = widget.existing!;
    final balance = store.goalBalance(g.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archiver « ${g.name} » ?'),
        content: Text(
          balance > 0
              ? "L'objectif disparaîtra de la liste ; ses ${formatFcfa(balance)} restent sur le compte épargne. L'historique est conservé."
              : "L'objectif disparaîtra de la liste. L'historique est conservé.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.updateGoal(g.copyWith(archived: true));
    if (mounted) Navigator.of(context).pop(g.copyWith(archived: true));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? "Modifier l'objectif" : 'Nouvel objectif'),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archiver',
              onPressed: _archive,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 16),
            _IconChoice(
              selected: _icon,
              onSelected: (k) => setState(() => _icon = k),
            ),
            const SizedBox(height: 16),
            AmountField(controller: _target, label: 'Montant cible'),
            const SizedBox(height: 16),
            _StartAmount(
              controller: _start,
              others: _others(store),
              walletId: _walletId,
            ),
            const SizedBox(height: 16),
            Text(
              'Date cible (facultatif)',
              style: TextStyle(fontSize: 13, color: mif.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _targetDate == null
                        ? 'Choisir un mois'
                        : monthLabel(_targetDate!),
                  ),
                ),
                if (_targetDate != null)
                  TextButton(
                    onPressed: () => setState(() => _targetDate = null),
                    child: const Text('Sans date'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Compte épargne',
              style: TextStyle(fontSize: 13, color: mif.textSecondary),
            ),
            const SizedBox(height: 6),
            if (store.savingsWallets.isEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final w = await WalletFormScreen.open(
                    context,
                    initialRole: WalletRole.savings,
                  );
                  if (w != null && w.isSavings) {
                    setState(() => _walletId = w.id);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un compte épargne'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final w in store.savingsWallets)
                    ChoiceChip(
                      avatar: Icon(walletIcon(w.type), size: 18),
                      label: Text(w.name),
                      selected: w.id == _walletId,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _walletId = w.id),
                    ),
                ],
              ),
            const SizedBox(height: 28),
            // Le bouton suit la saisie du nom et du montant cible.
            ListenableBuilder(
              listenable: Listenable.merge([_name, _target, _start]),
              builder: (context, _) {
                final missing = _missing;
                return FilledButton(
                  onPressed: missing == null && !_saving ? _save : null,
                  child: Text(missing ?? 'Enregistrer'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _labels = {
    'epargne': 'Épargne',
    'surete': 'Sûreté',
    'construction': 'Construction',
    'maison': 'Maison',
    'ecole': 'École',
    'vehicule': 'Véhicule',
    'voyage': 'Voyage',
    'fete': 'Fête',
  };

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: k, value: icon) in goalIcons.entries)
          Tooltip(
            message: _labels[k] ?? k,
            child: Semantics(
              label: _labels[k] ?? k,
              selected: k == selected,
              button: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelected(k),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: k == selected ? mif.greenSoft : mif.card,
                    border: Border.all(
                      color: k == selected ? mif.green : mif.border,
                      width: k == selected ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: k == selected ? mif.green : mif.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Part du compte déjà destinée à l'objectif : utile seulement si le compte
/// a d'autres objectifs ; sinon l'objectif a tout le solde du compte.
class _StartAmount extends StatelessWidget {
  const _StartAmount({
    required this.controller,
    required this.others,
    required this.walletId,
  });

  final TextEditingController controller;
  final List<SavingsGoal> others;
  final String? walletId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final help = TextStyle(fontSize: 12, color: mif.textSecondary);
    if (walletId == null) return const SizedBox.shrink();
    if (others.isEmpty) {
      return Text(
        "Seul objectif de ce compte : tout son solde "
        "(${formatFcfa(store.walletBalance(walletId!))}) compte pour lui.",
        style: help,
      );
    }
    final source = others.length == 1
        ? "Elle est prise sur « ${others.first.name} », qui a "
              "${formatFcfa(store.goalBalance(others.first.id))}."
        : 'Non réparti sur ce compte : '
              '${formatFcfa(store.unallocated(walletId!))}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AmountField(
          controller: controller,
          label: 'Part du compte déjà destinée à cet objectif',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(source, style: help),
        ),
      ],
    );
  }
}
