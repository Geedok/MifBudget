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
    this.householdId,
    this.email,
    this.pinHash,
    this.pinSalt,
    this.biometric = false,
    this.introSeen = false,
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

  /// Foyer partagé (synchronisation) ; null tant que les données restent
  /// sur ce téléphone seulement.
  final String? householdId;

  /// Compte Google connecté.
  final String? email;

  /// Code de verrouillage : empreinte SHA-256 du code salé (jamais le code).
  final String? pinHash;
  final String? pinSalt;

  /// Déverrouiller aussi avec l'empreinte digitale.
  final bool biometric;

  /// Présentation de l'application déjà vue sur ce téléphone.
  final bool introSeen;

  bool get locked => pinHash != null;

  AppSettings copyWith({
    bool? setupDone,
    String? memberId,
    String? memberName,
    ThemeChoice? theme,
    bool? personalMoney,
    String? Function()? allowanceRecurrenceId,
    String? Function()? householdId,
    String? Function()? email,
    String? Function()? pinHash,
    String? Function()? pinSalt,
    bool? biometric,
    bool? introSeen,
  }) => AppSettings(
    setupDone: setupDone ?? this.setupDone,
    memberId: memberId ?? this.memberId,
    memberName: memberName ?? this.memberName,
    theme: theme ?? this.theme,
    personalMoney: personalMoney ?? this.personalMoney,
    allowanceRecurrenceId: allowanceRecurrenceId != null
        ? allowanceRecurrenceId()
        : this.allowanceRecurrenceId,
    householdId: householdId != null ? householdId() : this.householdId,
    email: email != null ? email() : this.email,
    pinHash: pinHash != null ? pinHash() : this.pinHash,
    pinSalt: pinSalt != null ? pinSalt() : this.pinSalt,
    biometric: biometric ?? this.biometric,
    introSeen: introSeen ?? this.introSeen,
  );

  Map<String, dynamic> toJson() => {
    'installationFaite': setupDone,
    'membre': memberId,
    'prenom': memberName,
    'theme': theme.code,
    'argentPersonnel': personalMoney,
    'recurrenceArgentPersonnel': allowanceRecurrenceId,
    'foyer': householdId,
    'email': email,
    'codeEmpreinte': pinHash,
    'codeSel': pinSalt,
    'biometrie': biometric,
    'presentationVue': introSeen,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    setupDone: j['installationFaite'] as bool? ?? false,
    memberId: j['membre'] as String? ?? '',
    memberName: j['prenom'] as String? ?? '',
    theme: ThemeChoice.fromCode(j['theme'] as String?),
    personalMoney: j['argentPersonnel'] as bool? ?? false,
    allowanceRecurrenceId: j['recurrenceArgentPersonnel'] as String?,
    householdId: j['foyer'] as String?,
    email: j['email'] as String?,
    pinHash: j['codeEmpreinte'] as String?,
    pinSalt: j['codeSel'] as String?,
    biometric: j['biometrie'] as bool? ?? false,
    introSeen: j['presentationVue'] as bool? ?? false,
  );
}
