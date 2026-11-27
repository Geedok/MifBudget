enum ThemeChoice {
  system('systeme', 'Comme le téléphone'),
  light('jour', 'Jour'),
  dark('nuit', 'Nuit');

  const ThemeChoice(this.code, this.label);
  final String code;
  final String label;

  static ThemeChoice fromCode(String? code) =>
      values.firstWhere((t) => t.code == code, orElse: () => system);
}

/// Réglages propres à ce téléphone.
class AppSettings {
  const AppSettings({
    this.setupDone = false,
    this.memberId = '',
    this.memberName = '',
    this.theme = ThemeChoice.system,
    this.personalMoney = false,
    this.allowanceRecurrenceId,
  });

  final bool setupDone;

  /// Identifiant du membre qui utilise ce téléphone (auteur des opérations).
  final String memberId;
  final String memberName;
  final ThemeChoice theme;

  /// Argent personnel activé pour ce membre.
  final bool personalMoney;

  /// Récurrence du versement mensuel d'argent personnel.
  final String? allowanceRecurrenceId;

  AppSettings copyWith({
    bool? setupDone,
    String? memberId,
    String? memberName,
    ThemeChoice? theme,
    bool? personalMoney,
    String? Function()? allowanceRecurrenceId,
  }) => AppSettings(
    setupDone: setupDone ?? this.setupDone,
    memberId: memberId ?? this.memberId,
    memberName: memberName ?? this.memberName,
    theme: theme ?? this.theme,
    personalMoney: personalMoney ?? this.personalMoney,
    allowanceRecurrenceId: allowanceRecurrenceId != null
        ? allowanceRecurrenceId()
        : this.allowanceRecurrenceId,
  );

  Map<String, dynamic> toJson() => {
    'installationFaite': setupDone,
    'membre': memberId,
    'prenom': memberName,
    'theme': theme.code,
    'argentPersonnel': personalMoney,
    'recurrenceArgentPersonnel': allowanceRecurrenceId,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    setupDone: j['installationFaite'] as bool? ?? false,
    memberId: j['membre'] as String? ?? '',
    memberName: j['prenom'] as String? ?? '',
    theme: ThemeChoice.fromCode(j['theme'] as String?),
    personalMoney: j['argentPersonnel'] as bool? ?? false,
    allowanceRecurrenceId: j['recurrenceArgentPersonnel'] as String?,
  );
}
