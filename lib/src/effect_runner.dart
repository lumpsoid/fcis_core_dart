import 'package:fcis_core/src/listener_list.dart';
import 'package:fcis_core/src/shell.dart';

/// Read-only observable stream of emitted effects.
///
/// Type parameter:
/// - [E] Effect
abstract class EffectSource<E> {
  void addListener(void Function(E) listener);
  void removeListener(void Function(E) listener);
}

/// Executes a list of effects, feeding each result back via [dispatch].
///
/// Type parameters:
/// - [E] Effect
/// - [A] Action
abstract class EffectRunner<E, A> {
  const EffectRunner();

  Future<void> run(List<E>? effects, void Function(A) dispatch);
}

/// Default [EffectRunner] that delegates to a [Shell].
class ShellEffectRunner<E, A> extends EffectRunner<E, A> {
  const ShellEffectRunner({
    required Shell<E, A> shell,
    this.onEffectHandlerError,
  }) : _shell = shell;

  final Shell<E, A> _shell;
  final void Function(E, Object, StackTrace)? onEffectHandlerError;

  @override
  Future<void> run(List<E>? effects, void Function(A) dispatch) async {
    if (effects == null || effects.isEmpty) return;
    for (final effect in effects) {
      await _runOne(effect, dispatch);
    }
  }

  Future<void> _runOne(E effect, void Function(A) dispatch) async {
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

class ObservableEffectRunner<E, A> extends EffectRunner<E, A>
    implements EffectSource<E> {
  ObservableEffectRunner({
    required EffectRunner<E, A> inner,
    ListenerList<E>? listenerList,
  }) : _inner = inner,
       _listeners = listenerList ?? ListenerList<E>();

  final EffectRunner<E, A> _inner;
  final ListenerList<E> _listeners;

  @override
  void addListener(void Function(E) listener) => _listeners.add(listener);

  @override
  void removeListener(void Function(E) listener) => _listeners.remove(listener);

  @override
  Future<void> run(List<E>? effects, void Function(A) dispatch) async {
    if (effects == null || effects.isEmpty) return;
    for (final effect in effects) {
      _listeners.notify(effect);
      await _inner.run([effect], dispatch);
    }
  }
}
