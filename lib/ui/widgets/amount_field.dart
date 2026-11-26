import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';

/// Regroupe les chiffres par milliers pendant la saisie : « 125 000 ».
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = parseAmount(newValue.text);
    if (value == null) return const TextEditingValue();
    final text = formatAmount(value);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Champ de montant en FCFA, avec le clavier numérique du téléphone.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(12),
      ThousandsFormatter(),
    ],
    textAlign: TextAlign.right,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixText: 'FCFA',
      hintText: '0',
    ),
  );
}
