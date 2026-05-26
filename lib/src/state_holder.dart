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
