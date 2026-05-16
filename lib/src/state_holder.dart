abstract class StateHolder<S> {
  S get state;
  void update(S next);
}
