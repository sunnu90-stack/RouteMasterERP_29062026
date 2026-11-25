import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { light, dark }

class ThemeNotifier extends StateNotifier<AppThemeType> {
  ThemeNotifier() : super(AppThemeType.dark) {
    _loadSaved();
  }

  static const _prefsKey = 'rm_app_theme_mode_v3';

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      state = saved == null ? AppThemeType.dark : _themeFromSavedValue(saved);
      await prefs.setString(_prefsKey, state.name);
    } catch (_) {}
  }

  Future<void> setTheme(AppThemeType theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, theme.name);
    } catch (_) {}
  }

  Future<void> setDarkMode(bool enabled) =>
      setTheme(enabled ? AppThemeType.dark : AppThemeType.light);

  Future<void> toggle() => setDarkMode(state != AppThemeType.dark);

  AppThemeType _themeFromSavedValue(String? value) {
    switch (value) {
      case 'dark':
      case 'deepForestGlass':
        return AppThemeType.dark;
      case 'light':
      case 'cleanMaterial':
      case 'softSky':
      case 'sunsetGlow':
      case 'northernLights':
      case 'wildBerry':
      default:
        return AppThemeType.light;
    }
  }
}

final appThemeProvider = StateNotifierProvider<ThemeNotifier, AppThemeType>(
  (ref) => ThemeNotifier(),
);

class AppThemeConfig {
  final List<Color> backgroundGradient;
  final List<Color> appBarGradient;
  final Color cardColor;
  final Color cardBorder;
  final Color highlightColor;
  final Color accentColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color surfaceColor;
  final Color navBarColor;
  final bool isDark;
  final bool isGlass;
  final double shadowOpacity;
  final String displayName;

  const AppThemeConfig({
    required this.backgroundGradient,
    required this.appBarGradient,
    required this.cardColor,
    required this.cardBorder,
    required this.highlightColor,
    required this.accentColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.surfaceColor,
    required this.navBarColor,
    required this.isDark,
    this.isGlass = false,
    required this.shadowOpacity,
    required this.displayName,
  });

  Color get borderColor => cardBorder;
}

class ThemeHelper {
  static const _primary = Color(0xFF197C78);
  static const _accent = Color(0xFFC9A66B);

  static AppThemeConfig getConfig(AppThemeType type) {
    switch (type) {
      case AppThemeType.dark:
        return const AppThemeConfig(
          backgroundGradient: [Color(0xFF070B11), Color(0xFF0D1722)],
          appBarGradient: [Color(0xFF0A111A), Color(0xFF0A111A)],
          cardColor: Color(0xFF111B27),
          cardBorder: Color(0xFF283747),
          highlightColor: Color(0xFF58C9BF),
          accentColor: _accent,
          primaryTextColor: Color(0xFFF2F0EA),
          secondaryTextColor: Color(0xFFA0ABB4),
          surfaceColor: Color(0xFF070B11),
          navBarColor: Color(0xFF0A111A),
          isDark: true,
          isGlass: true,
          shadowOpacity: 0.24,
          displayName: 'Midnight Fleet',
        );
      case AppThemeType.light:
        return const AppThemeConfig(
          backgroundGradient: [Color(0xFFF5F3EE), Color(0xFFECEAE4)],
          appBarGradient: [Color(0xFFFFFEFB), Color(0xFFF7F5F0)],
          cardColor: Color(0xFFFFFEFB),
          cardBorder: Color(0xFFE0DBD0),
          highlightColor: _primary,
          accentColor: _accent,
          primaryTextColor: Color(0xFF1C2A31),
          secondaryTextColor: Color(0xFF68777E),
          surfaceColor: Color(0xFFF5F3EE),
          navBarColor: Color(0xFFFFFEFB),
          isDark: false,
          shadowOpacity: 0.07,
          displayName: 'Skyline',
        );
    }
  }

  static ThemeMode themeMode(AppThemeType type) =>
      type == AppThemeType.dark ? ThemeMode.dark : ThemeMode.light;

  static ThemeData materialTheme(AppThemeType type) {
    final config = getConfig(type);
    final brightness = config.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: config.highlightColor,
        brightness: brightness,
        primary: config.highlightColor,
        secondary: config.accentColor,
        surface: config.surfaceColor,
        onSurface: config.primaryTextColor,
        onPrimary: config.isDark ? const Color(0xFF0B1220) : Colors.white,
      ),
    );

    final mutedFill =
        config.isDark ? const Color(0xFF111C2D) : const Color(0xFFF8FAFC);
    final dialogSurface =
        config.isDark ? const Color(0xFF162337) : const Color(0xFFFFFFFF);

    return base.copyWith(
      primaryColor: config.highlightColor,
      scaffoldBackgroundColor: config.surfaceColor,
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: config.shadowOpacity),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: config.cardColor,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: config.cardBorder,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: config.highlightColor,
        selectionColor: config.highlightColor.withValues(alpha: 0.24),
        selectionHandleColor: config.highlightColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogSurface,
        titleTextStyle: TextStyle(
          color: config.primaryTextColor,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle:
            TextStyle(color: config.primaryTextColor, fontSize: 13),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dialogSurface,
        textStyle: TextStyle(
          color: config.primaryTextColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
          color: config.primaryTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(dialogSurface),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: config.isDark ? 0 : 2,
        backgroundColor: config.navBarColor,
        foregroundColor: config.primaryTextColor,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        titleTextStyle: TextStyle(
          color: config.primaryTextColor,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
        iconTheme: IconThemeData(color: config.primaryTextColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: config.highlightColor,
          foregroundColor:
              config.isDark ? const Color(0xFF0B1220) : Colors.white,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: config.highlightColor,
          side: BorderSide(color: config.cardBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: config.highlightColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mutedFill,
        contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.highlightColor, width: 2),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          color: config.secondaryTextColor,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: config.highlightColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        hintStyle: TextStyle(
          color: config.secondaryTextColor,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        helperStyle: TextStyle(color: config.secondaryTextColor, fontSize: 11),
        errorStyle: const TextStyle(
          color: Color(0xFFEF4444),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: config.secondaryTextColor,
        suffixIconColor: config.secondaryTextColor,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: config.primaryTextColor,
        displayColor: config.primaryTextColor,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: config.navBarColor,
        selectedItemColor: config.highlightColor,
        unselectedItemColor: config.secondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: config.navBarColor,
        indicatorColor: config.highlightColor.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? config.highlightColor
                  : config.secondaryTextColor,
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: config.highlightColor,
        foregroundColor: config.isDark ? const Color(0xFF0B1220) : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            config.isDark ? const Color(0xFF162337) : const Color(0xFF172B3A),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return config.isDark ? const Color(0xFF0B1220) : Colors.white;
          }
          return config.secondaryTextColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return config.highlightColor;
          }
          return config.cardBorder;
        }),
      ),
    );
  }

  static SystemUiOverlayStyle systemOverlayFor(AppThemeType type) {
    final config = getConfig(type);
    return SystemUiOverlayStyle(
      statusBarColor: config.surfaceColor,
      statusBarIconBrightness:
          config.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: config.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: config.navBarColor,
      systemNavigationBarIconBrightness:
          config.isDark ? Brightness.light : Brightness.dark,
    );
  }
}
