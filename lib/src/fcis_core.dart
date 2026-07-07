import 'dart:async';

import 'package:fcis_core/src/action_source.dart';
import 'package:fcis_core/src/effect_runner.dart';
import 'package:fcis_core/src/fcis_lifecycle.dart';
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
/// ## Liveness
///
/// The loop can outlive the widget/scope that owns it: an in-flight effect
/// may complete and try to [dispatch] a result back after the owner has been
/// torn down. Writing state at that point would touch a disposed state cell
/// (e.g. a disposed `ValueNotifier`) and throw.
///
/// [close] guards against this: once closed, [dispatch]/[dispatchAsync]
/// early-return, so no state write or further effect run happens. Effects
/// already running are NOT cancelled — they complete their async work (a
/// network write must not be lost); only the result they feed back is
/// dropped. Close is terminal — a closed loop is dead; build a fresh one to
/// resume.
///
/// Type parameters:
/// - [S] State
/// - [A] Action
/// - [E] Effect
class FcisLoop<S, A, E>
    implements ActionSink<A>, ActionSinkAsync<A>, LifecycleActionSink<A> {
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

  bool _closed = false;

  /// Permanently suppresses further dispatching. See [FcisLifecycle.close].
  ///
  /// After this, [dispatch]/[dispatchAsync] are no-ops. Not reversible — a
  /// closed loop is dead; build a fresh one to resume. Call on teardown of the
  /// loop's owner (view detach / scope disposal) so late results from in-flight
  /// effects can't write to a disposed state cell.
  @override
  void close() => _closed = true;

  /// Fire-and-forget dispatch.
  @override
  void dispatch(A action) => unawaited(dispatchAsync(action));

  /// Runs the full FCIS loop for [action].
  ///
  /// Completes after all resulting effects have been handled.
  /// Effects are run sequentially in list order.
  ///
  /// A no-op once the loop has been [close]d.
  @override
  Future<void> dispatchAsync(A action) async {
    if (_closed) return;

    final (nextState, effects) = _updater.update(_stateHolder.state, action);

    _stateHolder.update(nextState);

    _effectRunner.run(effects, dispatch);
  }
}
