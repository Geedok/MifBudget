import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../models/settings.dart';
import '../state/budget_store.dart';
import '../theme.dart';
import 'categories_screen.dart';
import 'lock.dart';
import 'personal_money.dart';
import 'recurrences_screen.dart';
import 'sync_screen.dart';
import 'wallet_form_screen.dart';
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
          const _Header('Partage et sécurité'),
          MifCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    store.settings.householdId == null
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_outlined,
                  ),
                  title: const Text('Partage du foyer'),
                  subtitle: Text(
                    store.settings.householdId == null
                        ? 'Partager le budget avec votre conjoint'
                        : 'Foyer partagé${store.settings.email == null ? '' : ' · ${store.settings.email}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => SyncScreen.open(context),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Code de verrouillage'),
                  subtitle: Text(
                    store.settings.locked
                        ? 'Activé · demandé à l\'ouverture'
                        : 'Désactivé',
                  ),
                  trailing: store.settings.locked
                      ? TextButton(
                          onPressed: () => store.updateSettings(
                            store.settings.copyWith(
                              pinHash: () => null,
                              pinSalt: () => null,
                              biometric: false,
                            ),
                          ),
                          child: const Text('Retirer'),
                        )
                      : null,
                  onTap: () => PinSetupScreen.open(context),
                ),
                if (store.settings.locked)
                  FutureBuilder<bool>(
                    future: biometricAvailable(),
                    builder: (context, snapshot) => snapshot.data == true
                        ? SwitchListTile(
                            secondary: const Icon(Icons.fingerprint),
                            title: const Text("Déverrouiller avec l'empreinte"),
                            value: store.settings.biometric,
                            onChanged: (v) => store.updateSettings(
                              store.settings.copyWith(biometric: v),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          const _Header('Argent personnel'),
          MifCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(
                store.settings.personalMoney
                    ? 'Argent personnel activé'
                    : "Activer l'argent personnel",
              ),
              subtitle: Text(
                store.allowance == null
                    ? 'Un montant mensuel pour chacun, dépenses privées'
                    : '${formatFcfa(store.allowance!.amount)} le '
                          '${store.allowance!.dayOfMonth == 1 ? '1er' : store.allowance!.dayOfMonth} '
                          'de chaque mois',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => PersonalMoneySetupScreen.open(context),
            ),
          ),
          const _Header('Opérations récurrentes'),
          MifCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Opérations récurrentes'),
              subtitle: Text(
                store.recurrences.isEmpty
                    ? 'Loyer, salaire, abonnements…'
                    : '${store.recurrences.length} en cours',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => RecurrencesScreen.open(context),
            ),
          ),
          const _Header('Catégories'),
          MifCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Catégories et sous-catégories'),
              subtitle: const Text(
                'Créer, renommer, archiver, changer de groupe',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => CategoriesScreen.open(context),
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
                    title: Row(
                      children: [
                        Flexible(child: Text(w.name)),
                        if (w.isPrivate) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            semanticLabel: 'Privé',
                            color: mif.textSecondary,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(walletDescription(w)),
                    trailing: Text(
                      formatAmount(store.walletBalance(w.id)),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: mif.text,
                      ),
                    ),
                    onTap: () => WalletFormScreen.open(context, existing: w),
                  ),
                ListTile(
                  leading: Icon(Icons.add, color: mif.green),
                  title: Text(
                    'Ajouter un portefeuille',
                    style: TextStyle(color: mif.green),
                  ),
                  onTap: () => WalletFormScreen.open(context),
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
