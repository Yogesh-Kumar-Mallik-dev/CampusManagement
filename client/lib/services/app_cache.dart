import 'dart:convert';
import 'package:flutter/material.dart';
import 'app_cache_storage.dart' as storage;

/// Application-level cache service that persists and manages user preferences,
/// session states, and personal settings (theme mode, last active tabs,
/// dock slot index, preferred payment methods, and filter states).
class AppCache {
  static final AppCache _instance = AppCache._internal();
  static AppCache get instance => _instance;

  final Map<String, dynamic> _memoryStore = {};
  bool _isInitialized = false;

  /// Global change notifier triggered on any cache mutation.
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  AppCache._internal();

  /// Creates an isolated AppCache instance for testing or scoped environments.
  AppCache.isolated({Map<String, dynamic>? initialData}) {
    if (initialData != null) {
      _memoryStore.addAll(initialData);
    }
    _isInitialized = true;
  }

  /// Synchronously initializes the in-memory cache from persistent backing store.
  void init() {
    if (_isInitialized) return;
    try {
      final raw = storage.loadAllPersistentData();
      for (final entry in raw.entries) {
        final decoded = _tryDecodeJson(entry.value);
        _memoryStore[entry.key] = decoded;
      }
    } catch (_) {
      // Fallback cleanly on error
    }
    _isInitialized = true;
  }

  /// Whether the cache has been initialized from storage.
  bool get isInitialized => _isInitialized;

  /// Total number of cached keys.
  int get size => _memoryStore.length;

  /// Set of all cached keys.
  Set<String> get keys => Set.unmodifiable(_memoryStore.keys);

  /// Checks if a key exists in cache.
  bool containsKey(String key) => _memoryStore.containsKey(key);

  /// Clears all cached entries both in-memory and persistent backing store.
  void clear() {
    _memoryStore.clear();
    storage.clearAllPersistentData();
    _notifyMutation();
  }

  /// Resets cache to uninitialized state (primarily for automated testing).
  void reset() {
    _memoryStore.clear();
    storage.clearAllPersistentData();
    _isInitialized = false;
    _notifyMutation();
  }

  // --------------------------------------------------------------------------
  // Core Getters and Setters
  // --------------------------------------------------------------------------

  /// Retrieves a value by key with optional fallback.
  dynamic get(String key, [dynamic defaultValue]) {
    if (!_isInitialized) init();
    return _memoryStore[key] ?? defaultValue;
  }

  /// Sets a value by key and flushes to persistent backing store.
  void set(String key, dynamic value) {
    if (!_isInitialized) init();
    if (value == null) {
      remove(key);
      return;
    }
    _memoryStore[key] = value;
    try {
      final serialized = jsonEncode(value);
      storage.persistData(key, serialized);
    } catch (_) {
      storage.persistData(key, value.toString());
    }
    _notifyMutation();
  }

  /// Removes an entry by key.
  void remove(String key) {
    if (!_isInitialized) init();
    _memoryStore.remove(key);
    storage.removePersistentData(key);
    _notifyMutation();
  }

  String? getString(String key, [String? defaultValue]) {
    final val = get(key, defaultValue);
    return val?.toString() ?? defaultValue;
  }

  void setString(String key, String value) {
    set(key, value);
  }

  int? getInt(String key, [int? defaultValue]) {
    final val = get(key, defaultValue);
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  void setInt(String key, int value) {
    set(key, value);
  }

  bool? getBool(String key, [bool? defaultValue]) {
    final val = get(key, defaultValue);
    if (val is bool) return val;
    if (val is String) {
      final lower = val.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (val is num) return val != 0;
    return defaultValue;
  }

  void setBool(String key, bool value) {
    set(key, value);
  }

  double? getDouble(String key, [double? defaultValue]) {
    final val = get(key, defaultValue);
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  void setDouble(String key, double value) {
    set(key, value);
  }

  Map<String, dynamic>? getMap(String key) {
    final val = get(key);
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    return null;
  }

  void setMap(String key, Map<String, dynamic> value) {
    set(key, value);
  }

  List<dynamic>? getList(String key) {
    final val = get(key);
    if (val is List) return val;
    return null;
  }

  void setList(String key, List<dynamic> value) {
    set(key, value);
  }

  // --------------------------------------------------------------------------
  // Domain Preferences: Preferred Theme Mode
  // --------------------------------------------------------------------------

  /// Returns preferred ThemeMode, or null if no preference has been saved yet.
  ThemeMode? getPreferredThemeMode() {
    final modeStr = getString('app.theme_mode');
    if (modeStr == null) return null;
    switch (modeStr.toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  /// Sets user's preferred ThemeMode and persists it.
  void setPreferredThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        setString('app.theme_mode', 'dark');
        break;
      case ThemeMode.light:
        setString('app.theme_mode', 'light');
        break;
      case ThemeMode.system:
        setString('app.theme_mode', 'system');
        break;
    }
  }

  // --------------------------------------------------------------------------
  // Domain Preferences: Active Tabs & Navigation (Scoped per user if desired)
  // --------------------------------------------------------------------------

  String _userKey(String baseKey, String? userHandle) {
    if (userHandle != null && userHandle.trim().isNotEmpty) {
      return 'user.${userHandle.trim()}.$baseKey';
    }
    return baseKey;
  }

  /// Last active main navigation screen/destination index in HomeScreen.
  int? getLastActiveNavIndex({String? userHandle}) {
    return getInt(_userKey('nav.last_active_index', userHandle));
  }

  /// Remembers last active main navigation index in HomeScreen.
  void setLastActiveNavIndex(int index, {String? userHandle}) {
    setInt(_userKey('nav.last_active_index', userHandle), index);
  }

  /// Last active slot 3 item index in bottom navigation dock.
  int? getSlot3PageIndex({String? userHandle}) {
    return getInt(_userKey('nav.slot3_index', userHandle));
  }

  /// Remembers last active slot 3 item index in bottom navigation dock.
  void setSlot3PageIndex(int index, {String? userHandle}) {
    setInt(_userKey('nav.slot3_index', userHandle), index);
  }

  /// Last active portal tab index in FeeScreen (0: Invoices, 1: Fines, 2: Records, 3: Slabs).
  int? getLastFeeTab({String? userHandle}) {
    return getInt(_userKey('fee.last_tab_index', userHandle));
  }

  /// Remembers last active portal tab index in FeeScreen.
  void setLastFeeTab(int index, {String? userHandle}) {
    setInt(_userKey('fee.last_tab_index', userHandle), index);
  }

  /// Last active tab index in LibraryScreen (0: Loans, 1: Books, 2: EBooks, 3: Policy, 4: Approvals).
  int? getLastLibraryTab({String? userHandle}) {
    return getInt(_userKey('library.last_tab_index', userHandle));
  }

  /// Remembers last active tab index in LibraryScreen.
  void setLastLibraryTab(int index, {String? userHandle}) {
    setInt(_userKey('library.last_tab_index', userHandle), index);
  }

  /// Preferred payment mode in payment dialogs ('upi', 'card', 'netbanking', 'challan').
  String? getPreferredPaymentMethod() {
    return getString('payment.preferred_method');
  }

  /// Remembers preferred payment mode in payment dialogs.
  void setPreferredPaymentMethod(String method) {
    setString('payment.preferred_method', method.toLowerCase());
  }

  /// Last active hostel floor/block selection.
  int? getLastHostelFloor({String? userHandle}) {
    return getInt(_userKey('hostel.last_floor', userHandle));
  }

  /// Remembers last active hostel floor selection.
  void setLastHostelFloor(int floor, {String? userHandle}) {
    setInt(_userKey('hostel.last_floor', userHandle), floor);
  }

  /// Last active mess meal day selection (1: Monday .. 7: Sunday).
  int? getLastMessDay({String? userHandle}) {
    return getInt(_userKey('mess.last_day', userHandle));
  }

  /// Remembers last active mess meal day selection.
  void setLastMessDay(int day, {String? userHandle}) {
    setInt(_userKey('mess.last_day', userHandle), day);
  }

  /// Last active complaints category/status filter.
  String? getLastComplaintsFilter({String? userHandle}) {
    return getString(_userKey('complaints.last_filter', userHandle));
  }

  /// Remembers last active complaints filter.
  void setLastComplaintsFilter(String filter, {String? userHandle}) {
    setString(_userKey('complaints.last_filter', userHandle), filter);
  }

  /// Remembered user handle for login convenience.
  String? getRememberedUserHandle() {
    return getString('auth.remembered_user_handle');
  }

  /// Sets remembered user handle.
  void setRememberedUserHandle(String handle) {
    setString('auth.remembered_user_handle', handle);
  }

  /// Clears remembered user handle.
  void clearRememberedUserHandle() {
    remove('auth.remembered_user_handle');
  }

  // --------------------------------------------------------------------------
  // Internal Helpers
  // --------------------------------------------------------------------------

  dynamic _tryDecodeJson(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return source;
    }
  }

  void _notifyMutation() {
    changeNotifier.value = changeNotifier.value + 1;
  }
}
