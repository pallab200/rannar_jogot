import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class LocalizationProvider extends ChangeNotifier {
  static const String _defaultLanguage = 'en';
  String _currentLanguage = _defaultLanguage;
  final CacheService _cacheService = CacheService();

  String get currentLanguage => _currentLanguage;

  LocalizationProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    _currentLanguage = await _cacheService.getPreferredLanguage();
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    await _cacheService.setPreferredLanguage(languageCode);
    _currentLanguage = languageCode;
    notifyListeners();
  }
}
