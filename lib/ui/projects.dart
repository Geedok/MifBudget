import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/projection.dart';
import '../models/project.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'widgets/amount_field.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

/// Carte d'un projet : budget, dépenses déjà faites, financement par son
/// objectif d'épargne et date estimée.
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final Project project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final p = project;
    final spent = store.projectSpent(p.id);
    final goal = store.goal(p.goalId);
    final saved = goal == null ? 0 : store.goalBalance(goal.id);
    final toFund = store.projectToFund(p);
    final funding = store.projectFundingDate(p);
    final small = TextStyle(fontSize: 13, color: mif.textSecondary);
    return Material(
      color: mif.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: mif.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: mif.track,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.status.label,
                      style: TextStyle(fontSize: 12, color: mif.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Budget ${formatFcfa(p.budget)}'
                '${p.targetDate == null ? '' : ' · prévu pour ${monthLabel(p.targetDate!).toLowerCase()}'}',
                style: small,
              ),
              if (spent > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dépensé ${formatAmount(spent)}',
                        style: TextStyle(fontSize: 13, color: mif.text),
                      ),
                    ),
                    Text(
                      formatPercent(p.budget == 0 ? 0 : spent / p.budget),
                      style: small,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ValueBar(
                  fraction: p.budget == 0 ? 0 : spent / p.budget,
                  color: mif.chartExpense,
                  height: 6,
                  track: true,
                ),
              ],
              if (goal != null && p.status != ProjectStatus.done) ...[
                const SizedBox(height: 10),
                Text(
                  'Financé par « ${goal.name} » : ${formatFcfa(saved)} épargnés',
                  style: TextStyle(fontSize: 13, color: mif.text),
                ),
              ],
              if (p.status != ProjectStatus.done) ...[
                const SizedBox(height: 4),
                Text(
                  toFund == 0
                      ? 'Entièrement financé'
                      : 'Reste à financer ${formatFcfa(toFund)}'
                            '${goal == null
                                ? ''
                                : funding == null
                                ? " · l'épargne n'avance pas"
                                : ' · vers ${monthLabel(funding).toLowerCase()}'}',
                  style: small,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Détail d'un projet : sa carte et ses dépenses.
class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final p = store.project(projectId);
    if (p == null) return const Scaffold();
    final ops = store.projectOperations(p.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final result = await ProjectFormScreen.open(context, existing: p);
              if (result != null && result.archived) navigator.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ProjectCard(project: p),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: SectionTitle('Dépenses du projet'),
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
                if (ops.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aucune dépense pour le moment. Dans la saisie rapide, '
                      'choisissez ce projet sous « Projet » pour la rattacher.',
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

/// Création ou modification d'un projet.
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, this.existing});

  final Project? existing;

  static Future<Project?> open(BuildContext context, {Project? existing}) =>
      Navigator.of(context).push<Project>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ProjectFormScreen(existing: existing),
        ),
      );

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  DateTime? _targetDate;
  String? _goalId;
  late ProjectStatus _status;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _budget = TextEditingController(
      text: (e?.budget ?? 0) == 0 ? '' : formatAmount(e!.budget),
    );
    _targetDate = e?.targetDate;
    _goalId = e?.goalId;
    _status = e?.status ?? ProjectStatus.planned;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  String? get _missing {
    if (_name.text.trim().isEmpty) return 'Donner un nom';
    if ((parseAmount(_budget.text) ?? 0) <= 0) return 'Saisir le budget';
    return null;
  }

  Future<void> _pickDate() async {
    final now = StoreScope.read(context).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? addMonths(now, 6),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Mois prévu (seul le mois compte)',
    );
    if (picked != null) {
      setState(() => _targetDate = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _save() async {
    if (_missing != null || _saving) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final budget = parseAmount(_budget.text)!;
    final Project result;
    if (_editing) {
      result = widget.existing!.copyWith(
        name: _name.text.trim(),
        budget: budget,
        targetDate: () => _targetDate,
        goalId: () => _goalId,
        status: _status,
      );
      await store.updateProject(result);
    } else {
      result = await store.addProject(
        name: _name.text,
        budget: budget,
        targetDate: _targetDate,
        goalId: _goalId,
        status: _status,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _archive() async {
    final store = StoreScope.read(context);
    final p = widget.existing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archiver « ${p.name} » ?'),
        content: const Text(
          "Le projet disparaîtra de la liste. Ses dépenses restent dans "
          "l'historique.",
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
    final archived = p.copyWith(archived: true);
    await store.updateProject(archived);
    if (mounted) Navigator.of(context).pop(archived);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: mif.textSecondary),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? 'Modifier le projet' : 'Nouveau projet'),
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
              decoration: const InputDecoration(
                labelText: 'Nom',
                hintText: 'Ex. : Fondations, Rentrée scolaire',
              ),
            ),
            const SizedBox(height: 16),
            AmountField(controller: _budget, label: 'Budget prévu'),
            label('Mois prévu (facultatif)'),
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
            label('Financé par (facultatif)'),
            if (store.goals.isEmpty)
              Text(
                "Aucun objectif d'épargne : vous pourrez en rattacher un plus "
                'tard depuis l\'onglet Épargnes.',
                style: TextStyle(fontSize: 13, color: mif.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Aucun'),
                    selected: _goalId == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _goalId = null),
                  ),
                  for (final g in store.goals)
                    ChoiceChip(
                      avatar: Icon(goalIcon(g.icon), size: 18),
                      label: Text(g.name),
                      selected: g.id == _goalId,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _goalId = g.id),
                    ),
                ],
              ),
            label('État'),
            SegmentedButton<ProjectStatus>(
              showSelectedIcon: false,
              segments: [
                for (final st in ProjectStatus.values)
                  ButtonSegment(value: st, label: Text(st.label)),
              ],
              selected: {_status},
              onSelectionChanged: (v) => setState(() => _status = v.first),
            ),
            const SizedBox(height: 28),
            ListenableBuilder(
              listenable: Listenable.merge([_name, _budget]),
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
