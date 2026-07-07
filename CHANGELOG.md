## 0.3.0

- `FcisLoop` gains a terminal liveness guard: `close()`. Once closed,
  `dispatch`/`dispatchAsync` are permanent no-ops, so a late result from an
  in-flight effect can't write to a disposed state cell after the loop's owner
  is torn down. In-flight effects still complete; only their fed-back result is
  dropped. Close is not reversible — a closed loop is dead; build a fresh one
  to resume.
- Add `FcisLifecycle` interface (`close`) and `LifecycleActionSink<A>`
  (`ActionSink<A>` + `FcisLifecycle`) so consumers can depend on dispatch +
  teardown control through a narrow type instead of the whole `FcisLoop`.

## 1.0.0

- Initial version.
