import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/settings.dart';
import '../models/wallet.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'widgets/amount_field.dart';
import 'widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mif = context.mif;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _Header('Vous'),
          MifCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Prénom'),
              subtitle: Text(store.settings.memberName),
              onTap: () => _editName(context, store),
            ),
          ),
          const _Header('Apparence'),
          SegmentedButton<ThemeChoice>(
            showSelectedIcon: false,
            segments: [
              for (final t in ThemeChoice.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {store.settings.theme},
            onSelectionChanged: (s) => store.setTheme(s.first),
          ),
          const _Header('Portefeuilles'),
          MifCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final w in store.wallets)
                  ListTile(
                    leading: Icon(walletIcon(w.type)),
                    title: Text(w.name),
                    subtitle: Text(
                      'Solde de départ : ${formatFcfa(w.openingBalance)}',
                    ),
                    trailing: Text(
                      formatAmount(store.walletBalance(w.id)),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: mif.text,
                      ),
                    ),
                    onTap: () => _editWallet(context, store, w),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Les données sont enregistrées sur ce téléphone. Le partage avec le conjoint arrivera avec la synchronisation (Firebase).",
            style: TextStyle(fontSize: 13, color: mif.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, BudgetStore store) async {
    final controller = TextEditingController(text: store.settings.memberName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Votre prénom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) await store.setMemberName(name);
  }

  Future<void> _editWallet(
    BuildContext context,
    BudgetStore store,
    Wallet wallet,
  ) async {
    final name = TextEditingController(text: wallet.name);
    final opening = TextEditingController(
      text: wallet.openingBalance == 0
          ? ''
          : formatAmount(wallet.openingBalance),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(wallet.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            AmountField(controller: opening, label: 'Solde de départ'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await store.updateWallet(
        wallet.copyWith(
          name: name.text.trim().isEmpty ? wallet.name : name.text.trim(),
          openingBalance: parseAmount(opening.text) ?? 0,
        ),
      );
    }
    name.dispose();
    opening.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.mif.textSecondary,
      ),
    ),
  );
}
