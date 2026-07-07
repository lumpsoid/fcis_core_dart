import 'package:fcis_core/fcis_core.dart';
import 'package:test/test.dart';

/// Minimal in-memory state cell for driving the loop under test.
class _Holder<S> implements StateHolder<S> {
  _Holder(this._state);

  S _state;

  @override
  S get state => _state;

  @override
  void update(S next) => _state = next;
}

/// Counts up on every action and emits one effect per dispatch.
class _CountUpdater extends Updater<int, void, void> {
  const _CountUpdater();

  @override
  (int, List<void>?) update(int state, void action) => (state + 1, [null]);
}

/// Records how many effects it was asked to run.
class _RecordingRunner extends EffectRunner<void, void> {
  int runs = 0;

  @override
  Future<void> run(List<void>? effects, void Function(void) dispatch) async {
    if (effects == null || effects.isEmpty) return;
    runs += effects.length;
  }
}

void main() {
  group('FcisLoop liveness guard', () {
    late _Holder<int> holder;
    late _RecordingRunner runner;
    late FcisLoop<int, void, void> loop;

    setUp(() {
      holder = _Holder<int>(0);
      runner = _RecordingRunner();
      loop = FcisLoop<int, void, void>(
        stateHolder: holder,
        updater: const _CountUpdater(),
        effectRunner: runner,
      );
    });

    test('dispatches while open', () async {
      await loop.dispatchAsync(null);

      expect(holder.state, 1);
      expect(runner.runs, 1);
    });

    test('close() suppresses state write and effect run', () async {
      loop.close();
      await loop.dispatchAsync(null);

      expect(holder.state, 0, reason: 'no state write while closed');
      expect(runner.runs, 0, reason: 'no effects run while closed');
    });

    test('close() is terminal — dispatch stays a no-op', () async {
      loop
        ..close()
        ..dispatch(null);
      await loop.dispatchAsync(null);

      expect(holder.state, 0);
      expect(runner.runs, 0);
    });
  });
}
