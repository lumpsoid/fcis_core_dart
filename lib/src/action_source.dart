abstract class ActionSink<A> {
  void dispatch(A action);
}

abstract class ActionSinkAsync<A> {
  Future<void> dispatchAsync(A action);
}
