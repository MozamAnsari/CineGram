import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccentPreset {
  goldLeaf('Gold Leaf', Color(0xFFFFD700)),
  cobaltSapphire('Cobalt Sapphire', Color(0xFF00D2FF)),
  crimsonRuby('Crimson Ruby', Color(0xFFFF2E93)),
  emeraldMint('Emerald Mint', Color(0xFF00F5D4));

  final String name;
  final Color color;
  const AccentPreset(this.name, this.color);
}

class ThemeProvider with ChangeNotifier {
  static const String _prefKey = 'accent_preset';
  static const String _customColorPrefKey = 'custom_accent_color';
  AccentPreset _currentPreset;
  Color? _customColor;

  ThemeProvider(int initialPresetIndex, {String? savedCustomHex})
      : _currentPreset = (initialPresetIndex >= 0 && initialPresetIndex < AccentPreset.values.length)
            ? AccentPreset.values[initialPresetIndex]
            : AccentPreset.goldLeaf {
    _customColor = parseHexColor(savedCustomHex);
  }

  AccentPreset get currentPreset => _currentPreset;
  Color get accentColor => _customColor ?? _currentPreset.color;
  Color? get customColor => _customColor;

  String? get customColorHex => _customColor != null
      ? '#${_customColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'
      : null;

  static Color? parseHexColor(String? hexString) {
    if (hexString == null || hexString.trim().isEmpty) return null;
    String hex = hexString.replaceAll('#', '').trim();
    if (hex.length == 3) {
      hex = hex.split('').map((c) => c + c).join();
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final val = int.tryParse(hex, radix: 16);
      if (val != null) {
        return Color(val);
      }
    }
    return null;
  }

  Future<void> setPreset(AccentPreset preset) async {
    _currentPreset = preset;
    _customColor = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, preset.index);
      await prefs.remove(_customColorPrefKey);
    } catch (_) {}
  }

  Future<bool> setCustomHexColor(String hexString) async {
    final parsed = parseHexColor(hexString);
    if (parsed == null) return false;

    _customColor = parsed;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customColorPrefKey, hexString.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearCustomColor() async {
    _customColor = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customColorPrefKey);
    } catch (_) {}
  }
}

class CinegramTheme {
  static const Color background = Color(0xFF070708); // Extreme deep void black
  static const Color surface = Color(0xFF121215); // Obsidian/Dark charcoal grey
  static const Color textPrimary = Color(0xFFF4F4F5); // Crisp off-white
  static const Color textSecondary = Color(0xFFA1A1AA); // Muted titanium gray
  static const Color glassWhite = Color(0xFF1E1E22);

  static ThemeData darkTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentColor,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: surface,
        background: background,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        TextTheme(
          displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.5),
          headlineLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.2),
          titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
          bodyLarge: const TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
          labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor, letterSpacing: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: accentColor,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
    );
  }
}
