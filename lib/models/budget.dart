/// Plafond de dépenses d'une catégorie principale pour un mois.
///
/// L'identifiant est déterminé par le mois et la catégorie : les deux
/// téléphones écrivent donc le même document pour le même budget. Un plafond
/// à 0 signifie « pas de budget ».
class Budget {
  const Budget({
    required this.categoryId,
    required this.month,
    required this.limit,
    required this.updatedAt,
  });

  final String categoryId;

  /// Mois au format AAAA-MM.
  final String month;

  /// Plafond en FCFA (0 : pas de budget).
  final int limit;
  final DateTime updatedAt;

  String get id => idFor(month, categoryId);

  static String idFor(String month, String categoryId) => '$month:$categoryId';

  Map<String, dynamic> toJson() => {
    'id': id,
    'categorie': categoryId,
    'mois': month,
    'plafond': limit,
    'modifieLe': updatedAt.toIso8601String(),
  };

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
    categoryId: j['categorie'] as String,
    month: j['mois'] as String,
    limit: (j['plafond'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(j['modifieLe'] as String),
  );
}

/// État d'un budget : vert sous 80 %, orange de 80 à 100 %, rouge au-delà.
enum BudgetStatus { ok, warning, over }

BudgetStatus budgetStatus(int spent, int limit) {
  if (limit <= 0) return BudgetStatus.ok;
  if (spent > limit) return BudgetStatus.over;
  if (spent >= limit * 0.8) return BudgetStatus.warning;
  return BudgetStatus.ok;
}
