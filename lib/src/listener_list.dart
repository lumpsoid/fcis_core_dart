/// A mutation-safe list of nullable listeners.
///
/// Handles the tombstone pattern for safe removal during notification:
/// - If a listener is removed while [notify] is executing, it is nulled
///   (tombstoned) rather than removed immediately.
/// - Tombstones are compacted after the outermost [notify] returns.
///
/// This is the single implementation of this logic in the package.
class ListenerList<T> {
  final List<void Function(T)?> _listeners = [];
  int _depth = 0;
  bool _hasTombstones = false;

  void add(void Function(T) listener) => _listeners.add(listener);

  void remove(void Function(T) listener) {
    final idx = _listeners.indexOf(listener);
    if (idx == -1) return;
    if (_depth > 0) {
      _listeners[idx] = null;
      _hasTombstones = true;
    } else {
      _listeners.removeAt(idx);
    }
  }

  void notify(T value) {
    _depth++;
    try {
      for (var i = 0; i < _listeners.length; i++) {
        _listeners[i]?.call(value);
      }
    } finally {
      _depth--;
      if (_depth == 0 && _hasTombstones) {
        _listeners.removeWhere((cb) => cb == null);
        _hasTombstones = false;
      }
    }
  }
}
