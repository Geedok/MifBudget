import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// Pavé numérique intégré à l'écran, pour saisir un montant sans ouvrir le
/// clavier du téléphone. Touche « 000 » pour aller vite en FCFA.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onDigits,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<String> onDigits;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _Key(
                      key: Key('touche-$key'),
                      label: key,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (key == '⌫') {
                          onBackspace();
                        } else {
                          onDigits(key);
                        }
                      },
                      onLongPress: key == '⌫' ? onClear : null,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mif = context.mif;
    final isBack = label == '⌫';
    return Material(
      color: mif.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 46,
          child: Center(
            child: isBack
                ? Icon(
                    Icons.backspace_outlined,
                    color: mif.text,
                    size: 22,
                    semanticLabel: 'Effacer',
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: mif.text,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
