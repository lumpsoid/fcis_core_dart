// updater.dart

/// Pure reducer.
///
/// Maps (state, action) → (nextState, effects).
/// Must be a pure function — no I/O, no mutation, no side effects.
///
/// Returning an empty list and returning null are equivalent;
/// prefer an empty list for consistency.
///
/// Type parameters:
/// - [S] State
/// - [A] Action
/// - [E] Effect
abstract class Updater<S, A, E> {
  const Updater();

  (S, List<E>) update(S state, A action);
}
