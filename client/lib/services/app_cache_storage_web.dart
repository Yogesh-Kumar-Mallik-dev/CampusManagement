// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String _keyPrefix = 'bbdit_app_cache_';

Map<String, String> loadAllPersistentData() {
  final result = <String, String>{};
  try {
    final storage = html.window.localStorage;
    for (final key in storage.keys) {
      if (key.startsWith(_keyPrefix)) {
        final cleanKey = key.substring(_keyPrefix.length);
        final val = storage[key];
        if (val != null) {
          result[cleanKey] = val;
        }
      }
    }
  } catch (_) {
    // Graceful fallback if localStorage is disabled or restricted (e.g. sandbox/private mode)
  }
  return result;
}

void persistData(String key, String value) {
  try {
    html.window.localStorage['$_keyPrefix$key'] = value;
  } catch (_) {}
}

void removePersistentData(String key) {
  try {
    html.window.localStorage.remove('$_keyPrefix$key');
  } catch (_) {}
}

void clearAllPersistentData() {
  try {
    final storage = html.window.localStorage;
    final keysToRemove = storage.keys.where((k) => k.startsWith(_keyPrefix)).toList();
    for (final k in keysToRemove) {
      storage.remove(k);
    }
  } catch (_) {}
}
