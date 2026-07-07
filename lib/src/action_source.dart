import 'package:fcis_core/src/fcis_lifecycle.dart';

abstract class ActionSink<A> {
  void dispatch(A action);
}

abstract class ActionSinkAsync<A> {
  Future<void> dispatchAsync(A action);
}

/// An [ActionSink] whose delivery can be paused/resumed via [FcisLifecycle].
///
/// Lets a consumer (e.g. a controller) depend on both dispatching and teardown
/// control through a single narrow type, without seeing the whole `FcisLoop`.
abstract class LifecycleActionSink<A> implements ActionSink<A>, FcisLifecycle {}
