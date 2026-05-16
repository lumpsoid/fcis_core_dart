abstract class ActionSink<A> {
  void dispatch(A action);
}

abstract class ActionSinkAsync<A> {
  Future<void> dispatchAsync(A action);
}

// for listening to another feature's actions
abstract class ActionSource<A> {
  void addListener(void Function(A) listener);
  void removeListener(void Function(A) listener);
}
