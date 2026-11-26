import 'package:material_ui/material_ui.dart';

import '../models/category.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// Liste des catégories de dépenses ou de revenus, par groupe, avec les
/// catégories archivées à restaurer.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.initialKind = CategoryKind.expense});

  final CategoryKind initialKind;

  static Future<void> open(
    BuildContext context, {
    CategoryKind kind = CategoryKind.expense,
  }) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CategoriesScreen(initialKind: kind)),
  );

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late CategoryKind _kind = widget.initialKind;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final tops = store.topCategories(_kind);
    final archived = store.archivedTopCategories(_kind);
    final groups = _kind == CategoryKind.expense
        ? [CategoryGroup.essential, CategoryGroup.comfort, null]
        : [null];

    Widget tile(Category c) {
      final subs = store.subcategories(c.id).length;
      return ListTile(
        leading: CategoryBadge(category: c, size: 36),
        title: Text(c.name),
        subtitle: subs == 0
            ? null
            : Text('$subs sous-catégorie${subs > 1 ? 's' : ''}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => CategoryFormScreen.open(context, existing: c),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SegmentedButton<CategoryKind>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: CategoryKind.expense,
                label: Text('Dépenses'),
              ),
              ButtonSegment(value: CategoryKind.income, label: Text('Revenus')),
            ],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          for (final g in groups)
            if (tops.any((c) => c.group == g || groups.length == 1)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                child: Text(
                  groups.length == 1 ? 'Revenus' : g?.label ?? 'Sans groupe',
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
                    for (final c in tops)
                      if (groups.length == 1 || c.group == g) tile(c),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => CategoryFormScreen.open(context, kind: _kind),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle catégorie'),
          ),
          if (archived.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              child: Text(
                'Archivées',
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
                  for (final c in archived)
                    ListTile(
                      leading: CategoryBadge(category: c, size: 36),
                      title: Text(c.name),
                      trailing: TextButton(
                        onPressed: () =>
                            store.updateCategory(c.copyWith(archived: false)),
                        child: const Text('Restaurer'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Création ou modification d'une catégorie principale : nom, groupe,
/// icône, couleur et sous-catégories.
class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({
    super.key,
    this.existing,
    this.kind = CategoryKind.expense,
  });

  final Category? existing;
  final CategoryKind kind;

  static Future<Category?> open(
    BuildContext context, {
    Category? existing,
    CategoryKind kind = CategoryKind.expense,
  }) => Navigator.of(context).push<Category>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CategoryFormScreen(existing: existing, kind: kind),
    ),
  );

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  late final TextEditingController _name;
  late CategoryGroup? _group;
  late String _icon;
  late int _color;
  bool _saving = false;

  bool get _editing => widget.existing != null;
  CategoryKind get _kind => widget.existing?.kind ?? widget.kind;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _group =
        e?.group ??
        (e == null && widget.kind == CategoryKind.expense
            ? CategoryGroup.comfort
            : null);
    _icon = e?.icon ?? 'divers';
    _color = e?.color ?? categoryColors.last;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _missing(BudgetStore store) {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Donner un nom';
    if (store.categoryNameTaken(
      name,
      kind: _kind,
      exceptId: widget.existing?.id,
    )) {
      return 'Ce nom existe déjà';
    }
    return null;
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    if (_missing(store) != null || _saving) return;
    setState(() => _saving = true);
    final Category result;
    if (_editing) {
      result = widget.existing!.copyWith(
        name: _name.text.trim(),
        group: () => _group,
        icon: _icon,
        color: _color,
      );
      await store.updateCategory(result);
    } else {
      result = await store.addCategory(
        name: _name.text,
        kind: _kind,
        group: _group,
        icon: _icon,
        color: _color,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _archive() async {
    final store = StoreScope.read(context);
    final c = widget.existing!;
    final used = store.categoryUsage(c.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archiver « ${c.name} » ?'),
        content: Text(
          "Elle n'apparaîtra plus dans la saisie ni dans les budgets à "
          'définir, avec ses sous-catégories. '
          '${used == 0 ? '' : 'Les $used opérations déjà saisies la gardent. '}'
          'Vous pourrez la restaurer.',
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
    final archived = c.copyWith(archived: true);
    await store.updateCategory(archived);
    if (mounted) Navigator.of(context).pop(archived);
  }

  /// Nom d'une sous-catégorie (création ou renommage).
  Future<String?> _askSubName(BudgetStore store, {Category? sub}) =>
      showDialog<String>(
        context: context,
        builder: (_) => _SubNameDialog(
          initial: sub?.name ?? '',
          title: sub == null ? 'Nouvelle sous-catégorie' : 'Renommer',
          taken: (name) => store.categoryNameTaken(
            name,
            kind: _kind,
            parentId: widget.existing!.id,
            exceptId: sub?.id,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final existing = widget.existing;
    final subs = existing == null
        ? const <Category>[]
        : store.subcategories(existing.id);
    final archivedSubs = existing == null
        ? const <Category>[]
        : store.archivedSubcategories(existing.id);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: mif.textSecondary),
      ),
    );
    final preview = Category(
      id: 'apercu',
      name: _name.text,
      kind: _kind,
      icon: _icon,
      color: _color,
      updatedAt: DateTime(2000),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? 'Modifier la catégorie' : 'Nouvelle catégorie'),
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
            Row(
              children: [
                CategoryBadge(category: preview, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nom',
                      errorText: _missing(store) == 'Ce nom existe déjà'
                          ? 'Ce nom existe déjà'
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_kind == CategoryKind.expense) ...[
              label('Groupe'),
              SegmentedButton<CategoryGroup?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CategoryGroup.essential,
                    label: Text('Essentiel'),
                  ),
                  ButtonSegment(
                    value: CategoryGroup.comfort,
                    label: Text('Confort'),
                  ),
                  ButtonSegment(value: null, label: Text('Aucun')),
                ],
                selected: {_group},
                onSelectionChanged: (v) => setState(() => _group = v.first),
              ),
            ],
            label('Icône'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: k, value: icon)
                    in categoryIcons.entries)
                  _Choice(
                    selected: k == _icon,
                    label: categoryIconLabels[k] ?? k,
                    onTap: () => setState(() => _icon = k),
                    child: Icon(
                      icon,
                      color: k == _icon ? mif.green : mif.textSecondary,
                    ),
                  ),
              ],
            ),
            label('Couleur'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in categoryColors)
                  _Choice(
                    selected: color == _color,
                    label: 'Couleur',
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            if (existing != null) ...[
              label('Sous-catégories'),
              MifCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final sub in subs)
                      ListTile(
                        title: Text(sub.name),
                        onTap: () async {
                          final name = await _askSubName(store, sub: sub);
                          if (name != null) {
                            await store.updateCategory(
                              sub.copyWith(name: name),
                            );
                          }
                        },
                        trailing: IconButton(
                          tooltip: 'Archiver ${sub.name}',
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => store.updateCategory(
                            sub.copyWith(archived: true),
                          ),
                        ),
                      ),
                    for (final sub in archivedSubs)
                      ListTile(
                        title: Text(
                          sub.name,
                          style: TextStyle(color: mif.textSecondary),
                        ),
                        subtitle: const Text('Archivée'),
                        trailing: TextButton(
                          onPressed: () => store.updateCategory(
                            sub.copyWith(archived: false),
                          ),
                          child: const Text('Restaurer'),
                        ),
                      ),
                    ListTile(
                      leading: Icon(Icons.add, color: mif.green),
                      title: Text(
                        'Ajouter une sous-catégorie',
                        style: TextStyle(color: mif.green),
                      ),
                      onTap: () async {
                        final name = await _askSubName(store);
                        if (name != null) {
                          await store.addCategory(
                            name: name,
                            kind: _kind,
                            parentId: existing.id,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Vous pourrez ajouter des sous-catégories une fois la '
                  'catégorie enregistrée.',
                  style: TextStyle(fontSize: 12, color: mif.textSecondary),
                ),
              ),
            const SizedBox(height: 28),
            Builder(
              builder: (context) {
                final missing = _missing(store);
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

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? mif.greenSoft : mif.card,
            border: Border.all(
              color: selected ? mif.green : mif.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Fenêtre de saisie d'un nom de sous-catégorie. Elle possède son champ,
/// libéré seulement quand elle disparaît (après l'animation de fermeture).
class _SubNameDialog extends StatefulWidget {
  const _SubNameDialog({
    required this.initial,
    required this.title,
    required this.taken,
  });

  final String initial;
  final String title;
  final bool Function(String name) taken;

  @override
  State<_SubNameDialog> createState() => _SubNameDialogState();
}

class _SubNameDialogState extends State<_SubNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _controller.text.trim();
    final taken = name.isNotEmpty && widget.taken(name);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nom',
          errorText: taken ? 'Ce nom existe déjà' : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: name.isEmpty || taken
              ? null
              : () => Navigator.pop(context, name),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
