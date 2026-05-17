import 'dart:async';

import 'package:fcis_core/src/action_source.dart';
import 'package:fcis_core/src/effect_runner.dart';
import 'package:fcis_core/src/listener_list.dart';
import 'package:fcis_core/src/state_holder.dart';

import 'updater.dart';

/// The FCIS runtime.
///
/// Owns the mutable state cell and executes the core loop:
///
///   dispatch(action)
///     → updater.update(state, action) → (nextState, effects)
///     → state = nextState
///     → notify listeners
///     → for each effect: handler.run(effect, dispatch: dispatch)
///
/// This is the entire pattern — nothing more.
///
/// Type parameters:
/// - [S] State
/// - [A] Action
/// - [E] Effect
class FcisLoop<S, A, E> implements ActionSink<A>, ActionSinkAsync<A> {
  FcisLoop({
    required StateHolder<S> stateHolder,
    required Updater<S, A, E> updater,
    required EffectRunner<E, A> effectRunner,
    this.onEffectHandlerError,
  }) : _effectRunner = effectRunner,
       _stateHolder = stateHolder,
       _updater = updater;

  /// The current state snapshot.
  final StateHolder<S> _stateHolder;
  final Updater<S, A, E> _updater;
  final EffectRunner<E, A> _effectRunner;

  /// Called when [EffectHandler.run] throws.
  ///
  /// If null, errors propagate out of [dispatchAsync].
  final void Function(E effect, Object error, StackTrace stackTrace)?
  onEffectHandlerError;

  /// Fire-and-forget dispatch.
  ///
  /// Errors are only catchable via [onEffectHandlerError].
  /// Prefer [dispatchAsync] when you need backpressure or error handling.
  @override
  void dispatch(A action) => unawaited(dispatchAsync(action));

  /// Runs the full FCIS loop for [action].
  ///
  /// Completes after all resulting effects have been handled.
  /// Effects are run sequentially in list order.
  @override
  Future<void> dispatchAsync(A action) async {
    final (nextState, effects) = _updater.update(_stateHolder.state, action);

    _stateHolder.update(nextState);

    _effectRunner.run(effects, dispatch);
  }
}

class ObservableFcisLoop<S, A, E> extends FcisLoop<S, A, E>
    implements ActionListener<A> {
  ObservableFcisLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
    super.onEffectHandlerError,
    ListenerList<A>? listenerList,
  }) : _listeners = listenerList ?? ListenerList<A>();

  final ListenerList<A> _listeners;

  @override
  void addListener(void Function(A) listener) => _listeners.add(listener);

  @override
  void removeListener(void Function(A) listener) => _listeners.remove(listener);

  @override
  Future<void> dispatchAsync(A action) async {
    await super.dispatchAsync(action);
    _listeners.notify(action);
  }
}
