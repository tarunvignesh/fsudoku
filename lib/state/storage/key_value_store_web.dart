/// Browser store, backed by `window.localStorage`.
library;

import 'dart:js_interop';

import 'key_value_store.dart';

@JS('globalThis.localStorage')
external _WebStorage? get _localStorage;

@JS()
extension type _WebStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Returns a store backed by `localStorage`, or an in-memory one if the
/// browser refuses it.
///
/// Private browsing and blocked third-party storage both make `localStorage`
/// throw rather than return null, so every call is guarded: losing saved
/// progress is acceptable, crashing on load is not.
KeyValueStore createStore() {
  try {
    final storage = _localStorage;
    if (storage == null) return InMemoryStore();
    // Prove it actually works before trusting it.
    const probe = '__fsudoku_probe__';
    storage.setItem(probe, '1');
    storage.removeItem(probe);
    return _LocalStorageStore(storage);
  } on Object {
    return InMemoryStore();
  }
}

class _LocalStorageStore implements KeyValueStore {
  _LocalStorageStore(this._storage);

  final _WebStorage _storage;

  @override
  String? read(String key) {
    try {
      return _storage.getItem(key);
    } on Object {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      _storage.setItem(key, value);
    } on Object {
      // Quota exceeded, or storage disabled mid-session. Nothing to do: the
      // game continues, it just will not be there next time.
    }
  }

  @override
  void delete(String key) {
    try {
      _storage.removeItem(key);
    } on Object {
      // As above.
    }
  }
}
