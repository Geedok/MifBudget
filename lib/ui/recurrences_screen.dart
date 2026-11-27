import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/projection.dart';
import '../models/operation.dart';
import '../models/recurrence.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'quick_entry_screen.dart';
import 'widgets/common.dart';

/// « le 5 de chaque mois », « le 1er de chaque mois ».
String dayLabelOf(Recurrence r) =>
    'le ${r.dayOfMonth == 1 ? '1er' : r.dayOfMonth} de chaque mois';

/// Nom d'une récurrence : sa note si elle en a une (« Canal+ »), sinon le
/// libellé habituel de l'opération.
String recurrenceTitle(BudgetStore store, Operation op) =>
    op.note.isNotEmpty ? op.note : operationTitle(store, op);

/// Montant signé d'une opération récurrente (« −150 000 », « +650 000 »).
String _amountOf(BudgetStore store, Operation op) {
  if (op.type == OperationType.transfer) return formatAmount(op.amount);
  return formatSigned(signedAmount(op));
}

/// Réglages → Opérations récurrentes.
class RecurrencesScreen extends StatelessWidget {
  const RecurrencesScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RecurrencesScreen()));

  /// Nouvelle récurrence : d'abord l'opération (avec la saisie habituelle),
  /// puis le calendrier.
  static Future<void> create(BuildContext context) async {
    final result = await QuickEntryScreen.open(context, mode: EntryMode.draft);
    if (result == null || !context.mounted) return;
    await RecurrenceFormScreen.open(context, template: result.operation);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final list = store.recurrences;
    final stopped = store.stoppedRecurrences;
    return Scaffold(
      appBar: AppBar(title: const Text('Opérations récurrentes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            'Loyer, salaire, abonnements, virements d\'épargne : elles '
            'reviennent chaque mois. Le jour venu, elles apparaissent sur '
            'l\'Accueil pour être confirmées (ou s\'enregistrent seules si '
            'elles sont automatiques).',
            style: TextStyle(fontSize: 13, color: mif.textSecondary),
          ),
          const SizedBox(height: 12),
          const RecurringCard(showPending: false),
          if (list.isNotEmpty)
            MifCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final r in list) _RecurrenceTile(recurrence: r),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => create(context),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle récurrence'),
          ),
          if (stopped.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              child: Text(
                'Arrêtées',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mif.textSecondary,
                ),
              ),
            ),
            MifCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final r in stopped) _RecurrenceTile(recurrence: r),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecurrenceTile extends StatelessWidget {
  const _RecurrenceTile({required this.recurrence});

  final Recurrence recurrence;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = recurrence;
    final op = store.draftFor(Occurrence(r, r.startMonth));
    final state = r.stopped
        ? 'arrêtée'
        : r.paused
        ? 'en pause'
        : r.automatic
        ? 'automatique'
        : 'à confirmer';
    return ListTile(
      leading: CategoryBadge(
        category: op.type == OperationType.transfer
            ? null
            : store.topCategory(op.categoryId),
      ),
      title: Text(recurrenceTitle(store, op)),
      subtitle: Text('${dayLabelOf(r)} · $state'),
      trailing: Text(
        _amountOf(store, op),
        style: TextStyle(fontWeight: FontWeight.w600, color: context.mif.text),
      ),
      onTap: () => RecurrenceFormScreen.open(context, existing: r),
    );
  }
}

/// Création ou modification d'une récurrence : l'opération type, le jour du
/// mois, le premier et le dernier mois, et le mode (à confirmer ou
/// automatique).
class RecurrenceFormScreen extends StatefulWidget {
  const RecurrenceFormScreen({
    super.key,
    this.existing,
    this.template,
    this.fromOperation,
  });

  /// Récurrence à modifier.
  final Recurrence? existing;

  /// Opération type d'une nouvelle récurrence.
  final Operation? template;

  /// Opération déjà saisie à rendre récurrente (elle devient l'échéance de
  /// son mois).
  final Operation? fromOperation;

  static Future<void> open(
    BuildContext context, {
    Recurrence? existing,
    Operation? template,
    Operation? fromOperation,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RecurrenceFormScreen(
        existing: existing,
        template: template,
        fromOperation: fromOperation,
      ),
    ),
  );

  @override
  State<RecurrenceFormScreen> createState() => _RecurrenceFormScreenState();
}

class _RecurrenceFormScreenState extends State<RecurrenceFormScreen> {
  late Operation _op;
  late int _day;
  late DateTime _start;
  DateTime? _end;
  late bool _automatic;
  late bool _paused;
  bool _saving = false;
  bool _initialized = false;

  bool get _editing => widget.existing != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context);
    final today = dateOnly(store.now());
    final r = widget.existing;
    if (r != null) {
      _op = store.draftFor(Occurrence(r, r.startMonth));
      _day = r.dayOfMonth;
      _start = r.startMonth;
      _end = r.endMonth;
      _automatic = r.automatic;
      _paused = r.paused;
      return;
    }
    final from = widget.fromOperation;
    _op = from ?? widget.template!;
    _automatic = false;
    _paused = false;
    if (from != null) {
      // L'opération saisie est l'échéance de son mois.
      _day = from.date.day;
      _start = DateTime(from.date.year, from.date.month);
    } else {
      _day = today.day;
      // Le jour même : à confirmer tout de suite ; sinon le mois prochain.
      _start = DateTime(today.year, today.month);
    }
  }

  Future<void> _editOperation() async {
    final result = await QuickEntryScreen.open(
      context,
      existing: _op,
      mode: EntryMode.draft,
    );
    if (result != null) setState(() => _op = result.operation);
  }

  Future<void> _pickEnd() async {
    final now = StoreScope.read(context).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? addMonths(now, 12),
      firstDate: _start,
      lastDate: DateTime(now.year + 30, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Dernier mois (seul le mois compte)',
    );
    if (picked != null) {
      setState(() => _end = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final r = widget.existing;
    if (r != null) {
      await store.updateRecurrence(
        r.copyWith(
          type: _op.type,
          amount: _op.amount,
          categoryId: () => _op.categoryId,
          sourceWalletId: () => _op.sourceWalletId,
          targetWalletId: () => _op.targetWalletId,
          savingsGoalId: () => _op.savingsGoalId,
          projectId: () => _op.projectId,
          note: _op.note,
          dayOfMonth: _day,
          endMonth: () => _end,
          automatic: _automatic,
          paused: _paused,
        ),
      );
    } else {
      await store.addRecurrence(
        type: _op.type,
        amount: _op.amount,
        categoryId: _op.categoryId,
        sourceWalletId: _op.sourceWalletId,
        targetWalletId: _op.targetWalletId,
        savingsGoalId: _op.savingsGoalId,
        projectId: _op.projectId,
        note: _op.note,
        dayOfMonth: _day,
        startMonth: _start,
        endMonth: _end,
        automatic: _automatic,
        linkedOperationId: widget.fromOperation?.id,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stop() async {
    final store = StoreScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrêter cette récurrence ?'),
        content: const Text(
          'Elle ne sera plus proposée. Les opérations déjà enregistrées '
          'restent dans l\'historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.updateRecurrence(widget.existing!.copyWith(stopped: true));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final today = dateOnly(store.now());
    final thisMonth = DateTime(today.year, today.month);
    final nextMonth = DateTime(today.year, today.month + 1);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: mif.textSecondary),
      ),
    );
    final stopped = widget.existing?.stopped ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? 'Modifier la récurrence' : 'Rendre récurrente'),
        actions: [
          if (_editing && !stopped)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Arrêter',
              onPressed: _stop,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            MifCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  OperationTile(operation: _op, onTap: _editOperation),
                  if (widget.fromOperation == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _editOperation,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text("Modifier l'opération"),
                      ),
                    ),
                ],
              ),
            ),
            label('Jour du mois'),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Jour précédent',
                  onPressed: _day > 1 ? () => setState(() => _day--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    dayLabelOf(
                      Recurrence(
                        id: '',
                        type: _op.type,
                        amount: 0,
                        dayOfMonth: _day,
                        startMonth: _start,
                        createdAt: today,
                        updatedAt: today,
                      ),
                    ),
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
            if (_day > 28)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Les mois plus courts, ce sera le dernier jour du mois.',
                  style: TextStyle(fontSize: 12, color: mif.textSecondary),
                ),
              ),
            label('À partir de'),
            if (_editing || widget.fromOperation != null)
              Text(
                monthLabel(_start),
                style: TextStyle(fontSize: 15, color: mif.text),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final m in [thisMonth, nextMonth])
                    ChoiceChip(
                      label: Text(monthLabel(m)),
                      selected: _start == m,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _start = m),
                    ),
                ],
              ),
            label("Jusqu'à (facultatif)"),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickEnd,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_end == null ? 'Sans fin' : monthLabel(_end!)),
                ),
                if (_end != null)
                  TextButton(
                    onPressed: () => setState(() => _end = null),
                    child: const Text('Sans fin'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Enregistrer automatiquement'),
              subtitle: Text(
                _automatic
                    ? "Enregistrée seule le jour venu, sans rien demander."
                    : "Le jour venu, elle vous est proposée à confirmer "
                          "(montant modifiable) sur l'Accueil.",
              ),
              value: _automatic,
              onChanged: (v) => setState(() => _automatic = v),
            ),
            if (_editing && !stopped)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('En pause'),
                subtitle: const Text(
                  'Rien ne sera proposé tant que la pause dure.',
                ),
                value: _paused,
                onChanged: (v) => setState(() => _paused = v),
              ),
            if (stopped)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.tonal(
                  onPressed: () async {
                    await store.updateRecurrence(
                      widget.existing!.copyWith(stopped: false),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Reprendre cette récurrence'),
                ),
              )
            else ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _op.amount > 0 && !_saving ? _save : null,
                child: const Text('Enregistrer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Accueil : échéances à confirmer, puis celles des 30 prochains jours.
class RecurringCard extends StatelessWidget {
  const RecurringCard({
    super.key,
    this.showPending = true,
    this.showUpcoming = true,
  });

  /// « À confirmer » (l'Accueil n'affiche que celles-ci).
  final bool showPending;

  /// « À venir » dans les 30 jours.
  final bool showUpcoming;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final pending = showPending
        ? store.pendingOccurrences
        : const <Occurrence>[];
    final upcoming = showUpcoming
        ? store.upcomingOccurrences().take(4).toList()
        : const <Occurrence>[];
    if (pending.isEmpty && upcoming.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MifCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pending.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: SectionTitle('À confirmer (${pending.length})'),
              ),
              for (final o in pending) _PendingRow(occurrence: o),
            ],
            if (upcoming.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  pending.isEmpty ? 0 : 12,
                  16,
                  4,
                ),
                child: const SectionTitle('À venir'),
              ),
              for (final o in upcoming)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          recurrenceTitle(store, store.draftFor(o)),
                          style: TextStyle(fontSize: 14, color: mif.text),
                        ),
                      ),
                      Text(
                        '${shortDate(o.date)} · ${_amountOf(store, store.draftFor(o))}',
                        style: TextStyle(
                          fontSize: 13,
                          color: mif.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final draft = store.draftFor(occurrence);
    final title = recurrenceTitle(store, draft);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toucher la ligne : confirmer en ajustant le montant ou la date.
          OperationTile(
            operation: draft,
            showDate: true,
            onTap: () =>
                openEntry(context, existing: draft, mode: EntryMode.confirm),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  await store.skipOccurrence(occurrence);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          '$title ignoré pour ${monthName(occurrence.month)}',
                        ),
                        persist: false,
                        action: SnackBarAction(
                          label: 'Annuler',
                          onPressed: () => store.undoOccurrence(
                            occurrence.recurrence.operationIdFor(
                              occurrence.month,
                            ),
                          ),
                        ),
                      ),
                    );
                },
                child: Text(
                  'Ignorer',
                  style: TextStyle(color: mif.textSecondary),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                // Le thème donne aux boutons pleins toute la largeur : ici,
                // dans une rangée, il faut une taille propre.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: mif.greenSoft,
                  foregroundColor: mif.text,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () async {
                  final op = await store.confirmOccurrence(occurrence);
                  if (!context.mounted) return;
                  final alert = budgetAlert(store, op);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          '$title enregistré${alert == null ? '' : ' · $alert'}',
                        ),
                        persist: false,
                        action: SnackBarAction(
                          label: 'Annuler',
                          onPressed: () => store.undoOccurrence(op.id),
                        ),
                      ),
                    );
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirmer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
