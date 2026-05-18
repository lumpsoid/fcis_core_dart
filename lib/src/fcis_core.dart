import 'dart:async';

import 'package:fcis_core/src/action_source.dart';
import 'package:fcis_core/src/effect_runner.dart';
import 'package:fcis_core/src/state_holder.dart';

import 'updater.dart';

/// The FCIS runtime.
///
/// Owns the mutable state cell and executes the core loop:
///
///   dispatch(action)
///     -> updater.update(state, action) -> (nextState, effects)
///     -> state = nextState
///     -> notify listeners
///     -> for each effect: handler.run(effect, dispatch: dispatch)
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
  }) : _effectRunner = effectRunner,
       _stateHolder = stateHolder,
       _updater = updater;

  /// The current state snapshot.
  final StateHolder<S> _stateHolder;
  final Updater<S, A, E> _updater;
  final EffectRunner<E, A> _effectRunner;

  /// Fire-and-forget dispatch.
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
