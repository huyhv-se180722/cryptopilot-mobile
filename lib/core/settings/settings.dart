import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device settings (never tokens): `shared_preferences` (D-141).
abstract interface class SettingsStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class PreferencesSettingsStore implements SettingsStore {
  PreferencesSettingsStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

class MemorySettingsStore implements SettingsStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => PreferencesSettingsStore(),
);

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// System, light or dark, remembered on the device.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsStoreProvider).read(_key);
    final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
    if (mode != null && ref.mounted) state = mode;
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsStoreProvider).write(_key, mode.name);
  }
}
