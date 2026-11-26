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
  });

  final bool setupDone;

  /// Identifiant du membre qui utilise ce téléphone (auteur des opérations).
  final String memberId;
  final String memberName;
  final ThemeChoice theme;

  AppSettings copyWith({
    bool? setupDone,
    String? memberId,
    String? memberName,
    ThemeChoice? theme,
  }) => AppSettings(
    setupDone: setupDone ?? this.setupDone,
    memberId: memberId ?? this.memberId,
    memberName: memberName ?? this.memberName,
    theme: theme ?? this.theme,
  );

  Map<String, dynamic> toJson() => {
    'installationFaite': setupDone,
    'membre': memberId,
    'prenom': memberName,
    'theme': theme.code,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    setupDone: j['installationFaite'] as bool? ?? false,
    memberId: j['membre'] as String? ?? '',
    memberName: j['prenom'] as String? ?? '',
    theme: ThemeChoice.fromCode(j['theme'] as String?),
  );
}
