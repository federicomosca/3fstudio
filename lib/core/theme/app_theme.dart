import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand palette 3F Training ────────────────────────────────────────────
  static const Color navy    = Color(0xFF0A1726);  // sfondo scuro, AppBar, NavBar
  static const Color blue    = Color(0xFF0081C8);  // accento principale
  static const Color cyan    = Color(0xFF50C0D0);  // accento secondario
  static const Color lightBg = Color(0xFFEDF2F8);  // sfondo light mode
  static const Color white   = Color(0xFFFFFFFF);

  // Backward-compat aliases
  static const Color charcoal    = navy;
  static const Color lime        = blue;
  static const Color mint        = cyan;
  static const Color surface     = lightBg;
  static const Color primaryColor = navy;
  static const Color accentColor  = blue;

  // Colori per sede (deterministici per indice)
  static const List<Color> sedeColors = [
    blue,                  // sede 0
    Color(0xFFFF8C42),     // arancio  — sede 1
    cyan,                  // teal     — sede 2
    Color(0xFF9C77D4),     // viola    — sede 3
  ];
  static Color sedeColor(int index) => sedeColors[index % sedeColors.length];

  // Dark mode surfaces
  static const Color darkSurface = Color(0xFF0D1A27);
  static const Color darkBg      = Color(0xFF060E18);
  static const Color darkOutline = Color(0xFF1A2E42);

  // ── LIGHT theme ──────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme(
      brightness:              Brightness.light,
      primary:                 navy,
      onPrimary:               white,
      primaryContainer:        Color(0xFFBDD8EE),
      onPrimaryContainer:      navy,
      secondary:               blue,
      onSecondary:             white,
      secondaryContainer:      Color(0xFFB8E0F5),
      onSecondaryContainer:    Color(0xFF003A5C),
      tertiary:                cyan,
      onTertiary:              white,
      tertiaryContainer:       Color(0xFFBCEEF5),
      onTertiaryContainer:     Color(0xFF003A42),
      error:                   Color(0xFFD32F2F),
      onError:                 white,
      errorContainer:          Color(0xFFFFEBEE),
      onErrorContainer:        Color(0xFFB71C1C),
      surface:                 white,
      onSurface:               navy,
      surfaceContainerHighest: Color(0xFFDCEAF5),
      outline:                 Color(0xFFADC6DC),
      outlineVariant:          Color(0xFFD0E3EF),
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          navy,
      onInverseSurface:        white,
      inversePrimary:          blue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:    navy,
      foregroundColor:    white,
      centerTitle:        false,
      elevation:          0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness:     Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        color: white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3,
      ),
      iconTheme:        IconThemeData(color: white),
      actionsIconTheme: IconThemeData(color: white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navy,
      elevation:       0,
      height:          64,
      indicatorColor:  Color(0x330081C8),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? blue : const Color(0xFF6A90A8),
          size:  24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color:      selected ? blue : const Color(0xFF6A90A8),
          fontSize:   11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color:     white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFADC6DC)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFADC6DC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFADC6DC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled:    true,
      fillColor: white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: white,
        minimumSize:     const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: white,
        minimumSize:     const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: blue),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy,
        side: const BorderSide(color: navy, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: blue,
      foregroundColor: white,
      elevation:       2,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:           white,
      unselectedLabelColor: Color(0xFF8AAFC4),
      indicatorColor:       blue,
      dividerColor:         Colors.transparent,
    ),
    chipTheme: const ChipThemeData(shape: StadiumBorder()),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFD0E3EF), thickness: 1, space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    textTheme: const TextTheme(
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
    ),
  );

  // ── DARK theme ──────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    colorScheme: ColorScheme(
      brightness:              Brightness.dark,
      primary:                 const Color(0xFF29A8E8),   // blue chiaro per dark mode
      onPrimary:               const Color(0xFF001E30),
      primaryContainer:        const Color(0xFF00334D),
      onPrimaryContainer:      const Color(0xFF8ED4F5),
      secondary:               cyan,
      onSecondary:             const Color(0xFF001E25),
      secondaryContainer:      const Color(0xFF003040),
      onSecondaryContainer:    cyan,
      tertiary:                cyan,
      onTertiary:              const Color(0xFF001E25),
      tertiaryContainer:       const Color(0xFF003040),
      onTertiaryContainer:     cyan,
      error:                   const Color(0xFFCF6679),
      onError:                 const Color(0xFF690020),
      errorContainer:          const Color(0xFF93000A),
      onErrorContainer:        const Color(0xFFFFDAD6),
      surface:                 darkSurface,
      onSurface:               white,
      surfaceContainerHighest: const Color(0xFF112030),
      outline:                 darkOutline,
      outlineVariant:          const Color(0xFF142030),
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          white,
      onInverseSurface:        navy,
      inversePrimary:          navy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:    Color(0xFF080F18),
      foregroundColor:    white,
      centerTitle:        false,
      elevation:          0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness:     Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        color: white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3,
      ),
      iconTheme:        IconThemeData(color: white),
      actionsIconTheme: IconThemeData(color: white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF080F18),
      elevation:       0,
      height:          64,
      indicatorColor:  const Color(0xFF29A8E8).withAlpha(50),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? const Color(0xFF29A8E8) : const Color(0xFF4A7090),
          size:  24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color:      selected ? const Color(0xFF29A8E8) : const Color(0xFF4A7090),
          fontSize:   11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color:     darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: darkOutline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF29A8E8), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCF6679)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled:    true,
      fillColor: darkSurface,
      labelStyle:  const TextStyle(color: Color(0xFF5A8AAA)),
      hintStyle:   const TextStyle(color: Color(0xFF3A6080)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF29A8E8),
        foregroundColor: const Color(0xFF001E30),
        minimumSize:     const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF29A8E8),
        foregroundColor: const Color(0xFF001E30),
        minimumSize:     const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF29A8E8)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF29A8E8),
        side: const BorderSide(color: Color(0xFF29A8E8), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF29A8E8),
      foregroundColor: Color(0xFF001E30),
      elevation:       2,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:           white,
      unselectedLabelColor: Color(0xFF4A7090),
      indicatorColor:       Color(0xFF29A8E8),
      dividerColor:         Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      backgroundColor: const Color(0xFF0A1826),
      selectedColor:   const Color(0xFF29A8E8).withAlpha(50),
      side: const BorderSide(color: darkOutline),
      labelStyle: const TextStyle(color: white),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF162030), thickness: 1, space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor:      darkSurface,
      textColor:      white,
      iconColor:      Color(0xFF5A8AAA),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(fontWeight: FontWeight.w900, letterSpacing: -2.0, color: white),
      displayMedium:  TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.5, color: white),
      displaySmall:   TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0, color: white),
      headlineLarge:  TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.8, color: white),
      headlineMedium: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: white),
      headlineSmall:  TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: white),
      titleLarge:     TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2, color: white),
      titleMedium:    TextStyle(fontWeight: FontWeight.w600, color: white),
      titleSmall:     TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1, color: white),
      labelLarge:     TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3, color: white),
      labelMedium:    TextStyle(fontWeight: FontWeight.w600, color: white),
      bodyLarge:      TextStyle(fontWeight: FontWeight.w400, color: white),
      bodyMedium:     TextStyle(fontWeight: FontWeight.w400, color: white),
      bodySmall:      TextStyle(fontWeight: FontWeight.w400, color: Color(0xFF80A8C0)),
    ),
  );
}
