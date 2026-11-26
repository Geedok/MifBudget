/// Objectif d'épargne : une « enveloppe » dans un portefeuille. L'argent ne
/// quitte pas le portefeuille ; il est seulement mis de côté (et retiré du
/// disponible). Le montant épargné n'est jamais stocké : il est recalculé à
/// partir du montant de départ et des versements / retraits.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    this.targetDate,
    this.walletId,
    this.startAmount = 0,
    this.icon = 'epargne',
    this.projectId,
    this.archived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// Montant cible en FCFA.
  final int target;

  /// Date cible facultative (on n'en garde que le mois).
  final DateTime? targetDate;

  /// Portefeuille où se trouve l'argent mis de côté.
  final String? walletId;

  /// Montant déjà épargné à la création de l'objectif.
  final int startAmount;

  /// Clé d'icône (voir `goalIcons`).
  final String icon;
  final String? projectId;
  final bool archived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavingsGoal copyWith({
    String? name,
    int? target,
    DateTime? Function()? targetDate,
    String? Function()? walletId,
    int? startAmount,
    String? icon,
    bool? archived,
    int? sortOrder,
    DateTime? updatedAt,
  }) => SavingsGoal(
    id: id,
    name: name ?? this.name,
    target: target ?? this.target,
    targetDate: targetDate != null ? targetDate() : this.targetDate,
    walletId: walletId != null ? walletId() : this.walletId,
    startAmount: startAmount ?? this.startAmount,
    icon: icon ?? this.icon,
    projectId: projectId,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': name,
    'cible': target,
    'dateCible': targetDate?.toIso8601String(),
    'portefeuille': walletId,
    'montantDepart': startAmount,
    'icone': icon,
    'projet': projectId,
    'archive': archived,
    'ordre': sortOrder,
    'creeLe': createdAt.toIso8601String(),
    'modifieLe': updatedAt.toIso8601String(),
  };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
    id: j['id'] as String,
    name: j['nom'] as String,
    target: (j['cible'] as num?)?.toInt() ?? 0,
    targetDate: j['dateCible'] == null
        ? null
        : DateTime.parse(j['dateCible'] as String),
    walletId: j['portefeuille'] as String?,
    startAmount: (j['montantDepart'] as num?)?.toInt() ?? 0,
    icon: j['icone'] as String? ?? 'epargne',
    projectId: j['projet'] as String?,
    archived: j['archive'] as bool? ?? false,
    sortOrder: (j['ordre'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(j['creeLe'] as String),
    updatedAt: DateTime.parse(j['modifieLe'] as String),
  );
}
