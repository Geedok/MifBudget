import 'package:intl/intl.dart';

/// Espace insécable utilisé comme séparateur de milliers (« 125 000 »).
const String nbsp = ' ';

/// Formate un montant entier en francs CFA : 125000 → « 125 000 ».
String formatAmount(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(nbsp);
    buffer.write(digits[i]);
  }
  return negative ? '−$buffer' : buffer.toString();
}

/// « 125 000 FCFA ».
String formatFcfa(int amount) => '${formatAmount(amount)}${nbsp}FCFA';

/// Montant signé pour une liste d'opérations : « −15 000 », « +650 000 ».
String formatSigned(int amount) {
  if (amount > 0) return '+${formatAmount(amount)}';
  return formatAmount(amount);
}

/// Lit un montant saisi au clavier (« 125 000 », « 125000 ») ; null si vide.
int? parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// « Novembre 2026 ».
String monthLabel(DateTime month) =>
    _capitalize(DateFormat('MMMM y', 'fr_FR').format(month));

/// « Aujourd'hui », « Hier », sinon « Lundi 24 novembre » (avec l'année si
/// elle diffère de l'année en cours).
String dayLabel(DateTime day, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final d = dateOnly(day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  if (diff == -1) return 'Demain';
  final pattern = d.year == today.year ? 'EEEE d MMMM' : 'EEEE d MMMM y';
  return _capitalize(DateFormat(pattern, 'fr_FR').format(d));
}

/// Date courte pour un bouton : « 24 nov. ».
String shortDate(DateTime day) => DateFormat('d MMM', 'fr_FR').format(day);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Clé de mois AAAA-MM, utilisée aussi pour les budgets.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// « octobre ».
String monthName(DateTime month) => DateFormat('MMMM', 'fr_FR').format(month);

/// « nov. » (abréviation française).
String shortMonth(DateTime month) => DateFormat('MMM', 'fr_FR').format(month);

/// Pourcentage arrondi : 0.287 → « 29 % ».
String formatPercent(double ratio) => '${(ratio * 100).round()}$nbsp%';

/// Écart avec le mois précédent : « +50 000 par rapport à octobre »,
/// « −20 000 par rapport à octobre », « Comme en octobre » ; null s'il n'y a
/// rien à comparer.
String? deltaLabel(int current, int previous, DateTime previousMonth) {
  if (previous == 0 && current == 0) return null;
  if (previous == 0) return 'Rien en ${monthName(previousMonth)}';
  final diff = current - previous;
  if (diff == 0) return 'Comme en ${monthName(previousMonth)}';
  return '${formatSigned(diff)} par rapport à ${monthName(previousMonth)}';
}
