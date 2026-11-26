enum CategoryKind {
  expense('depense'),
  income('revenu');

  const CategoryKind(this.code);
  final String code;

  static CategoryKind fromCode(String code) =>
      values.firstWhere((k) => k.code == code, orElse: () => expense);
}

enum CategoryGroup {
  essential('essentiel', 'Essentiel'),
  comfort('confort', 'Confort');

  const CategoryGroup(this.code, this.label);
  final String code;
  final String label;

  static CategoryGroup? fromCode(String? code) {
    for (final g in values) {
      if (g.code == code) return g;
    }
    return null;
  }
}

/// Catégorie ou sous-catégorie (quand [parentId] est renseigné).
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.group,
    this.parentId,
    required this.icon,
    required this.color,
    this.archived = false,
    this.sortOrder = 0,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final CategoryKind kind;
  final CategoryGroup? group;
  final String? parentId;

  /// Clé d'icône (voir `categoryIcons`).
  final String icon;

  /// Couleur ARGB.
  final int color;
  final bool archived;
  final int sortOrder;
  final DateTime updatedAt;

  bool get isSub => parentId != null;

  Category copyWith({
    String? name,
    CategoryGroup? Function()? group,
    String? icon,
    int? color,
    bool? archived,
    int? sortOrder,
    DateTime? updatedAt,
  }) => Category(
    id: id,
    name: name ?? this.name,
    kind: kind,
    group: group != null ? group() : this.group,
    parentId: parentId,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': name,
    'type': kind.code,
    'groupe': group?.code,
    'parente': parentId,
    'icone': icon,
    'couleur': color,
    'archivee': archived,
    'ordre': sortOrder,
    'modifieLe': updatedAt.toIso8601String(),
  };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] as String,
    name: j['nom'] as String,
    kind: CategoryKind.fromCode(j['type'] as String),
    group: CategoryGroup.fromCode(j['groupe'] as String?),
    parentId: j['parente'] as String?,
    icon: j['icone'] as String? ?? 'divers',
    color: (j['couleur'] as num?)?.toInt() ?? 0xFF5B6660,
    archived: j['archivee'] as bool? ?? false,
    sortOrder: (j['ordre'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(j['modifieLe'] as String),
  );
}
