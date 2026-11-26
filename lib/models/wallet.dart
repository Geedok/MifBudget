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

/// Portefeuille : espèces, banque ou Mobile Money. Le solde n'est jamais
/// stocké : il est recalculé à partir du solde de départ et des opérations.
class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    this.openingBalance = 0,
    this.shared = true,
    this.ownerId,
    this.monthlyAmount,
    this.archived = false,
    this.sortOrder = 0,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final WalletType type;
  final int openingBalance;

  /// Commun (visible des deux) ou personnel.
  final bool shared;
  final String? ownerId;

  /// Montant mensuel d'un portefeuille personnel (argent personnel).
  final int? monthlyAmount;
  final bool archived;
  final int sortOrder;
  final DateTime updatedAt;

  Wallet copyWith({
    String? name,
    WalletType? type,
    int? openingBalance,
    bool? archived,
    int? sortOrder,
    DateTime? updatedAt,
  }) => Wallet(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    openingBalance: openingBalance ?? this.openingBalance,
    shared: shared,
    ownerId: ownerId,
    monthlyAmount: monthlyAmount,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': name,
    'type': type.code,
    'soldeDepart': openingBalance,
    'commun': shared,
    'proprietaire': ownerId,
    'montantMensuel': monthlyAmount,
    'archive': archived,
    'ordre': sortOrder,
    'modifieLe': updatedAt.toIso8601String(),
  };

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
    id: j['id'] as String,
    name: j['nom'] as String,
    type: WalletType.fromCode(j['type'] as String),
    openingBalance: (j['soldeDepart'] as num?)?.toInt() ?? 0,
    shared: j['commun'] as bool? ?? true,
    ownerId: j['proprietaire'] as String?,
    monthlyAmount: (j['montantMensuel'] as num?)?.toInt(),
    archived: j['archive'] as bool? ?? false,
    sortOrder: (j['ordre'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(j['modifieLe'] as String),
  );
}
