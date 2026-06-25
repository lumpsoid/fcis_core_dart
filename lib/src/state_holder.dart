abstract class StateSource<S> {
  S get state;
}

abstract class StateHolder<S> implements StateSource<S> {
  @override
  S get state;
  void update(S next);
}

abstract class StateListener<S> {
  void addListener(void Function(S) listener);
  void removeListener(void Function(S) listener);
}

/// Read-only reactive view over a state source.
///
/// Mirrors the shape of `ValueListenable` but in fcis_core terms: exposes the
/// current [state] and lets callers react to changes via a no-argument
/// listener, without the ability to mutate the state.
abstract class StateReader<S> implements StateSource<S> {
  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}
