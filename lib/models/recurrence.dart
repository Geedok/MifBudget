import 'operation.dart';

/// Opération qui revient chaque mois (loyer, salaire, abonnement, virement
/// d'épargne). Chaque mois produit au plus une opération, reconnue par son
/// champ `recurrence` ; « à confirmer » par défaut, ou automatique.
class Recurrence {
  const Recurrence({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.sourceWalletId,
    this.targetWalletId,
    this.savingsGoalId,
    this.projectId,
    this.note = '',
    required this.dayOfMonth,
    required this.startMonth,
    this.endMonth,
    this.automatic = false,
    this.paused = false,
    this.stopped = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final OperationType type;
  final int amount;
  final String? categoryId;
  final String? sourceWalletId;
  final String? targetWalletId;
  final String? savingsGoalId;
  final String? projectId;
  final String note;

  /// Jour du mois (1 à 31 ; ramené au dernier jour pour les mois courts).
  final int dayOfMonth;

  /// Premier mois concerné (premier jour du mois).
  final DateTime startMonth;

  /// Dernier mois concerné, compris (facultatif).
  final DateTime? endMonth;

  /// Enregistrée toute seule le jour venu ; sinon à confirmer.
  final bool automatic;

  /// Mise en pause : rien n'est proposé tant qu'elle l'est.
  final bool paused;

  /// Arrêtée définitivement (gardée pour l'historique).
  final bool stopped;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get active => !paused && !stopped;

  /// Date de l'échéance d'un mois.
  DateTime dateIn(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(
      month.year,
      month.month,
      dayOfMonth > last ? last : dayOfMonth,
    );
  }

  /// La récurrence s'applique-t-elle à ce mois ?
  bool covers(DateTime month) {
    final m = month.year * 12 + month.month;
    if (m < startMonth.year * 12 + startMonth.month) return false;
    final end = endMonth;
    return end == null || m <= end.year * 12 + end.month;
  }

  /// Identifiant de l'opération d'un mois : le même sur les deux téléphones,
  /// pour ne jamais l'enregistrer deux fois.
  String operationIdFor(DateTime month) =>
      'rec-$id-${month.year}-${month.month.toString().padLeft(2, '0')}';

  Recurrence copyWith({
    OperationType? type,
    int? amount,
    String? Function()? categoryId,
    String? Function()? sourceWalletId,
    String? Function()? targetWalletId,
    String? Function()? savingsGoalId,
    String? Function()? projectId,
    String? note,
    int? dayOfMonth,
    DateTime? startMonth,
    DateTime? Function()? endMonth,
    bool? automatic,
    bool? paused,
    bool? stopped,
    DateTime? updatedAt,
  }) => Recurrence(
    id: id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    sourceWalletId: sourceWalletId != null
        ? sourceWalletId()
        : this.sourceWalletId,
    targetWalletId: targetWalletId != null
        ? targetWalletId()
        : this.targetWalletId,
    savingsGoalId: savingsGoalId != null ? savingsGoalId() : this.savingsGoalId,
    projectId: projectId != null ? projectId() : this.projectId,
    note: note ?? this.note,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    startMonth: startMonth ?? this.startMonth,
    endMonth: endMonth != null ? endMonth() : this.endMonth,
    automatic: automatic ?? this.automatic,
    paused: paused ?? this.paused,
    stopped: stopped ?? this.stopped,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.code,
    'montant': amount,
    'categorie': categoryId,
    'portefeuilleSource': sourceWalletId,
    'portefeuilleCible': targetWalletId,
    'objectifEpargne': savingsGoalId,
    'projet': projectId,
    'note': note,
    'jour': dayOfMonth,
    'debut': startMonth.toIso8601String(),
    'fin': endMonth?.toIso8601String(),
    'automatique': automatic,
    'enPause': paused,
    'arretee': stopped,
    'creeLe': createdAt.toIso8601String(),
    'modifieLe': updatedAt.toIso8601String(),
  };

  factory Recurrence.fromJson(Map<String, dynamic> j) => Recurrence(
    id: j['id'] as String,
    type: OperationType.fromCode(j['type'] as String),
    amount: (j['montant'] as num).toInt(),
    categoryId: j['categorie'] as String?,
    sourceWalletId: j['portefeuilleSource'] as String?,
    targetWalletId: j['portefeuilleCible'] as String?,
    savingsGoalId: j['objectifEpargne'] as String?,
    projectId: j['projet'] as String?,
    note: j['note'] as String? ?? '',
    dayOfMonth: (j['jour'] as num).toInt(),
    startMonth: DateTime.parse(j['debut'] as String),
    endMonth: j['fin'] == null ? null : DateTime.parse(j['fin'] as String),
    automatic: j['automatique'] as bool? ?? false,
    paused: j['enPause'] as bool? ?? false,
    stopped: j['arretee'] as bool? ?? false,
    createdAt: DateTime.parse(j['creeLe'] as String),
    updatedAt: DateTime.parse(j['modifieLe'] as String),
  );
}
