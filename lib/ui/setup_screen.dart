import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../sync/app_controller.dart';
import '../sync/household_service.dart';
import '../theme.dart';
import 'sync_screen.dart';
import 'widgets/amount_field.dart';
import 'widgets/common.dart';
import 'widgets/logo.dart';

/// Première ouverture : prénom et soldes de départ des portefeuilles.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _cash = TextEditingController();
  final _bank = TextEditingController();
  final _mobile = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _cash, _bank, _mobile]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await StoreScope.read(context).completeSetup(
      memberName: _name.text,
      cash: parseAmount(_cash.text) ?? 0,
      bank: parseAmount(_bank.text) ?? 0,
      mobileMoney: parseAmount(_mobile.text) ?? 0,
    );
  }

  Future<void> _join() async {
    final controller = AppScope.maybeOf(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final code = await askInvitationCode(context);
    if (code == null) return;
    setState(() => _saving = true);
    try {
      await controller.joinHousehold(code);
    } on HouseholdException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de rejoindre le foyer. Vérifiez la connexion '
            'internet et réessayez.',
          ),
        ),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Row(
              children: [
                const MifLogo(size: 44),
                const SizedBox(width: 12),
                Text(
                  'MifBudget',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: mif.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Bienvenue',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: mif.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deux informations pour commencer. Tout reste modifiable ensuite dans les Réglages.',
              style: TextStyle(fontSize: 15, color: mif.textSecondary),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Votre prénom'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 28),
            Text(
              "Combien avez-vous aujourd'hui ?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: mif.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ce sont les soldes de départ. Laissez vide si un portefeuille est à zéro.',
              style: TextStyle(fontSize: 13, color: mif.textSecondary),
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _cash,
              label: 'Espèces',
              icon: walletIcon(WalletType.cash),
            ),
            const SizedBox(height: 12),
            AmountField(
              controller: _bank,
              label: 'Banque',
              icon: walletIcon(WalletType.bank),
            ),
            const SizedBox(height: 12),
            AmountField(
              controller: _mobile,
              label: 'Mobile Money',
              icon: walletIcon(WalletType.mobileMoney),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _name.text.trim().isEmpty || _saving ? null : _start,
              child: Text(
                _name.text.trim().isEmpty ? 'Saisir votre prénom' : 'Commencer',
              ),
            ),
            if (AppScope.maybeOf(context) != null) ...[
              const SizedBox(height: 28),
              Text(
                'Votre conjoint utilise déjà MifBudget ?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: mif.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Demandez-lui un code d'invitation (Réglages → Partage du "
                'foyer), puis rejoignez son foyer avec votre compte Google.',
                style: TextStyle(fontSize: 13, color: mif.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _saving ? null : _join,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Rejoindre le foyer de mon conjoint'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
