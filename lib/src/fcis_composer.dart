import 'package:fcis_core/src/action_source.dart';
import 'package:fcis_core/src/effect_runner.dart';

/// A directional action bridge between two features.
///
/// Listens to a [ActionSource<F>] and forwards selected actions to a
/// [ActionSink<T>] by applying a [map] function.
///
/// The [map] function returns null to ignore an action, or a mapped action
/// to forward it. This makes [FcisComposer] a selective, typed signal router —
/// nothing more.
///
/// [FcisComposer] has no knowledge of lifecycle, FCIS internals, or any
/// external dependencies. Calling [bind] and [unbind] is the sole
/// responsibility of the user.
///
/// Example:
/// ```dart
/// final composer = FcisComposer<CartAction, CheckoutAction>(
///   source: cartLoop,
///   sink: checkoutLoop,
///   map: (action) => switch (action) {
///     CartAction.cleared() => CheckoutAction.cartCleared(),
///     _ => null,
///   },
/// );
///
/// // when ready
/// composer.bind();
///
/// // when done
/// composer.unbind();
/// ```
///
/// Type parameters:
/// - [F] From — the source feature's action type
/// - [T] To   — the sink feature's action type
class FcisComposer<F, T> {
  /// Creates a composer that routes actions from [source] to [sink].
  ///
  /// [map] is called for every action emitted by [source].
  /// Return a [T] action to forward it, or null to ignore it.
  FcisComposer({
    required EffectSource<F> source,
    required ActionSink<T> sink,
    required T? Function(F) map,
  }) : _source = source,
       _sink = sink,
       _map = map;

  final EffectSource<F> _source;
  final ActionSink<T> _sink;
  final T? Function(F) _map;

  /// Whether this composer is currently bound.
  bool _isBound = false;

  /// Whether this composer is currently bound.
  bool get isBound => _isBound;

  void _listener(F action) {
    final mapped = _map(action);
    if (mapped != null) _sink.dispatch(mapped);
  }

  /// Starts routing actions from source to sink.
  ///
  /// No-op if already bound.
  void bind() {
    if (isBound) return;
    _source.addListener(_listener);
    _isBound = true;
  }

  /// Stops routing actions and releases the listener.
  ///
  /// No-op if not bound.
  void unbind() {
    if (!isBound) return;
    _source.removeListener(_listener);
    _isBound = false;
  }
}
