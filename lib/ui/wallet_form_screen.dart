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
        role: _shared ? _role : WalletRole.current,
        openingBalance: opening,
      );
      await store.updateWallet(result);
    } else {
      result = await store.addWallet(
        name: _name.text,
        type: _type,
        role: _role,
        openingBalance: opening,
        shared: _shared,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  /// Supprimer : pour de bon s'il n'a jamais servi, sinon archivé.
  Future<void> _remove() async {
    final store = StoreScope.read(context);
    final w = widget.existing!;
    final unused = store.walletUnused(w.id);
    final balance = store.walletBalance(w.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          unused ? 'Supprimer « ${w.name} » ?' : 'Retirer « ${w.name} » ?',
        ),
        content: Text(
          unused
              ? "Il n'a jamais servi : il sera supprimé définitivement."
              : [
                  "Il a déjà servi : il sera archivé (retiré des listes, son "
                      "historique est gardé). Vous pourrez le remettre en "
                      "service dans Réglages → Portefeuilles archivés.",
                  if (balance != 0)
                    "Son solde de ${formatFcfa(balance)} ne sera plus compté : "
                        "videz-le d'abord par un transfert si l'argent est "
                        "ailleurs.",
                ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(unused ? 'Supprimer' : 'Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.removeWallet(w.id);
    if (mounted) Navigator.of(context).pop();
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
            label('À qui ?'),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.home_outlined),
                  label: Text('Au foyer'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.lock_outline),
                  label: Text('Argent personnel'),
                ),
              ],
              selected: {_shared},
              // Changer un portefeuille déjà utilisé mélangerait l'argent
              // du foyer et l'argent personnel : on en crée un autre.
              onSelectionChanged: _editing
                  ? null
                  : (s) => setState(() => _shared = s.first),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                _shared
                    ? 'Visible par vous deux, compté dans les chiffres du foyer.'
                    : 'Votre argent de poche : vous seul le voyez, avec ses '
                          'dépenses. Il ne compte pas dans les chiffres du foyer.',
                style: TextStyle(fontSize: 12, color: mif.textSecondary),
              ),
            ),
            if (_shared) ...[
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
                      ? "L'argent de tous les jours : il compte dans l'argent "
                            'disponible.'
                      : "L'argent mis de côté : il ne compte pas dans l'argent "
                            'disponible. Vous pourrez y rattacher un ou '
                            'plusieurs objectifs.',
                  style: TextStyle(fontSize: 12, color: mif.textSecondary),
                ),
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
            if (_editing) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: mif.statusOver,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer ce portefeuille'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Réglages → Portefeuilles archivés : les remettre en service.
class ArchivedWalletsScreen extends StatelessWidget {
  const ArchivedWalletsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ArchivedWalletsScreen()));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    final archived = store.archivedWallets;
    return Scaffold(
      appBar: AppBar(title: const Text('Portefeuilles archivés')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Retirés des listes, avec leur historique. Remettez-en un en '
            'service pour le réutiliser.',
            style: TextStyle(fontSize: 13, color: mif.textSecondary),
          ),
          const SizedBox(height: 12),
          if (archived.isEmpty)
            Text(
              'Aucun portefeuille archivé.',
              style: TextStyle(fontSize: 14, color: mif.textSecondary),
            )
          else
            MifCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final w in archived)
                    ListTile(
                      leading: Icon(walletIcon(w.type)),
                      title: Text(w.name),
                      subtitle: Text(walletDescription(w)),
                      trailing: TextButton(
                        onPressed: () =>
                            store.updateWallet(w.copyWith(archived: false)),
                        child: const Text('Remettre'),
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
