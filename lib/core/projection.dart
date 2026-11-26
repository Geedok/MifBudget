/// Calculs de projection : combien de mois pour atteindre un montant, et à
/// quelle date.
library;

/// Nombre de mois nécessaires pour réunir [remaining] en mettant [perMonth]
/// de côté chaque mois ; 0 si c'est déjà atteint, null si [perMonth] ≤ 0.
int? monthsToReach(int remaining, int perMonth) {
  if (remaining <= 0) return 0;
  if (perMonth <= 0) return null;
  return (remaining / perMonth).ceil();
}

/// Premier jour du mois situé [months] mois après celui de [from].
DateTime addMonths(DateTime from, int months) =>
    DateTime(from.year, from.month + months);

/// Mois (premier jour) où [remaining] sera atteint à raison de [perMonth]
/// par mois, en comptant le mois en cours comme le premier versement ;
/// null si ce n'est jamais atteint à ce rythme.
DateTime? reachDate(DateTime now, int remaining, int perMonth) {
  final months = monthsToReach(remaining, perMonth);
  if (months == null) return null;
  return addMonths(now, months == 0 ? 0 : months - 1);
}

/// Écart en mois entre deux mois (positif si [b] est après [a]).
int monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + b.month - a.month;

/// Moyenne entière d'une liste (0 si vide).
int average(Iterable<int> values) {
  var total = 0;
  var count = 0;
  for (final v in values) {
    total += v;
    count++;
  }
  return count == 0 ? 0 : (total / count).round();
}
