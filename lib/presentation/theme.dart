import 'package:flutter/material.dart';

/// Sistema visual de GestuVoz (mockups vigentes 1-12): turquesa como color de
/// accion, fondos claros y tarjetas pastel por categoria. Los estados se
/// comunican con icono + texto, nunca solo con color (RNF-04).
class AppColors {
  // Accion principal (botones, seleccion). Blanco sobre primary: 6.3:1.
  static const primary = Color(0xFF276B62);
  static const primaryDark = Color(0xFF1B4A44);
  static const primarySoft = Color(0xFFDDF0EB);

  static const bg = Color(0xFFF4F7F6);
  static const surface = Colors.white;
  static const ink = Color(0xFF15302B);
  static const inkSoft = Color(0xFF55665F);
  static const outline = Color(0xFFDDE5E2);

  // Estados
  static const success = Color(0xFF2E7D5B);
  static const successSoft = Color(0xFFDDF0E4);
  static const coral = Color(0xFFD9584A);
  static const coralSoft = Color(0xFFFDE4E0);
  static const amberSoft = Color(0xFFFFF4D6);
  static const amberInk = Color(0xFF6E5200);

  // Pastel (fondos de tarjetas del nino)
  static const pink = Color(0xFFFDE4E0);
  static const blue = Color(0xFFE3EEFB);
  static const yellow = Color(0xFFFFF3D6);
  static const lilac = Color(0xFFECE6FB);
  static const mint = Color(0xFFDDF0EB);
  static const peach = Color(0xFFFFE8D6);

  // Acentos (bordes de seleccion) de cada pastel
  static const pinkAccent = Color(0xFFE07A6E);
  static const blueAccent = Color(0xFF5B8FD6);
  static const yellowAccent = Color(0xFFD9A62B);
  static const lilacAccent = Color(0xFF8A74D6);
  static const mintAccent = Color(0xFF3E9A84);
  static const peachAccent = Color(0xFFE08A4A);
}

class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 36;
}

class Radii {
  static const double card = 22;
  static const double tile = 24;
  static const double button = 18;
}

ThemeData buildTheme({required bool highContrast}) {
  final primary = highContrast ? AppColors.primaryDark : AppColors.primary;
  final ink = highContrast ? Colors.black : AppColors.ink;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.mintAccent,
    error: AppColors.coral,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: highContrast ? Colors.black87 : AppColors.inkSoft,
    outlineVariant: highContrast ? Colors.black54 : AppColors.outline,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Baloo2',
    scaffoldBackgroundColor: highContrast ? Colors.white : AppColors.bg,
  );
  final borderColor = highContrast ? Colors.black : AppColors.outline;
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: highContrast ? Colors.white : AppColors.bg,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(
        fontFamily: 'Baloo2',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: borderColor, width: highContrast ? 2 : 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
            fontFamily: 'Baloo2', fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 54),
        foregroundColor: primary,
        side: BorderSide(color: borderColor, width: 1.5),
        backgroundColor: Colors.white,
        textStyle: const TextStyle(
            fontFamily: 'Baloo2', fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
            fontFamily: 'Baloo2', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : null),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primarySoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(
          fontFamily: 'Baloo2', fontSize: 13, fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: borderColor),
      labelStyle: const TextStyle(fontFamily: 'Baloo2', fontSize: 14),
    ),
  );
}
