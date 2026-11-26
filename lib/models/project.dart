enum ProjectStatus {
  planned('prevu', 'Prévu'),
  active('en_cours', 'En cours'),
  done('termine', 'Terminé');

  const ProjectStatus(this.code, this.label);
  final String code;
  final String label;

  static ProjectStatus fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => planned);
}

/// Projet du foyer (ex. : fondations, rentrée scolaire, voyage) : un budget
/// prévu, éventuellement financé par un objectif d'épargne ; ses dépenses
/// sont les opérations marquées avec son identifiant.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.budget,
    this.targetDate,
    this.goalId,
    this.status = ProjectStatus.planned,
    this.archived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// Budget prévu en FCFA.
  final int budget;

  /// Mois visé pour le projet (facultatif).
  final DateTime? targetDate;

  /// Objectif d'épargne qui finance le projet (facultatif).
  final String? goalId;
  final ProjectStatus status;
  final bool archived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project copyWith({
    String? name,
    int? budget,
    DateTime? Function()? targetDate,
    String? Function()? goalId,
    ProjectStatus? status,
    bool? archived,
    DateTime? updatedAt,
  }) => Project(
    id: id,
    name: name ?? this.name,
    budget: budget ?? this.budget,
    targetDate: targetDate != null ? targetDate() : this.targetDate,
    goalId: goalId != null ? goalId() : this.goalId,
    status: status ?? this.status,
    archived: archived ?? this.archived,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': name,
    'budget': budget,
    'dateCible': targetDate?.toIso8601String(),
    'objectifEpargne': goalId,
    'statut': status.code,
    'archive': archived,
    'ordre': sortOrder,
    'creeLe': createdAt.toIso8601String(),
    'modifieLe': updatedAt.toIso8601String(),
  };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String,
    name: j['nom'] as String,
    budget: (j['budget'] as num?)?.toInt() ?? 0,
    targetDate: j['dateCible'] == null
        ? null
        : DateTime.parse(j['dateCible'] as String),
    goalId: j['objectifEpargne'] as String?,
    status: ProjectStatus.fromCode(j['statut'] as String?),
    archived: j['archive'] as bool? ?? false,
    sortOrder: (j['ordre'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(j['creeLe'] as String),
    updatedAt: DateTime.parse(j['modifieLe'] as String),
  );
}
