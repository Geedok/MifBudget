import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../core/pin.dart';
import '../state/budget_store.dart';
import '../theme.dart';

/// Délai hors de l'application au-delà duquel le code est redemandé.
const lockAfter = Duration(minutes: 5);

/// Empreinte digitale disponible sur ce téléphone ?
Future<bool> biometricAvailable() async {
  try {
    final auth = LocalAuthentication();
    return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
}

Future<bool> _askBiometric() async {
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: 'Déverrouiller MifBudget',
      biometricOnly: true,
    );
  } catch (_) {
    return false;
  }
}

/// Verrouille l'application à l'ouverture et après [lockAfter] passées
/// ailleurs, quand un code est défini. L'écran de verrouillage recouvre
/// tout (les écrans ouverts restent en place derrière).
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool? _locked;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && DateTime.now().difference(left) >= lockAfter) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = StoreScope.of(context).settings;
    // Verrouillé à l'ouverture si un code existe.
    _locked ??= settings.locked;
    final locked = _locked! && settings.locked;
    return Stack(
      children: [
        // Le contenu reste construit (et ignoré) sous l'écran de code.
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: widget.child),
        ),
        if (locked)
          // L'écran de code est au-dessus du navigateur de l'application :
          // il lui faut sa propre couche (infobulles des boutons).
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => LockScreen(
                    onUnlocked: () => setState(() => _locked = false),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Saisie du code (ou empreinte) pour déverrouiller.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entered = '';
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    if (!StoreScope.read(context).settings.biometric) return;
    if (await _askBiometric() && mounted) widget.onUnlocked();
  }

  void _press(String digit) {
    if (_entered.length >= pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _wrong = false;
      _entered += digit;
    });
    if (_entered.length == pinLength) {
      final s = StoreScope.read(context).settings;
      if (hashPin(_entered, s.pinSalt!) == s.pinHash) {
        widget.onUnlocked();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _wrong = true;
          _entered = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final biometric = StoreScope.of(context).settings.biometric;
    return Material(
      color: mif.background,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_outline, size: 40, color: mif.green),
            const SizedBox(height: 12),
            Text(
              'MifBudget',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: mif.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _wrong ? 'Code incorrect, réessayez' : 'Saisissez votre code',
              style: TextStyle(
                fontSize: 15,
                color: _wrong ? mif.statusOver : mif.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            PinDots(count: _entered.length),
            const Spacer(),
            PinPad(
              onDigit: _press,
              onBackspace: () => setState(() {
                if (_entered.isNotEmpty) {
                  _entered = _entered.substring(0, _entered.length - 1);
                }
              }),
              extra: biometric
                  ? IconButton(
                      tooltip: "Déverrouiller avec l'empreinte",
                      iconSize: 32,
                      icon: Icon(Icons.fingerprint, color: mif.green),
                      onPressed: _tryBiometric,
                    )
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Points du code saisi.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Semantics(
      label: '$count chiffre${count > 1 ? 's' : ''} sur $pinLength',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < pinLength; i++)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < count ? mif.green : Colors.transparent,
                border: Border.all(color: mif.green, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pavé numérique du code : 1–9, [extra] (empreinte), 0, effacer.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.extra,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    Widget key(String d) => SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        key: Key('pin-$d'),
        onPressed: () => onDigit(d),
        child: Text(
          d,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: mif.text,
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 80, height: 64, child: Center(child: extra)),
            key('0'),
            SizedBox(
              width: 80,
              height: 64,
              child: IconButton(
                tooltip: 'Effacer',
                icon: Icon(Icons.backspace_outlined, color: mif.text),
                onPressed: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Définir (deux fois) un nouveau code de verrouillage.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PinSetupScreen(),
    ),
  );

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _entered = '';
  bool _mismatch = false;

  Future<void> _press(String d) async {
    if (_entered.length >= pinLength) return;
    setState(() {
      _mismatch = false;
      _entered += d;
    });
    if (_entered.length < pinLength) return;
    if (_first.isEmpty) {
      setState(() {
        _first = _entered;
        _entered = '';
      });
      return;
    }
    if (_entered != _first) {
      setState(() {
        _mismatch = true;
        _first = '';
        _entered = '';
      });
      return;
    }
    final store = StoreScope.read(context);
    final salt = newPinSalt();
    await store.updateSettings(
      store.settings.copyWith(
        pinSalt: () => salt,
        pinHash: () => hashPin(_entered, salt),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Code de verrouillage'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              _mismatch
                  ? 'Les deux codes diffèrent. Recommencez.'
                  : _first.isEmpty
                  ? 'Choisissez un code à $pinLength chiffres'
                  : 'Saisissez-le une deuxième fois',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _mismatch ? mif.statusOver : mif.text,
              ),
            ),
            const SizedBox(height: 20),
            PinDots(count: _entered.length),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Il sera demandé à l'ouverture et après "
                '${lockAfter.inMinutes} minutes passées hors de MifBudget.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: mif.textSecondary),
              ),
            ),
            const Spacer(),
            PinPad(
              onDigit: _press,
              onBackspace: () => setState(() {
                if (_entered.isNotEmpty) {
                  _entered = _entered.substring(0, _entered.length - 1);
                }
              }),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
