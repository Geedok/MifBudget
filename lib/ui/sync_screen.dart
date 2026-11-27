import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../state/budget_store.dart';
import '../sync/app_controller.dart';
import '../sync/household_service.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// Réglages → Partage du foyer : créer le foyer partagé, inviter son
/// conjoint, ou rejoindre le foyer de son conjoint.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SyncScreen()));

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _busy = false;
  String? _error;
  String? _code;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on HouseholdException catch (e) {
      _error = e.message;
    } catch (e) {
      _error =
          'Une erreur est survenue. Vérifiez la connexion internet et '
          'réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final controller = AppScope.maybeOf(context);
    final mif = context.mif;
    final settings = store.settings;
    final text = TextStyle(fontSize: 14, color: mif.textSecondary);

    Widget body;
    if (controller == null) {
      body = Text('Le partage du foyer est indisponible ici.', style: text);
    } else if (controller.needsSignIn) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ce téléphone fait partie d\'un foyer partagé, mais le compte '
            'Google n\'est plus connecté.',
            style: text,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(controller.signInAgain),
            icon: const Icon(Icons.login),
            label: const Text('Se reconnecter avec Google'),
          ),
        ],
      );
    } else if (controller.shared) {
      final names = store.data.memberNames;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MifCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.cloud_done_outlined, color: mif.green),
                  title: const Text('Foyer partagé'),
                  subtitle: Text(
                    names.isEmpty
                        ? 'Synchronisé'
                        : 'Membres : ${names.values.join(', ')}',
                  ),
                ),
                if (settings.email != null)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Compte'),
                    subtitle: Text(settings.email!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Les opérations saisies sur un téléphone apparaissent sur '
            'l\'autre, même saisies hors connexion (elles partent dès que '
            'le réseau revient). Vos portefeuilles privés et vos dépenses '
            'personnelles privées restent sur votre compte seulement.',
            style: text,
          ),
          const SizedBox(height: 20),
          if (_code == null)
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final code = await controller.invite();
                      setState(() => _code = code);
                    }),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Inviter mon conjoint'),
            )
          else
            _InvitationCode(code: _code!),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Partagez le budget avec votre conjoint : chacun sur son '
            'téléphone, avec son compte Google, les mêmes données.',
            style: text,
          ),
          const SizedBox(height: 20),
          _Choice(
            icon: Icons.cloud_upload_outlined,
            title: 'Créer le foyer partagé',
            description:
                'Vos données actuelles deviennent celles du foyer. '
                'Vous inviterez ensuite votre conjoint avec un code.',
            button: 'Se connecter avec Google et créer',
            onPressed: _busy ? null : () => _run(controller.createHousehold),
          ),
          const SizedBox(height: 12),
          _Choice(
            icon: Icons.group_add_outlined,
            title: 'Rejoindre le foyer de mon conjoint',
            description:
                'Avec le code reçu. Les données de ce téléphone sont '
                'remplacées par celles du foyer (une copie de sauvegarde '
                'est gardée).',
            button: 'Saisir le code',
            onPressed: _busy
                ? null
                : () async {
                    final code = await askInvitationCode(context);
                    if (code != null) {
                      await _run(() => controller.joinHousehold(code));
                    }
                  },
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Partage du foyer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          body,
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: mif.statusOver, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(fontSize: 14, color: mif.text),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Demande le code d'invitation (8 caractères).
Future<String?> askInvitationCode(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _CodeDialog());

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _controller.text.replaceAll(RegExp('[^A-Za-z0-9]'), '').length == 8;
    return AlertDialog(
      title: const Text("Code d'invitation"),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 9,
        style: const TextStyle(fontSize: 22, letterSpacing: 3),
        decoration: const InputDecoration(
          hintText: 'ABCD2345',
          counterText: '',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: ready
              ? () => Navigator.pop(context, _controller.text)
              : null,
          child: const Text('Rejoindre'),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.description,
    required this.button,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return MifCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: mif.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: mif.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: mif.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onPressed, child: Text(button)),
        ],
      ),
    );
  }
}

class _InvitationCode extends StatelessWidget {
  const _InvitationCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final spaced = '${code.substring(0, 4)} ${code.substring(4)}';
    return MifCard(
      child: Column(
        children: [
          Text(
            "Code d'invitation",
            style: TextStyle(fontSize: 13, color: mif.textSecondary),
          ),
          const SizedBox(height: 8),
          SelectableText(
            spaced,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: mif.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Valable 7 jours, une seule fois. Sur le téléphone de votre '
            'conjoint : installer MifBudget, puis « Rejoindre le foyer de '
            'mon conjoint » et saisir ce code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: mif.textSecondary),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Code copié')));
            },
            icon: const Icon(Icons.content_copy),
            label: const Text('Copier le code'),
          ),
        ],
      ),
    );
  }
}
