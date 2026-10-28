/// Fallback store for platforms with no implementation yet.
library;

import 'key_value_store.dart';

/// Returns an in-memory store.
///
/// iOS and Android reach this. Nothing is lost that was not already lost
/// before persistence existed, and swapping in a real implementation is one
/// file -- the rest of the app only knows [KeyValueStore].
KeyValueStore createStore() => InMemoryStore();
