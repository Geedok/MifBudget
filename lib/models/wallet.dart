enum WalletType {
  cash('especes', 'Espèces'),
  bank('banque', 'Banque'),
  mobileMoney('mobile_money', 'Mobile Money');

  const WalletType(this.code, this.label);
  final String code;
  final String label;

  static WalletType fromCode(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => cash);
}

/// Rôle d'un portefeuille : l'argent de tous les jours, ou l'épargne.
enum WalletRole {
  current('courant', 'Courant'),
  savings('epargne', 'Épargne');

  const WalletRole(this.code, this.label);
  final String code;
  final String label;

  static WalletRole fromCode(String? code) =>
      values.firstWhere((r) => r.code == code, orElse: () => current);
}

/// Portefeuille : un compte bancaire, une caisse d'espèces ou un compte
/// Mobile Money. Le solde n'est jamais stocké : il est recalculé à partir du
/// solde de départ et des opérations.
class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    this.role = WalletRole.current,
    this.openingBalance = 0,
    this.shared = true,
    this.ownerId,
    this.private = false,
    this.monthlyAmount,
    this.archived = false,
    this.sortOrder = 0,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final WalletType type;
  final WalletRole role;
  final int openingBalance;

  /// Du foyer (visible des deux, compté dans les chiffres du foyer), ou
  /// argent personnel de [ownerId] : toujours privé, son propriétaire seul
  /// le voit, avec ses opérations.
  final bool shared;
  final String? ownerId;

  /// Ancien interrupteur « privé » (versions 0.4 à 1.0.2) : un portefeuille
  /// personnel est désormais toujours privé. Gardé pour relire les données
  /// et toujours écrit égal à `!shared`.
  final bool private;

  /// Montant mensuel d'un portefeuille personnel (argent personnel).
  final int? monthlyAmount;
  final bool archived;
  final int sortOrder;
  final DateTime updatedAt;

  bool get isSavings => role == WalletRole.savings;

  /// Argent personnel : privé, hors chiffres du foyer.
  bool get isPersonal => !shared;
  bool get isPrivate => !shared;

  Wallet copyWith({
    String? name,
    WalletType? type,
    WalletRole? role,
    int? openingBalance,
    bool? shared,
    String? Function()? ownerId,
    bool? private,
    bool? archived,
    int? sortOrder,
    DateTime? updatedAt,
  }) => Wallet(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    role: role ?? this.role,
    openingBalance: openingBalance ?? this.openingBalance,
    shared: shared ?? this.shared,
    ownerId: ownerId != null ? ownerId() : this.ownerId,
    private: private ?? this.private,
    monthlyAmount: monthlyAmount,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': name,
    'type': type.code,
    'role': role.code,
    'soldeDepart': openingBalance,
    'commun': shared,
    'proprietaire': ownerId,
    'prive': !shared,
    'montantMensuel': monthlyAmount,
    'archive': archived,
    'ordre': sortOrder,
    'modifieLe': updatedAt.toIso8601String(),
  };

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
    id: j['id'] as String,
    name: j['nom'] as String,
    type: WalletType.fromCode(j['type'] as String),
    role: WalletRole.fromCode(j['role'] as String?),
    openingBalance: (j['soldeDepart'] as num?)?.toInt() ?? 0,
    shared: j['commun'] as bool? ?? true,
    ownerId: j['proprietaire'] as String?,
    private: j['prive'] as bool? ?? false,
    monthlyAmount: (j['montantMensuel'] as num?)?.toInt(),
    archived: j['archive'] as bool? ?? false,
    sortOrder: (j['ordre'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(j['modifieLe'] as String),
  );
}
