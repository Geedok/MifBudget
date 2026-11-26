import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/savings_goal.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'widgets/amount_field.dart';
import 'widgets/common.dart';

/// Création ou modification d'une épargne : nom, cible, date cible
/// facultative, portefeuille, montant déjà épargné, icône.
class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({
    super.key,
    this.existing,
    this.suggestedName,
    this.suggestedIcon,
  });

  final SavingsGoal? existing;
  final String? suggestedName;
  final String? suggestedIcon;

  static Future<SavingsGoal?> open(
    BuildContext context, {
    SavingsGoal? existing,
    String? suggestedName,
    String? suggestedIcon,
  }) => Navigator.of(context).push<SavingsGoal>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GoalFormScreen(
        existing: existing,
        suggestedName: suggestedName,
        suggestedIcon: suggestedIcon,
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
    final wallets = store.wallets;
    _walletId =
        e?.walletId ??
        wallets
            .where((w) => w.name == 'Banque')
            .followedBy(wallets)
            .map((w) => w.id)
            .firstOrNull;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _start.dispose();
    super.dispose();
  }

  String? get _missing {
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
    final start = parseAmount(_start.text) ?? 0;
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
              ? "Les ${formatFcfa(balance)} mis de côté redeviendront disponibles. L'historique est conservé."
              : "L'épargne disparaîtra de la liste. L'historique est conservé.",
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
        title: Text(_editing ? "Modifier l'épargne" : 'Nouvelle épargne'),
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
            AmountField(
              controller: _start,
              label: 'Déjà mis de côté (facultatif)',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                "L'argent que vous avez déjà pour cette épargne. Il doit être compté dans le solde du portefeuille choisi plus bas.",
                style: TextStyle(fontSize: 12, color: mif.textSecondary),
              ),
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
              "Portefeuille où se trouve l'argent",
              style: TextStyle(fontSize: 13, color: mif.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final w in store.wallets)
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
              listenable: Listenable.merge([_name, _target]),
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
