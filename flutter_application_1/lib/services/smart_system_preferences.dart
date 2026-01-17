import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'smart_system_service.dart';

class SmartSystemPreferences {
  static const String _filtersKey = 'smart_system_filters';
  static const String _sortKey = 'smart_system_sort';
  static const String _userPreferencesKey = 'smart_system_user_prefs';
  static const String _savedSearchesKey = 'smart_system_saved_searches';
  static const String _viewModeKey = 'smart_system_view_mode';

  // Save filters
  static Future<void> saveFilters(Map<String, dynamic> filters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filtersKey, jsonEncode(filters));
    
    // Also save to backend if possible
    try {
      await SmartSystemService.updateUserPreferences(filters: filters);
    } catch (e) {
      // Silent fail - local storage is sufficient
    }
  }

  // Load filters
  static Future<Map<String, dynamic>> loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final filtersJson = prefs.getString(_filtersKey);
    if (filtersJson != null) {
      return jsonDecode(filtersJson) as Map<String, dynamic>;
    }
    return {};
  }

  // Save sort preference
  static Future<void> saveSortBy(String sortBy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortKey, sortBy);
  }

  // Load sort preference
  static Future<String> loadSortBy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortKey) ?? 'score';
  }

  // Save complete user preferences
  static Future<void> saveUserPreferences({
    required String? preferredCity,
    required String? preferredType,
    required double? minPrice,
    required double? maxPrice,
    required int? minBedrooms,
    required String? userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final preferences = {
      'preferredCity': preferredCity,
      'preferredType': preferredType,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'minBedrooms': minBedrooms,
      'userType': userType,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_userPreferencesKey, jsonEncode(preferences));
  }

  // Load user preferences
  static Future<Map<String, dynamic>> loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString(_userPreferencesKey);
    if (prefsJson != null) {
      return jsonDecode(prefsJson) as Map<String, dynamic>;
    }
    return {};
  }

  // Clear all preferences
  static Future<void> clearAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_filtersKey);
    await prefs.remove(_sortKey);
    await prefs.remove(_userPreferencesKey);
    await prefs.remove(_savedSearchesKey);
    await prefs.remove(_viewModeKey);
  }

  // ========================================================
  // Saved Searches
  // ========================================================

  // Save a search
  static Future<void> saveSearch({
    required String name,
    required Map<String, dynamic> filters,
    String? searchQuery,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSearchesJson = prefs.getString(_savedSearchesKey);
    List<Map<String, dynamic>> savedSearches = [];
    
    if (savedSearchesJson != null) {
      final List<dynamic> decoded = jsonDecode(savedSearchesJson);
      savedSearches = decoded.map((e) => e as Map<String, dynamic>).toList();
    }

    // Check if search with same name exists
    savedSearches.removeWhere((s) => s['name'] == name);

    savedSearches.add({
      'name': name,
      'filters': filters,
      'searchQuery': searchQuery ?? '',
      'savedAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_savedSearchesKey, jsonEncode(savedSearches));
  }

  // Load all saved searches
  static Future<List<Map<String, dynamic>>> loadSavedSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSearchesJson = prefs.getString(_savedSearchesKey);
    
    if (savedSearchesJson != null) {
      final List<dynamic> decoded = jsonDecode(savedSearchesJson);
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  // Delete a saved search
  static Future<void> deleteSavedSearch(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSearchesJson = prefs.getString(_savedSearchesKey);
    
    if (savedSearchesJson != null) {
      final List<dynamic> decoded = jsonDecode(savedSearchesJson);
      final savedSearches = decoded.map((e) => e as Map<String, dynamic>).toList();
      savedSearches.removeWhere((s) => s['name'] == name);
      await prefs.setString(_savedSearchesKey, jsonEncode(savedSearches));
    }
  }

  // ========================================================
  // View Mode
  // ========================================================

  // Save view mode preference
  static Future<void> saveViewMode(String viewMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, viewMode);
  }

  // Load view mode preference
  static Future<String> loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_viewModeKey) ?? 'list';
  }
}
