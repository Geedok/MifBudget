import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'widgets/amount_field.dart';
import 'widgets/common.dart';

/// Création ou modification d'un portefeuille : nom, type, rôle (courant ou
/// épargne), commun ou personnel (privé ou visible), solde de départ.
class WalletFormScreen extends StatefulWidget {
  const WalletFormScreen({
    super.key,
    this.existing,
    this.initialRole = WalletRole.current,
  });

  final Wallet? existing;
  final WalletRole initialRole;

  static Future<Wallet?> open(
    BuildContext context, {
    Wallet? existing,
    WalletRole initialRole = WalletRole.current,
  }) => Navigator.of(context).push<Wallet>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          WalletFormScreen(existing: existing, initialRole: initialRole),
    ),
  );

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _opening;
  late WalletType _type;
  late WalletRole _role;
  late bool _shared;
  late bool _private;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _opening = TextEditingController(
      text: (e?.openingBalance ?? 0) == 0
          ? ''
          : formatAmount(e!.openingBalance),
    );
    _type = e?.type ?? WalletType.bank;
    _role = e?.role ?? widget.initialRole;
    _shared = e?.shared ?? true;
    _private = e?.private ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final opening = parseAmount(_opening.text) ?? 0;
    final Wallet result;
    if (_editing) {
      final e = widget.existing!;
      result = e.copyWith(
        name: _name.text.trim(),
        type: _type,
        role: _role,
        openingBalance: opening,
        shared: _shared,
        ownerId: () => _shared ? null : (e.ownerId ?? store.settings.memberId),
        private: !_shared && _private,
      );
      await store.updateWallet(result);
    } else {
      result = await store.addWallet(
        name: _name.text,
        type: _type,
        role: _role,
        openingBalance: opening,
        shared: _shared,
        private: _private,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _archive() async {
    final store = StoreScope.read(context);
    final w = widget.existing!;
    final balance = store.walletBalance(w.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archiver « ${w.name} » ?'),
        content: Text(
          balance != 0
              ? "Son solde est de ${formatFcfa(balance)} : il ne sera plus compté. Videz-le d'abord par un transfert si l'argent est ailleurs. L'historique est conservé."
              : "Il disparaîtra des listes. L'historique est conservé.",
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
    final archived = w.copyWith(archived: true);
    await store.updateWallet(archived);
    if (mounted) Navigator.of(context).pop(archived);
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          _editing ? 'Modifier le portefeuille' : 'Nouveau portefeuille',
        ),
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
                hintText: 'Ex. : Compte salaire, Compte épargne, Wave',
              ),
            ),
            label('Type'),
            SegmentedButton<WalletType>(
              showSelectedIcon: false,
              segments: [
                for (final t in WalletType.values)
                  ButtonSegment(
                    value: t,
                    icon: Icon(walletIcon(t)),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(t.label),
                    ),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            label('Rôle'),
            SegmentedButton<WalletRole>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: WalletRole.current,
                  label: Text('Courant'),
                ),
                ButtonSegment(
                  value: WalletRole.savings,
                  label: Text('Épargne'),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                _role == WalletRole.current
                    ? "L'argent de tous les jours : il compte dans le disponible."
                    : "L'argent mis de côté : il ne compte pas dans le disponible. "
                          'Vous pourrez y rattacher un ou plusieurs objectifs.',
                style: TextStyle(fontSize: 12, color: mif.textSecondary),
              ),
            ),
            label('À qui ?'),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Commun au foyer')),
                ButtonSegment(value: false, label: Text('Personnel')),
              ],
              selected: {_shared},
              onSelectionChanged: (s) => setState(() => _shared = s.first),
            ),
            if (!_shared) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Privé'),
                subtitle: Text(
                  _private
                      ? 'Vous seul verrez ce portefeuille et ses opérations.'
                      : 'Votre conjoint pourra le voir.',
                ),
                value: _private,
                onChanged: (v) => setState(() => _private = v),
              ),
            ],
            const SizedBox(height: 20),
            AmountField(controller: _opening, label: 'Solde de départ'),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                "Le montant sur ce portefeuille avant les opérations saisies dans l'application.",
                style: TextStyle(fontSize: 12, color: mif.textSecondary),
              ),
            ),
            const SizedBox(height: 28),
            ListenableBuilder(
              listenable: _name,
              builder: (context, _) => FilledButton(
                onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
                child: Text(
                  _name.text.trim().isEmpty ? 'Donner un nom' : 'Enregistrer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
