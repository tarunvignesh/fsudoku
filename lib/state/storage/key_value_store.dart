/// A tiny string store, backed by whatever the platform offers.
///
/// Deliberately not a database. What has to survive a reload is one game in
/// progress and a handful of preferences -- one or two kilobytes of JSON.
/// SQLite on the web means shipping a wasm build of SQLite, which would add
/// roughly a megabyte to a payload that is already dominated by the renderer,
/// and a remote database would trade working offline for sync nobody asked
/// for yet.
library;

export 'key_value_store_stub.dart'
    if (dart.library.js_interop) 'key_value_store_web.dart';

/// Reads and writes small strings by key.
abstract interface class KeyValueStore {
  /// The value stored under [key], or null.
  String? read(String key);

  /// Stores [value] under [key].
  void write(String key, String value);

  /// Removes [key].
  void delete(String key);
}

/// A store that keeps everything in memory and forgets it on exit.
///
/// Used by tests, and as the fallback wherever no platform store exists yet.
class InMemoryStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void delete(String key) => _values.remove(key);
}
