import '../core/format.dart';

enum OperationType {
  expense('depense', 'Dépense'),
  income('revenu', 'Revenu'),
  transfer('transfert', 'Transfert'),
  savingsDeposit('versement_epargne', 'Versement épargne'),
  savingsWithdrawal('retrait_epargne', 'Retrait épargne');

  const OperationType(this.code, this.label);
  final String code;
  final String label;

  bool get isSavings => this == savingsDeposit || this == savingsWithdrawal;

  static OperationType fromCode(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => expense);
}

/// Une opération du foyer. Montant toujours positif, en FCFA entiers ;
/// le sens est donné par le type et les portefeuilles source / cible.
class Operation {
  const Operation({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.categoryId,
    this.sourceWalletId,
    this.targetWalletId,
    this.projectId,
    this.recurrenceId,
    this.savingsGoalId,
    this.note = '',
    this.visibleToPartner = true,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.deletedAt,
  });

  final String id;
  final OperationType type;
  final int amount;

  /// Jour de l'opération (sans heure).
  final DateTime date;
  final String? categoryId;

  /// Dépense et transfert : portefeuille débité.
  final String? sourceWalletId;

  /// Revenu et transfert : portefeuille crédité.
  final String? targetWalletId;
  final String? projectId;

  /// Récurrence qui a produit cette opération (une par mois au plus).
  final String? recurrenceId;
  final String? savingsGoalId;
  final String note;
  final bool visibleToPartner;
  final String authorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Suppression douce, annulable pendant 30 jours.
  final bool deleted;
  final DateTime? deletedAt;

  Operation copyWith({
    OperationType? type,
    int? amount,
    DateTime? date,
    String? Function()? categoryId,
    String? Function()? sourceWalletId,
    String? Function()? targetWalletId,
    String? Function()? savingsGoalId,
    String? Function()? projectId,
    String? Function()? recurrenceId,
    String? note,
    DateTime? updatedAt,
    bool? deleted,
    DateTime? Function()? deletedAt,
  }) => Operation(
    id: id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    sourceWalletId: sourceWalletId != null
        ? sourceWalletId()
        : this.sourceWalletId,
    targetWalletId: targetWalletId != null
        ? targetWalletId()
        : this.targetWalletId,
    projectId: projectId != null ? projectId() : this.projectId,
    recurrenceId: recurrenceId != null ? recurrenceId() : this.recurrenceId,
    savingsGoalId: savingsGoalId != null ? savingsGoalId() : this.savingsGoalId,
    note: note ?? this.note,
    visibleToPartner: visibleToPartner,
    authorId: authorId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.code,
    'montant': amount,
    'date': _day(date),
    'categorie': categoryId,
    'portefeuilleSource': sourceWalletId,
    'portefeuilleCible': targetWalletId,
    'projet': projectId,
    'recurrence': recurrenceId,
    'objectifEpargne': savingsGoalId,
    'note': note,
    'visibleParAutre': visibleToPartner,
    'auteur': authorId,
    'creeLe': createdAt.toIso8601String(),
    'modifieLe': updatedAt.toIso8601String(),
    'supprimee': deleted,
    'supprimeeLe': deletedAt?.toIso8601String(),
  };

  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
    id: j['id'] as String,
    type: OperationType.fromCode(j['type'] as String),
    amount: (j['montant'] as num).toInt(),
    date: DateTime.parse(j['date'] as String),
    categoryId: j['categorie'] as String?,
    sourceWalletId: j['portefeuilleSource'] as String?,
    targetWalletId: j['portefeuilleCible'] as String?,
    projectId: j['projet'] as String?,
    recurrenceId: j['recurrence'] as String?,
    savingsGoalId: j['objectifEpargne'] as String?,
    note: j['note'] as String? ?? '',
    visibleToPartner: j['visibleParAutre'] as bool? ?? true,
    authorId: j['auteur'] as String,
    createdAt: DateTime.parse(j['creeLe'] as String),
    updatedAt: DateTime.parse(j['modifieLe'] as String),
    deleted: j['supprimee'] as bool? ?? false,
    deletedAt: j['supprimeeLe'] == null
        ? null
        : DateTime.parse(j['supprimeeLe'] as String),
  );

  static String _day(DateTime d) =>
      '${monthKey(d)}-${d.day.toString().padLeft(2, '0')}';
}
