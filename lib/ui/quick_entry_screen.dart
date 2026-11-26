import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'widgets/amount_keypad.dart';
import 'widgets/common.dart';

/// Ce que l'écran de saisie renvoie, pour afficher la confirmation.
class EntryResult {
  const EntryResult(
    this.operation, {
    this.created = false,
    this.deleted = false,
  });
  final Operation operation;
  final bool created;
  final bool deleted;
}

/// Saisie rapide : le montant d'abord, puis la catégorie (les plus utilisées
/// en tête), le portefeuille (le dernier utilisé est présélectionné), et
/// enfin, si besoin, la date et une note.
class QuickEntryScreen extends StatefulWidget {
  const QuickEntryScreen({super.key, this.existing});

  /// Opération à modifier ; null pour une nouvelle saisie.
  final Operation? existing;

  static Future<EntryResult?> open(
    BuildContext context, {
    Operation? existing,
  }) => Navigator.of(context).push<EntryResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuickEntryScreen(existing: existing),
    ),
  );

  @override
  State<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends State<QuickEntryScreen> {
  static const _maxDigits = 12;

  late OperationType _type;
  String _digits = '';
  String? _categoryId;
  String? _walletId; // dépense : débité ; revenu : crédité
  String? _fromId; // transfert
  String? _toId; // transfert
  late DateTime _date;
  final _note = TextEditingController();
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
    if (e != null) {
      _type = e.type;
      _digits = e.amount.toString();
      _categoryId = e.categoryId;
      _date = e.date;
      _note.text = e.note;
      if (e.type == OperationType.transfer) {
        _fromId = e.sourceWalletId;
        _toId = e.targetWalletId;
      } else {
        _walletId = e.type == OperationType.income
            ? e.targetWalletId
            : e.sourceWalletId;
      }
    } else {
      _type = OperationType.expense;
      _date = dateOnly(store.now());
      _applyDefaultWallets(store);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _applyDefaultWallets(BudgetStore store) {
    final wallets = store.wallets;
    if (wallets.isEmpty) return;
    String fallback(String? id) => id ?? wallets.first.id;
    if (_type == OperationType.transfer) {
      _fromId ??= fallback(store.lastWalletFor(OperationType.transfer));
      _toId ??= wallets
          .firstWhere((w) => w.id != _fromId, orElse: () => wallets.first)
          .id;
    } else {
      _walletId = fallback(store.lastWalletFor(_type));
    }
  }

  int get _amount => int.tryParse(_digits) ?? 0;

  CategoryKind get _kind => _type == OperationType.income
      ? CategoryKind.income
      : CategoryKind.expense;

  String? get _missing {
    if (_amount <= 0) return 'Saisir un montant';
    if (_type == OperationType.transfer) {
      if (_fromId == null || _toId == null) return 'Choisir les portefeuilles';
      if (_fromId == _toId) return 'Choisir deux portefeuilles différents';
      return null;
    }
    if (_categoryId == null) return 'Choisir une catégorie';
    if (_walletId == null) return 'Choisir un portefeuille';
    return null;
  }

  void _setType(OperationType type) {
    if (type == _type) return;
    setState(() {
      final kindChanged =
          (type == OperationType.income) != (_type == OperationType.income);
      _type = type;
      if (kindChanged || type == OperationType.transfer) _categoryId = null;
      _applyDefaultWallets(StoreScope.read(context));
    });
  }

  void _addDigits(String d) {
    setState(() {
      var next = _digits + d;
      next = next.replaceFirst(RegExp(r'^0+'), '');
      if (next.length > _maxDigits) return;
      _digits = next;
    });
  }

  Future<void> _save() async {
    if (_missing != null || _saving) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final isTransfer = _type == OperationType.transfer;
    final source = isTransfer
        ? _fromId
        : (_type == OperationType.income ? null : _walletId);
    final target = isTransfer
        ? _toId
        : (_type == OperationType.income ? _walletId : null);
    final category = isTransfer ? null : _categoryId;
    final EntryResult result;
    if (_editing) {
      final updated = widget.existing!.copyWith(
        type: _type,
        amount: _amount,
        date: _date,
        categoryId: () => category,
        sourceWalletId: () => source,
        targetWalletId: () => target,
        note: _note.text.trim(),
      );
      await store.updateOperation(updated);
      result = EntryResult(updated);
    } else {
      final op = await store.addOperation(
        type: _type,
        amount: _amount,
        date: _date,
        categoryId: category,
        sourceWalletId: source,
        targetWalletId: target,
        note: _note.text,
      );
      result = EntryResult(op, created: true);
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    final store = StoreScope.read(context);
    final op = widget.existing!;
    await store.deleteOperation(op.id);
    if (mounted) Navigator.of(context).pop(EntryResult(op, deleted: true));
  }

  Future<void> _pickOtherCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.mif.card,
      builder: (_) => _CategoryPicker(kind: _kind, selectedId: _categoryId),
    );
    if (picked != null) setState(() => _categoryId = picked);
  }

  Future<void> _pickDate() async {
    final store = StoreScope.read(context);
    final now = store.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: "Date de l'opération",
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final missing = _missing;
    final title = _editing ? 'Modifier' : 'Nouvelle opération';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _TypeSelector(value: _type, onChanged: _setType),
            ),
            _AmountDisplay(amount: _amount),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  if (_type != OperationType.transfer) ...[
                    _Label('Catégorie'),
                    _CategoryGrid(
                      kind: _kind,
                      selectedId: _categoryId,
                      onSelected: (id) => setState(() => _categoryId = id),
                      onOther: _pickOtherCategory,
                    ),
                    _SubcategoryChips(
                      categoryId: _categoryId,
                      onSelected: (id) => setState(() => _categoryId = id),
                    ),
                    const SizedBox(height: 12),
                    _Label(
                      _type == OperationType.income ? 'Reçu sur' : 'Payé avec',
                    ),
                    _WalletChips(
                      wallets: store.wallets,
                      selectedId: _walletId,
                      onSelected: (id) => setState(() => _walletId = id),
                    ),
                  ] else ...[
                    _Label('De'),
                    _WalletChips(
                      wallets: store.wallets,
                      selectedId: _fromId,
                      onSelected: (id) => setState(() => _fromId = id),
                    ),
                    const SizedBox(height: 12),
                    _Label('Vers'),
                    _WalletChips(
                      wallets: store.wallets,
                      selectedId: _toId,
                      onSelected: (id) => setState(() => _toId = id),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _Label('Date'),
                  _DateChips(
                    date: _date,
                    today: dateOnly(store.now()),
                    onSelected: (d) => setState(() => _date = d),
                    onOther: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Note (facultatif)',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: mif.background,
              padding: const EdgeInsets.fromLTRB(13, 4, 13, 8),
              child: Column(
                children: [
                  AmountKeypad(
                    onDigits: _addDigits,
                    onBackspace: () => setState(() {
                      if (_digits.isNotEmpty) {
                        _digits = _digits.substring(0, _digits.length - 1);
                      }
                    }),
                    onClear: () => setState(() => _digits = ''),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FilledButton(
                      onPressed: missing == null && !_saving ? _save : null,
                      child: Text(missing ?? 'Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: context.mif.textSecondary),
    ),
  );
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final OperationType value;
  final ValueChanged<OperationType> onChanged;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    const types = [
      OperationType.expense,
      OperationType.income,
      OperationType.transfer,
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: mif.track,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final t in types)
            Expanded(
              child: Semantics(
                selected: t == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t == value ? mif.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: t == value
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: t == value ? mif.text : mif.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatAmount(amount),
              key: const Key('montant'),
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: amount == 0 ? mif.textSecondary : mif.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            'FCFA',
            style: TextStyle(fontSize: 14, color: mif.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Les 7 catégories les plus utilisées + « Autre ».
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.kind,
    required this.selectedId,
    required this.onSelected,
    required this.onOther,
  });

  final CategoryKind kind;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final selectedTop = store.topCategory(selectedId);
    final shown = store.frequentCategories(kind, count: 7);
    // Une catégorie choisie via « Autre » prend la dernière place visible.
    if (selectedTop != null && !shown.any((c) => c.id == selectedTop.id)) {
      if (shown.length == 7) shown.removeLast();
      shown.add(selectedTop);
    }
    // Hauteur : marges + pastille + deux lignes de texte (suit la taille de
    // police choisie dans le téléphone).
    final tileHeight = 46 + MediaQuery.textScalerOf(context).scale(27);
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: tileHeight,
      ),
      children: [
        for (final c in shown)
          _CategoryButton(
            category: c,
            selected: selectedTop?.id == c.id,
            onTap: () => onSelected(c.id),
          ),
        _OtherButton(onTap: onOther),
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? mif.greenSoft : mif.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? mif.green : mif.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CategoryBadge(category: category, size: 28),
                const SizedBox(height: 4),
                Flexible(child: _TileLabel(category.name, selected: selected)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nom de catégorie sur deux lignes au plus ; un mot seul trop long
/// (« Communication ») est réduit plutôt que coupé au milieu.
class _TileLabel extends StatelessWidget {
  const _TileLabel(this.text, {required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      height: 1.15,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: context.mif.text,
    );
    if (!text.contains(' ')) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: style),
      );
    }
    return Text(
      text,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _OtherButton extends StatelessWidget {
  const _OtherButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: mif.textSecondary.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps, color: mif.textSecondary),
            const SizedBox(height: 4),
            Text(
              'Autre',
              style: TextStyle(fontSize: 11, color: mif.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryChips extends StatelessWidget {
  const _SubcategoryChips({required this.categoryId, required this.onSelected});

  final String? categoryId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final top = store.topCategory(categoryId);
    if (top == null) return const SizedBox.shrink();
    final subs = store.subcategories(top.id);
    if (subs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final s in subs)
            _Chip(
              label: s.name,
              selected: s.id == categoryId,
              // Toucher à nouveau la sous-catégorie revient à la catégorie.
              onTap: () => onSelected(s.id == categoryId ? top.id : s.id),
            ),
        ],
      ),
    );
  }
}

class _WalletChips extends StatelessWidget {
  const _WalletChips({
    required this.wallets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Wallet> wallets;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    _Chip chip(Wallet w, {bool expand = false}) => _Chip(
      label: w.name,
      icon: walletIcon(w.type),
      selected: w.id == selectedId,
      expand: expand,
      onTap: () => onSelected(w.id),
    );
    // Jusqu'à 3 portefeuilles : tous visibles sur une ligne, même largeur.
    if (wallets.length <= 3) {
      return Row(
        children: [
          for (final (i, w) in wallets.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: chip(w, expand: true)),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [for (final w in wallets) chip(w)],
    );
  }
}

class _DateChips extends StatelessWidget {
  const _DateChips({
    required this.date,
    required this.today,
    required this.onSelected,
    required this.onOther,
  });

  final DateTime date;
  final DateTime today;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final yesterday = today.subtract(const Duration(days: 1));
    final isOther = date != today && date != yesterday;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _Chip(
          label: "Aujourd'hui",
          selected: date == today,
          onTap: () => onSelected(today),
        ),
        _Chip(
          label: 'Hier',
          selected: date == yesterday,
          onTap: () => onSelected(yesterday),
        ),
        _Chip(
          label: isOther ? shortDate(date) : 'Autre date',
          icon: Icons.calendar_today_outlined,
          selected: isOther,
          onTap: onOther,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Occupe toute la largeur donnée ; le texte rétrécit s'il le faut.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? mif.greenSoft : mif.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? mif.green : mif.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expand ? 8 : 14),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? mif.green : mif.textSecondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: mif.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste complète des catégories et sous-catégories.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.kind, required this.selectedId});

  final CategoryKind kind;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final tops = store.topCategories(kind);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Toutes les catégories',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: mif.text,
              ),
            ),
          ),
          for (final c in tops) ...[
            ListTile(
              leading: CategoryBadge(category: c, size: 36),
              title: Text(c.name),
              subtitle: c.group == null ? null : Text(c.group!.label),
              selected: c.id == selectedId,
              onTap: () => Navigator.of(context).pop(c.id),
            ),
            for (final s in store.subcategories(c.id))
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                dense: true,
                title: Text(s.name),
                selected: s.id == selectedId,
                onTap: () => Navigator.of(context).pop(s.id),
              ),
          ],
        ],
      ),
    );
  }
}
