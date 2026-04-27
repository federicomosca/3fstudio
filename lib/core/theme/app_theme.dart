import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand palette 3F Training ─────────────────────────────────────────────
  static const Color amber    = Color(0xFFC8A84B);  // accento principale (oro caldo)
  static const Color gold     = Color(0xFFE2C069);  // accento secondario (oro chiaro)
  static const Color warmDark = Color(0xFF14100A);  // sfondo scuro, AppBar, NavBar
  static const Color warmBg   = Color(0xFFFAF7ED);  // sfondo light mode
  static const Color white    = Color(0xFFFFFFFF);

  // Backward-compat aliases
  static const Color navy         = warmDark;
  static const Color blue         = amber;
  static const Color cyan         = gold;
  static const Color lightBg      = warmBg;
  static const Color charcoal     = warmDark;
  static const Color lime         = amber;
  static const Color mint         = gold;
  static const Color surface      = warmBg;
  static const Color primaryColor = warmDark;
  static const Color accentColor  = amber;

  // Colori sede (deterministici per indice)
  static const List<Color> sedeColors = [
    amber, Color(0xFFFF8C42), gold, Color(0xFF9C77D4),
  ];
  static Color sedeColor(int index) => sedeColors[index % sedeColors.length];

  // Dark mode surfaces
  static const Color darkSurface = Color(0xFF1C1709);
  static const Color darkBg      = Color(0xFF0E0B04);
  static const Color darkOutline = Color(0xFF2A2310);

  // ── Shared constants ──────────────────────────────────────────────────────
  static const _btnShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );
  static const _btnSize = Size(double.infinity, 52);
  static const _btnText = TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5);

  static const TextTheme _baseText = TextTheme(
    displayLarge:   TextStyle(fontWeight: FontWeight.w900, letterSpacing: -2.0),
    displayMedium:  TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.5),
    displaySmall:   TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0),
    headlineLarge:  TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.8),
    headlineMedium: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
    headlineSmall:  TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
    titleLarge:     TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleMedium:    TextStyle(fontWeight: FontWeight.w600),
    titleSmall:     TextStyle(fontWeight: FontWeight.w700, letterSpacing:  0.1),
    labelLarge:     TextStyle(fontWeight: FontWeight.w700, letterSpacing:  0.3),
    labelMedium:    TextStyle(fontWeight: FontWeight.w600),
    bodyLarge:      TextStyle(fontWeight: FontWeight.w400),
    bodyMedium:     TextStyle(fontWeight: FontWeight.w400),
    bodySmall:      TextStyle(fontWeight: FontWeight.w400),
  );

  static InputDecorationTheme _inputTheme({
    required Color border,
    required Color fill,
    Color focused = amber,
    Color error   = const Color(0xFFD32F2F),
    Color? label,
    Color? hint,
  }) =>
    InputDecorationTheme(
      border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: focused, width: 2)),
      errorBorder:    OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled:    true,
      fillColor: fill,
      labelStyle: label != null ? TextStyle(color: label) : null,
      hintStyle:  hint  != null ? TextStyle(color: hint)  : null,
    );

  static NavigationBarThemeData _navBar({
    required Color bg,
    required Color selected,
    required Color unselected,
    required Color indicator,
  }) =>
    NavigationBarThemeData(
      backgroundColor: bg,
      elevation: 0,
      height:    64,
      indicatorColor: indicator,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? selected : unselected,
        size: 24,
      )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final sel = states.contains(WidgetState.selected);
        return TextStyle(
          color: sel ? selected : unselected,
          fontSize: 11,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    );

  // ── LIGHT theme ───────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: warmBg,
    colorScheme: const ColorScheme(
      brightness:              Brightness.light,
      primary:                 warmDark,
      onPrimary:               white,
      primaryContainer:        Color(0xFFEEDFB0),
      onPrimaryContainer:      warmDark,
      secondary:               amber,
      onSecondary:             white,
      secondaryContainer:      Color(0xFFF5E8B8),
      onSecondaryContainer:    Color(0xFF3A2A00),
      tertiary:                gold,
      onTertiary:              Color(0xFF3A2A00),
      tertiaryContainer:       Color(0xFFF8EFC8),
      onTertiaryContainer:     Color(0xFF3A2A00),
      error:                   Color(0xFFD32F2F),
      onError:                 white,
      errorContainer:          Color(0xFFFFEBEE),
      onErrorContainer:        Color(0xFFB71C1C),
      surface:                 white,
      onSurface:               warmDark,
      surfaceContainerHighest: Color(0xFFF0E8C8),
      outline:                 Color(0xFFD4C080),
      outlineVariant:          Color(0xFFE8D8A0),
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          warmDark,
      onInverseSurface:        white,
      inversePrimary:          amber,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: warmDark,
      foregroundColor: white,
      centerTitle:     false,
      elevation:       0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness:     Brightness.dark,
      ),
      titleTextStyle: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      iconTheme:        IconThemeData(color: white),
      actionsIconTheme: IconThemeData(color: white),
    ),
    navigationBarTheme: _navBar(
      bg:        warmDark,
      selected:  amber,
      unselected: const Color(0xFF9A8040),
      indicator:  const Color(0x33C8A84B),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color:     white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD4C080)),
      ),
    ),
    inputDecorationTheme: _inputTheme(border: const Color(0xFFD4C080), fill: white),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: warmDark, foregroundColor: white,
        minimumSize: _btnSize, shape: _btnShape, elevation: 0, textStyle: _btnText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: amber, foregroundColor: white,
        minimumSize: _btnSize, shape: _btnShape, textStyle: _btnText,
      ),
    ),
    textButtonTheme:    TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: amber)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: warmDark,
        side:  const BorderSide(color: warmDark, width: 1.5),
        shape: _btnShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: amber, foregroundColor: white, elevation: 2,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:           white,
      unselectedLabelColor: Color(0xFF9A8040),
      indicatorColor:       amber,
      dividerColor:         Colors.transparent,
    ),
    chipTheme:    const ChipThemeData(shape: StadiumBorder()),
    dividerTheme: const DividerThemeData(color: Color(0xFFE8D8A0), thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
    textTheme: _baseText,
  );

  // ── DARK theme ────────────────────────────────────────────────────────────
  static const Color _darkAccent = Color(0xFFD4A84B);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme(
      brightness:              Brightness.dark,
      primary:                 _darkAccent,
      onPrimary:               Color(0xFF1A1000),
      primaryContainer:        Color(0xFF2A2000),
      onPrimaryContainer:      Color(0xFFEDD08A),
      secondary:               gold,
      onSecondary:             Color(0xFF1A1000),
      secondaryContainer:      Color(0xFF2A2000),
      onSecondaryContainer:    gold,
      tertiary:                gold,
      onTertiary:              Color(0xFF1A1000),
      tertiaryContainer:       Color(0xFF2A2000),
      onTertiaryContainer:     gold,
      error:                   Color(0xFFCF6679),
      onError:                 Color(0xFF690020),
      errorContainer:          Color(0xFF93000A),
      onErrorContainer:        Color(0xFFFFDAD6),
      surface:                 darkSurface,
      onSurface:               white,
      surfaceContainerHighest: Color(0xFF241D08),
      outline:                 darkOutline,
      outlineVariant:          Color(0xFF221C08),
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          white,
      onInverseSurface:        warmDark,
      inversePrimary:          warmDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0800),
      foregroundColor: white,
      centerTitle:     false,
      elevation:       0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness:     Brightness.dark,
      ),
      titleTextStyle: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      iconTheme:        IconThemeData(color: white),
      actionsIconTheme: IconThemeData(color: white),
    ),
    navigationBarTheme: _navBar(
      bg:        const Color(0xFF0A0800),
      selected:  _darkAccent,
      unselected: const Color(0xFF6A5A30),
      indicator:  const Color(0x33D4A84B),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color:     darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: darkOutline),
      ),
    ),
    inputDecorationTheme: _inputTheme(
      border:  darkOutline,
      fill:    darkSurface,
      focused: _darkAccent,
      error:   const Color(0xFFCF6679),
      label:   const Color(0xFF8A7040),
      hint:    const Color(0xFF5A4820),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkAccent, foregroundColor: const Color(0xFF1A1000),
        minimumSize: _btnSize, shape: _btnShape, elevation: 0, textStyle: _btnText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _darkAccent, foregroundColor: const Color(0xFF1A1000),
        minimumSize: _btnSize, shape: _btnShape, textStyle: _btnText,
      ),
    ),
    textButtonTheme:    TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _darkAccent)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _darkAccent,
        side:  const BorderSide(color: _darkAccent, width: 1.5),
        shape: _btnShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _darkAccent, foregroundColor: Color(0xFF1A1000), elevation: 2,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:           white,
      unselectedLabelColor: Color(0xFF6A5A30),
      indicatorColor:       _darkAccent,
      dividerColor:         Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      shape:           const StadiumBorder(),
      backgroundColor: const Color(0xFF1A1505),
      selectedColor:   _darkAccent.withAlpha(50),
      side:            const BorderSide(color: darkOutline),
      labelStyle:      const TextStyle(color: white),
    ),
    dividerTheme:  const DividerThemeData(color: Color(0xFF221C08), thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor:  darkSurface,
      textColor:  white,
      iconColor:  Color(0xFF8A7040),
    ),
    textTheme: _baseText.apply(bodyColor: white, displayColor: white).copyWith(
      bodySmall: const TextStyle(fontWeight: FontWeight.w400, color: Color(0xFFD0A840)),
    ),
  );
}
