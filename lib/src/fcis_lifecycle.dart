/// Terminal teardown for a running FCIS loop.
///
/// A loop can outlive the widget/scope that owns it: an in-flight effect may
/// complete and try to dispatch a result back after the owner is torn down.
/// [close] permanently suppresses dispatching so that late result can't write
/// to a disposed state cell.
///
/// A closed loop is dead — there is no reopen. The only way forward is to
/// build a fresh loop. This is deliberate: it forces per-use loops to be
/// created (and discarded) with their owner, rather than kept as long-lived
/// singletons.
abstract class FcisLifecycle {
  /// Permanently suppresses further dispatching. Idempotent; not reversible.
  void close();
}
