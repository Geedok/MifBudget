import 'package:material_ui/material_ui.dart';

/// Couleurs de la charte MifBudget qui ne rentrent pas dans le ColorScheme.
@immutable
class MifColors extends ThemeExtension<MifColors> {
  const MifColors({
    required this.green,
    required this.terracotta,
    required this.background,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.border,
    required this.track,
    required this.greenSoft,
    required this.income,
    required this.chartIncome,
    required this.chartExpense,
    required this.statusOk,
    required this.statusWarning,
    required this.statusWarningText,
    required this.statusOver,
  });

  final Color green;
  final Color terracotta;
  final Color background;
  final Color card;
  final Color text;
  final Color textSecondary;
  final Color border;

  /// Fond des barres de progression et des sélecteurs.
  final Color track;

  /// Fond d'un élément sélectionné.
  final Color greenSoft;

  /// Couleur des montants de revenus.
  final Color income;

  /// Barres des graphiques revenus / dépenses (variantes de la charte
  /// vérifiées pour le daltonisme et le contraste).
  final Color chartIncome;
  final Color chartExpense;

  /// États des budgets (toujours accompagnés d'un libellé et d'une icône) :
  /// vert sous 80 %, orange de 80 à 100 %, rouge « Dépassé ».
  final Color statusOk;
  final Color statusWarning;

  /// Orange assez foncé pour du texte sur une carte.
  final Color statusWarningText;
  final Color statusOver;

  static const light = MifColors(
    green: Color(0xFF1F6B4F),
    terracotta: Color(0xFFB4531A),
    background: Color(0xFFF5F6F3),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF1C2420),
    textSecondary: Color(0xFF5B6660),
    border: Color(0xFFD9DED9),
    track: Color(0xFFE6EAE6),
    greenSoft: Color(0xFFE8F2ED),
    income: Color(0xFF1F6B4F),
    chartIncome: Color(0xFF14805A),
    chartExpense: Color(0xFFB4531A),
    statusOk: Color(0xFF1F6B4F),
    statusWarning: Color(0xFFC26A1E),
    statusWarningText: Color(0xFF9A4A12),
    statusOver: Color(0xFFB3261E),
  );

  static const dark = MifColors(
    green: Color(0xFF5CC197),
    terracotta: Color(0xFFE5884E),
    background: Color(0xFF101513),
    card: Color(0xFF1A211E),
    text: Color(0xFFE6ECE8),
    textSecondary: Color(0xFF9DAAA3),
    border: Color(0xFF2C3632),
    track: Color(0xFF26302C),
    greenSoft: Color(0xFF1C3A2E),
    income: Color(0xFF5CC197),
    chartIncome: Color(0xFF3FAE82),
    chartExpense: Color(0xFFD9783E),
    statusOk: Color(0xFF5CC197),
    statusWarning: Color(0xFFF0A35E),
    statusWarningText: Color(0xFFF0A35E),
    statusOver: Color(0xFFF2827A),
  );

  @override
  MifColors copyWith() => this;

  @override
  MifColors lerp(MifColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MifColors(
      green: l(green, other.green),
      terracotta: l(terracotta, other.terracotta),
      background: l(background, other.background),
      card: l(card, other.card),
      text: l(text, other.text),
      textSecondary: l(textSecondary, other.textSecondary),
      border: l(border, other.border),
      track: l(track, other.track),
      greenSoft: l(greenSoft, other.greenSoft),
      income: l(income, other.income),
      chartIncome: l(chartIncome, other.chartIncome),
      chartExpense: l(chartExpense, other.chartExpense),
      statusOk: l(statusOk, other.statusOk),
      statusWarning: l(statusWarning, other.statusWarning),
      statusWarningText: l(statusWarningText, other.statusWarningText),
      statusOver: l(statusOver, other.statusOver),
    );
  }
}

extension MifTheme on BuildContext {
  MifColors get mif => Theme.of(this).extension<MifColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? MifColors.light : MifColors.dark;
  final onGreen = brightness == Brightness.light
      ? Colors.white
      : const Color(0xFF0B1F17);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.green,
    onPrimary: onGreen,
    secondary: c.terracotta,
    onSecondary: brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF2A1405),
    error: brightness == Brightness.light
        ? const Color(0xFFB3261E)
        : const Color(0xFFF2B8B5),
    onError: brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF601410),
    surface: c.card,
    onSurface: c.text,
    onSurfaceVariant: c.textSecondary,
    outline: c.border,
    outlineVariant: c.track,
    surfaceContainerHighest: c.track,
    surfaceContainerHigh: c.card,
    surfaceContainer: c.card,
    surfaceContainerLow: c.background,
    surfaceContainerLowest: c.background,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: c.background,
  );
  return base.copyWith(
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.greenSoft,
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? c.green
              : c.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? c.green
              : c.textSecondary,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.terracotta,
      foregroundColor: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF2A1405),
      shape: const CircleBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.green, width: 2),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.greenSoft
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.text : c.textSecondary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: c.track, thickness: 1, space: 1),
  );
}
