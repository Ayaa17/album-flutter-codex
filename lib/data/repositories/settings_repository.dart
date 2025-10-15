import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../services/storage_service.dart';

class SettingsRepository {
  SettingsRepository({required StorageService storageService}) : _storageService = storageService;

  final StorageService _storageService;

  static const _themeKey = 'settings_theme_mode';
  static const _defaultNameKey = 'settings_default_name';
  static const _storagePathKey = 'settings_storage_path';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storageDir = await _storageService.ensureRootDirectory();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    final themeMode = ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)];

    return AppSettings(
      themeMode: themeMode,
      defaultActivityNameFormat: prefs.getString(_defaultNameKey) ?? 'Event {date}',
      storagePath: prefs.getString(_storagePathKey) ?? storageDir.path,
    );
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> updateDefaultNaming(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultNameKey, value);
  }

  Future<String> updateStoragePath(String path) async {
    await _storageService.overrideRootPath(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storagePathKey, path);
    return path;
  }
}
