// lib/services/theme_notifier.dart
// ─────────────────────────────────────────────────────────────────────────────
// App-wide theme state. Wrap MaterialApp with this so dark/light
// mode toggle in Profile actually changes the whole app.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'storage_service.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final ThemeNotifier instance = ThemeNotifier._();

  bool _isDark = true;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void init() {
    _isDark = StorageService.instance.loadDarkMode();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    await StorageService.instance.saveDarkMode(_isDark);
    notifyListeners();
  }

  Future<void> set(bool dark) async {
    if (_isDark == dark) return;
    _isDark = dark;
    await StorageService.instance.saveDarkMode(_isDark);
    notifyListeners();
  }
}
