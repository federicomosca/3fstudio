import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand palette 3F Training ─────────────────────────────────────────────
  static const Color navy    = Color(0xFF0A1726);  // dark navy (sfondo scuro)
  static const Color blue    = Color(0xFF0081C8);  // blu medio (testo "3F")
  static const Color cyan    = Color(0xFF50C0D0);  // cyan chiaro (triangoli logo)
  static const Color lightBg = Color(0xFFEDF2F8);  // grigio-azzurro chiaro (logo bg)
  static const Color white   = Color(0xFFFFFFFF);

  // Alias per retrocompatibilità con widget esistenti
  static const Color charcoal = navy;
  static const Color lime     = blue;
  static const Color surface  = lightBg;

  // Esposti per uso nei widget
  static const Color primaryColor = navy;
  static const Color accentColor  = blue;

  // ── Sfondo card in dark mode (usabile nei widget come AppTheme.darkSurface) ──
  static const Color darkSurface  = Color(0xFF0E1C32);
  static const Color darkBg       = Color(0xFF070D1C);
  static const Color darkOutline  = Color(0xFF243B5A);

  // ── LIGHT theme ─────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme(
      brightness:              Brightness.light,
      primary:                 navy,
      onPrimary:               white,
      primaryContainer:        Color(0xFFD0E8F5),
      onPrimaryContainer:      navy,
      secondary:               blue,
      onSecondary:             white,
      secondaryContainer:      Color(0xFFCCEAF7),
      onSecondaryContainer:    navy,
      tertiary:                cyan,
      onTertiary:              navy,
      tertiaryContainer:       Color(0xFFCCEEF4),
      onTertiaryContainer:     navy,
      error:                   Color(0xFFD32F2F),
      onError:                 white,
      errorContainer:          Color(0xFFFFEBEE),
      onErrorContainer:        Color(0xFFB71C1C),
      surface:                 white,
      onSurface:               navy,
      surfaceContainerHighest: Color(0xFFE0ECF5),
      outline:                 Color(0xFFB8CCE0),
      outlineVariant:          Color(0xFFD8E8F0),
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          navy,
      onInverseSurface:        white,
      inversePrimary:          cyan,
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
        color:        white,
        fontSize:     18,
        fontWeight:   FontWeight.w800,
        letterSpacing: -0.3,
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
          color: selected ? blue : const Color(0xFF6A8AAA),
          size:  24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color:      selected ? blue : const Color(0xFF6A8AAA),
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
        side: const BorderSide(color: Color(0xFFB8CCE0)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB8CCE0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB8CCE0)),
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
          fontWeight:    FontWeight.w800,
          fontSize:      15,
          letterSpacing: 0.5,
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
    chipTheme: const ChipThemeData(shape: StadiumBorder()),
    dividerTheme: const DividerThemeData(
      color:     Color(0xFFD0E0EE),
      thickness: 1,
      space:     1,
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

  // ── DARK theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme(
      brightness:              Brightness.dark,
      primary:                 blue,
      onPrimary:               white,
      primaryContainer:        Color(0xFF0A2D4E),
      onPrimaryContainer:      Color(0xFF90CAEF),
      secondary:               cyan,
      onSecondary:             navy,
      secondaryContainer:      Color(0xFF0A2535),
      onSecondaryContainer:    cyan,
      tertiary:                cyan,
      onTertiary:              navy,
      tertiaryContainer:       Color(0xFF0A2535),
      onTertiaryContainer:     cyan,
      error:                   Color(0xFFCF6679),
      onError:                 Color(0xFF690020),
      errorContainer:          Color(0xFF93000A),
      onErrorContainer:        Color(0xFFFFDAD6),
      surface:                 darkSurface,
      onSurface:               white,
      surfaceContainerHighest: Color(0xFF162843),
      outline:                 darkOutline,
      outlineVariant:          Color(0xFF192E4A),
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          white,
      onInverseSurface:        navy,
      inversePrimary:          navy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:    Color(0xFF0A1726),
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
        color:        white,
        fontSize:     18,
        fontWeight:   FontWeight.w800,
        letterSpacing: -0.3,
      ),
      iconTheme:        IconThemeData(color: white),
      actionsIconTheme: IconThemeData(color: white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color(0xFF0A1726),
      elevation:       0,
      height:          64,
      indicatorColor:  Color(0x330081C8),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? blue : const Color(0xFF4A6A8A),
          size:  24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color:      selected ? blue : const Color(0xFF4A6A8A),
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
        borderSide: const BorderSide(color: blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCF6679)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled:    true,
      fillColor: darkSurface,
      labelStyle:     const TextStyle(color: Color(0xFF6A8AAA)),
      hintStyle:      const TextStyle(color: Color(0xFF4A6A8A)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: white,
        minimumSize:     const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight:    FontWeight.w800,
          fontSize:      15,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: blue),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: blue,
        side: const BorderSide(color: blue, width: 1.5),
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
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      backgroundColor: const Color(0xFF0E1C32),
      selectedColor:   blue.withAlpha(50),
      side: const BorderSide(color: darkOutline),
      labelStyle: const TextStyle(color: white),
    ),
    dividerTheme: const DividerThemeData(
      color:     Color(0xFF192E4A),
      thickness: 1,
      space:     1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor:      darkSurface,
      textColor:      white,
      iconColor:      Color(0xFF6A8AAA),
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
      bodySmall:      TextStyle(fontWeight: FontWeight.w400, color: Color(0xFF94B0C8)),
    ),
  );
}
