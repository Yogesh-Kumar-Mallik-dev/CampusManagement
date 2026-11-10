// Native / Desktop / Testing fallback: In-memory persistent map
final Map<String, String> _stubStorage = {};

Map<String, String> loadAllPersistentData() {
  return Map<String, String>.from(_stubStorage);
}

void persistData(String key, String value) {
  _stubStorage[key] = value;
}

void removePersistentData(String key) {
  _stubStorage.remove(key);
}

void clearAllPersistentData() {
  _stubStorage.clear();
}
