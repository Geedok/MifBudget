import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mifbudget/core/format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('montants groupés par milliers', () {
    expect(formatAmount(0), '0');
    expect(formatAmount(950), '950');
    expect(formatAmount(15000), '15${nbsp}000');
    expect(formatAmount(125000), '125${nbsp}000');
    expect(formatAmount(1500000), '1${nbsp}500${nbsp}000');
    expect(formatAmount(-18500), '−18${nbsp}500');
    expect(formatFcfa(125000), '125${nbsp}000${nbsp}FCFA');
    expect(formatSigned(650000), '+650${nbsp}000');
    expect(formatSigned(-15000), '−15${nbsp}000');
  });

  test('lecture des montants saisis', () {
    expect(parseAmount(''), isNull);
    expect(parseAmount('125 000'), 125000);
    expect(parseAmount('125${nbsp}000 FCFA'), 125000);
  });

  test('libellés de jour et de mois en français', () {
    final now = DateTime(2026, 11, 26, 15);
    expect(dayLabel(DateTime(2026, 11, 26), now: now), "Aujourd'hui");
    expect(dayLabel(DateTime(2026, 11, 25), now: now), 'Hier');
    expect(dayLabel(DateTime(2026, 11, 23), now: now), 'Lundi 23 novembre');
    expect(
      dayLabel(DateTime(2025, 12, 31), now: now),
      'Mercredi 31 décembre 2025',
    );
    expect(monthLabel(DateTime(2026, 11)), 'Novembre 2026');
    expect(monthKey(DateTime(2026, 3, 9)), '2026-03');
  });

  test('écarts et pourcentages', () {
    final oct = DateTime(2026, 10);
    expect(formatPercent(0.287), '29$nbsp%');
    expect(deltaLabel(0, 0, oct), isNull);
    expect(
      deltaLabel(650000, 600000, oct),
      '+50${nbsp}000 par rapport à octobre',
    );
    expect(
      deltaLabel(580000, 600000, oct),
      '−20${nbsp}000 par rapport à octobre',
    );
    expect(deltaLabel(600000, 600000, oct), 'Comme en octobre');
    expect(deltaLabel(45000, 0, oct), 'Rien en octobre');
    expect(shortMonth(DateTime(2026, 11)), 'nov.');
  });
}
