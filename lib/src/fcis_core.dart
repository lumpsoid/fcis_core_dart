import 'dart:async';

import 'package:fcis_core/src/shell.dart';
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
class FcisLoop<S, A, E> {
  FcisLoop({
    required StateHolder<S> stateHolder,
    required Updater<S, A, E> updater,
    required Shell<E, A> shell,
    this.onEffectHandlerError,
  }) : _stateHolder = stateHolder,
       _updater = updater,
       _shell = shell;

  /// The current state snapshot.
  final StateHolder<S> _stateHolder;
  final Updater<S, A, E> _updater;
  final Shell<E, A> _shell;

  /// Called when [EffectHandler.run] throws.
  ///
  /// If null, errors propagate out of [dispatchAsync].
  final void Function(E effect, Object error, StackTrace stackTrace)?
  onEffectHandlerError;

  /// Fire-and-forget dispatch.
  ///
  /// Errors are only catchable via [onEffectHandlerError].
  /// Prefer [dispatchAsync] when you need backpressure or error handling.
  void dispatch(A action) => unawaited(dispatchAsync(action));

  /// Runs the full FCIS loop for [action].
  ///
  /// Completes after all resulting effects have been handled.
  /// Effects are run sequentially in list order.
  Future<void> dispatchAsync(A action) async {
    final (nextState, effects) = _updater.update(_stateHolder.state, action);

    _stateHolder.update(nextState);

    for (final effect in effects) {
      await _runEffect(effect);
    }
  }

  Future<void> _runEffect(E effect) async {
    try {
      await _shell.run(effect, dispatch: dispatch);
    } catch (e, st) {
      if (onEffectHandlerError != null) {
        onEffectHandlerError!(effect, e, st);
      } else {
        rethrow;
      }
    }
  }
}
