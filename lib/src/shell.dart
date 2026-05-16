// effect_handler.dart

/// Executes a single effect and may dispatch actions back into the loop.
///
/// Implementations hold external dependencies (repositories, services, etc.)
/// as constructor-injected fields.
///
/// Type parameters:
/// - [E] Effect
/// - [A] Action
abstract class Shell<E, A> {
  const Shell();

  Future<void> run(E effect, {required void Function(A) dispatch});
}
