import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Global app settings persisted across sessions.
/// Admin controls everything; participants & organizers read the values.
///
/// Persistence strategy:
///   • All settings → SharedPreferences (instant, works offline, survives refresh)
///   • Text/color/font settings → also Supabase app_settings table
///     so they survive logout and are shared across devices
///   • Logo bytes → SharedPreferences only (too large for Supabase TEXT column)
///
/// Key invariant: font scale is stored in SharedPreferences as a DOUBLE
/// (not a string) using setDouble/getDouble to avoid type-mismatch reads.
class AppSettingsProvider extends ChangeNotifier {
  static const _keyPrimary   = 'setting_primary_color';
  static const _keySecondary = 'setting_secondary_color';
  static const _keyLogoB64   = 'setting_logo_b64';
  static const _keyLogoName  = 'setting_logo_name';
  static const _keyFontPart  = 'setting_font_participant';
  static const _keyFontOrg   = 'setting_font_organizer';
  static const _keyAppTitle  = 'setting_app_title';

  // ── State ────────────────────────────────────────────────
  Color  _primaryColor   = const Color(0xFFE53935);
  Color  _secondaryColor = const Color(0xFFB71C1C);
  Uint8List? _logoBytes;
  String?    _logoName;
  double _fontScaleParticipant = 1.0;
  double _fontScaleOrganizer   = 1.0;
  String _appTitle = 'RAID';

  // ── Getters ──────────────────────────────────────────────
  Color  get primaryColor            => _primaryColor;
  Color  get secondaryColor          => _secondaryColor;
  Uint8List? get logoBytes           => _logoBytes;
  String?    get logoName            => _logoName;
  bool   get hasLogo                 => _logoBytes != null;
  double get fontScaleParticipant    => _fontScaleParticipant;
  double get fontScaleOrganizer      => _fontScaleOrganizer;
  String get appTitle                => _appTitle;

  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primaryColor, _secondaryColor],
  );

  // ── Load ─────────────────────────────────────────────────
  /// Called once at app startup (before runApp).
  /// Step 1: Load from SharedPreferences (instant, offline-safe).
  /// Step 2: Pull from Supabase and overwrite if values exist there.
  Future<void> load() async {
    await _loadFromPrefs();
    // Pull from Supabase in the background — don't block app startup
    _pullFromSupabase().catchError((_) {});
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final priHex = prefs.getString(_keyPrimary);
    if (priHex != null) _primaryColor = _hexToColor(priHex);

    final secHex = prefs.getString(_keySecondary);
    if (secHex != null) _secondaryColor = _hexToColor(secHex);

    final logoB64 = prefs.getString(_keyLogoB64);
    if (logoB64 != null) _logoBytes = base64Decode(logoB64);
    _logoName = prefs.getString(_keyLogoName);

    // Font scale: stored as Double in prefs; fall back to String parse for
    // legacy data that was stored as String in older builds.
    _fontScaleParticipant = prefs.getDouble(_keyFontPart)
        ?? double.tryParse(prefs.getString(_keyFontPart) ?? '')
        ?? 1.0;
    _fontScaleOrganizer   = prefs.getDouble(_keyFontOrg)
        ?? double.tryParse(prefs.getString(_keyFontOrg) ?? '')
        ?? 1.0;

    _appTitle = prefs.getString(_keyAppTitle) ?? 'RAID';

    notifyListeners();
  }

  /// Pull settings from Supabase and merge into local state + SharedPreferences.
  /// Called on startup (background) and by pushAllToSupabase after a write.
  Future<void> _pullFromSupabase() async {
    final priHex  = await SupabaseService.instance.getSetting(_keyPrimary);
    final secHex  = await SupabaseService.instance.getSetting(_keySecondary);
    final fontPart = await SupabaseService.instance.getSetting(_keyFontPart);
    final fontOrg  = await SupabaseService.instance.getSetting(_keyFontOrg);
    final title    = await SupabaseService.instance.getSetting(_keyAppTitle);

    final prefs = await SharedPreferences.getInstance();
    bool changed = false;

    if (priHex != null) {
      _primaryColor = _hexToColor(priHex);
      await prefs.setString(_keyPrimary, priHex);
      changed = true;
    }
    if (secHex != null) {
      _secondaryColor = _hexToColor(secHex);
      await prefs.setString(_keySecondary, secHex);
      changed = true;
    }
    if (fontPart != null) {
      final v = (double.tryParse(fontPart) ?? 1.0).clamp(0.8, 1.4);
      _fontScaleParticipant = v;
      await prefs.setDouble(_keyFontPart, v);
      changed = true;
    }
    if (fontOrg != null) {
      final v = (double.tryParse(fontOrg) ?? 1.0).clamp(0.8, 1.4);
      _fontScaleOrganizer = v;
      await prefs.setDouble(_keyFontOrg, v);
      changed = true;
    }
    if (title != null) {
      _appTitle = title.isEmpty ? 'RAID' : title;
      await prefs.setString(_keyAppTitle, _appTitle);
      changed = true;
    }

    if (changed) notifyListeners();
  }

  // ── Push ALL current settings to Supabase ─────────────────
  /// Writes every non-logo setting to Supabase in parallel.
  /// Call this from the "Push to cloud" button in the Settings screen, or
  /// after the database schema has just been fixed (so values set before the
  /// table existed are not lost).
  /// Returns a map of key → error message for any that failed.
  Future<Map<String, String>> pushAllToSupabase() async {
    final Map<String, String> errors = {};

    final pairs = {
      _keyPrimary:   _colorToHex(_primaryColor),
      _keySecondary: _colorToHex(_secondaryColor),
      _keyFontPart:  _fontScaleParticipant.toString(),
      _keyFontOrg:   _fontScaleOrganizer.toString(),
      _keyAppTitle:  _appTitle,
    };

    await Future.wait(pairs.entries.map((e) async {
      try {
        await SupabaseService.instance.setSetting(e.key, e.value);
      } catch (err) {
        errors[e.key] = err.toString();
      }
    }));

    return errors;
  }

  // ── Private write helpers ─────────────────────────────────
  Future<void> _saveToPrefs(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveDoubleToPrefs(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  /// Fire-and-forget Supabase write — never blocks the UI.
  void _saveToSupabase(String key, String value) {
    SupabaseService.instance.setSetting(key, value).catchError((_) {});
  }

  // ── Setters ──────────────────────────────────────────────
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final hex = _colorToHex(color);
    await _saveToPrefs(_keyPrimary, hex);
    _saveToSupabase(_keyPrimary, hex);
    notifyListeners();
  }

  Future<void> setSecondaryColor(Color color) async {
    _secondaryColor = color;
    final hex = _colorToHex(color);
    await _saveToPrefs(_keySecondary, hex);
    _saveToSupabase(_keySecondary, hex);
    notifyListeners();
  }

  Future<void> setLogo(Uint8List bytes, String name) async {
    _logoBytes = bytes;
    _logoName  = name;
    // Logo bytes are too large for Supabase TEXT — store locally only
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogoB64, base64Encode(bytes));
    await prefs.setString(_keyLogoName, name);
    notifyListeners();
  }

  Future<void> clearLogo() async {
    _logoBytes = null;
    _logoName  = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogoB64);
    await prefs.remove(_keyLogoName);
    notifyListeners();
  }

  Future<void> setFontScaleParticipant(double scale) async {
    _fontScaleParticipant = scale.clamp(0.8, 1.4);
    // Store as Double (not String) so getDouble() reads it back correctly
    await _saveDoubleToPrefs(_keyFontPart, _fontScaleParticipant);
    _saveToSupabase(_keyFontPart, _fontScaleParticipant.toString());
    notifyListeners();
  }

  Future<void> setFontScaleOrganizer(double scale) async {
    _fontScaleOrganizer = scale.clamp(0.8, 1.4);
    await _saveDoubleToPrefs(_keyFontOrg, _fontScaleOrganizer);
    _saveToSupabase(_keyFontOrg, _fontScaleOrganizer.toString());
    notifyListeners();
  }

  Future<void> setAppTitle(String title) async {
    _appTitle = title.trim().isEmpty ? 'RAID' : title.trim();
    await _saveToPrefs(_keyAppTitle, _appTitle);
    _saveToSupabase(_keyAppTitle, _appTitle);
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────
  /// Encodes a Color as an 8-char lowercase hex string (AARRGGBB).
  /// Uses toARGB32() instead of the deprecated .value getter.
  static String _colorToHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0');

  static Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFE53935);
    }
  }

  /// Build a dynamic ThemeData using the stored primary color
  ThemeData buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      primaryColor: _primaryColor,
      colorScheme: ColorScheme.dark(
        primary: _primaryColor,
        secondary: _secondaryColor,
        surface: const Color(0xFF1A1A1A),
        error: const Color(0xFFE53935),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: BorderSide(color: _primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF242424),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
        hintStyle: const TextStyle(color: Color(0xFF666666)),
        prefixIconColor: const Color(0xFF666666),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFF2A2A2A), thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: _primaryColor,
        unselectedItemColor: const Color(0xFF666666),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF242424),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF242424),
        labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        selectedColor: _primaryColor.withValues(alpha: 0.3),
      ),
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        displayMedium:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        headlineLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(
            color: Color(0xFFB0B0B0), fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFB0B0B0)),
        bodySmall: TextStyle(color: Color(0xFF666666)),
        labelLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: Color(0xFF666666)),
      ),
      useMaterial3: true,
    );
  }
}
