/// A mutation-safe list of nullable listeners.
///
/// Handles the tombstone pattern for safe removal during [notify]:
/// - Listeners removed mid-notification are nulled (tombstoned) rather than
///   removed immediately, tracked by [_reentrantlyRemovedListeners].
/// - Tombstones are compacted after the outermost [notify] returns, using
///   either in-place null-swapping or a fresh allocation depending on density.
/// - Listeners added during [notify] are not visited in that same call
///   (the loop end is snapshotted as [_count] at entry).
/// - The backing store is a fixed-length array that doubles on growth and
///   halves when utilisation drops to ≤ 50 %.
class ListenerList<T> {
  // A shared zero-length sentinel so every fresh instance shares the same
  // backing object. Fixed-length (not const) keeps the runtime type identical
  // to every other backing array, letting the compiler monomorphise field
  // accesses for better performance.
  List<void Function(T)?> _listeners = const [];

  /// Number of live (non-null) listeners currently registered.
  int _count = 0;

  /// How many [notify] frames are currently on the call stack.
  int _notifyDepth = 0;

  /// How many slots were nulled out during the current [notify] invocation
  /// tree. Lets us avoid a full scan when zero removals occurred.
  int _reentrantlyRemovedListeners = 0;

  /// Whether any listeners are currently registered.
  bool get hasListeners => _count > 0;

  /// Registers [listener]. Duplicate registrations are allowed; each must be
  /// removed independently.
  void add(void Function(T) listener) {
    // Grow the backing array if all logical slots are occupied.
    if (_count == _listeners.length) {
      // Start at 1 so we never try to allocate length 0 * 2 == 0 on the
      // very first add.
      final newLength = _count == 0 ? 1 : _count * 2;
      final next = List<void Function(T)?>.filled(newLength, null);
      for (var i = 0; i < _count; i++) {
        next[i] = _listeners[i];
      }
      _listeners = next;
    }
    _listeners[_count++] = listener;
  }

  /// Removes the first occurrence of [listener].
  ///
  /// Safe to call during [notify]; the slot is tombstoned and compacted later.
  /// If [listener] is not registered the call is a no-op.
  void remove(void Function(T) listener) {
    for (var i = 0; i < _count; i++) {
      if (_listeners[i] == listener) {
        if (_notifyDepth > 0) {
          // Inside a notification: tombstone and defer compaction.
          _listeners[i] = null;
          _reentrantlyRemovedListeners++;
        } else {
          // Outside a notification: shrink immediately.
          _removeAt(i);
        }
        return;
      }
    }
  }

  /// Calls every registered listener with [value].
  ///
  /// Listeners added during this call are not visited.
  /// Listeners removed during this call are skipped via the tombstone pattern.
  void notify(T value) {
    _notifyDepth++;
    // Snapshot the count so mid-notify additions are not visited.
    final end = _count;
    try {
      for (var i = 0; i < end; i++) {
        _listeners[i]?.call(value);
      }
    } finally {
      _notifyDepth--;
      if (_notifyDepth == 0 && _reentrantlyRemovedListeners > 0) {
        _compact();
      }
    }
  }

  /// Removes the listener at [index] and shrinks the backing array when the
  /// live count falls to ≤ 50 % of the allocated length.
  void _removeAt(int index) {
    _count--;
    if (_count * 2 <= _listeners.length) {
      // Utilisation dropped below 50 %: allocate a right-sized array.
      final next = List<void Function(T)?>.filled(_count, null);
      for (var i = 0; i < index; i++) {
        next[i] = _listeners[i];
      }
      for (var i = index; i < _count; i++) {
        next[i] = _listeners[i + 1];
      }
      _listeners = next;
    } else {
      // Utilisation still healthy: shift elements left in place, then clear
      // the vacated trailing slot so we don't retain a stale closure.
      for (var i = index; i < _count; i++) {
        _listeners[i] = _listeners[i + 1];
      }
      _listeners[_count] = null;
    }
  }

  /// Compacts tombstones after the outermost [notify] completes.
  ///
  /// - If live count ≤ 50 % of allocated length -> reallocate (also shrinks).
  /// - Otherwise -> in-place null-swap to preserve existing allocation.
  void _compact() {
    final newCount = _count - _reentrantlyRemovedListeners;

    if (newCount * 2 <= _listeners.length) {
      // Reallocate: right-sized array, copy only non-null entries.
      final next = List<void Function(T)?>.filled(newCount, null);
      var dst = 0;
      for (var i = 0; i < _count; i++) {
        final cb = _listeners[i];
        if (cb != null) {
          next[dst++] = cb;
        }
      }
      _listeners = next;
    } else {
      // In-place: bubble all nulls to the tail by swapping each null slot
      // with the next non-null slot.
      for (var i = 0; i < newCount; i++) {
        if (_listeners[i] == null) {
          var swap = i + 1;
          while (_listeners[swap] == null) {
            swap++;
          }
          _listeners[i] = _listeners[swap];
          _listeners[swap] = null;
        }
      }
    }

    _reentrantlyRemovedListeners = 0;
    _count = newCount;
  }
}

/// A mutation-safe list of nullable listeners.
///
/// Handles the tombstone pattern for safe removal during notification:
/// - If a listener is removed while [notify] is executing, it is nulled
///   (tombstoned) rather than removed immediately.
/// - Tombstones are compacted after the outermost [notify] returns.
///
/// This is the single implementation of this logic in the package.
class TombstoneListenerList<T> {
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
