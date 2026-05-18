import 'package:fcis_core/src/listener_list.dart';
import 'package:test/test.dart';

void main() {
  group('initial state', () {
    test('hasListeners is false on a fresh instance', () {
      final list = ListenerList<int>();
      expect(list.hasListeners, isFalse);
    });
  });

  group('add', () {
    test('hasListeners becomes true after first add', () {
      final list = ListenerList<int>();
      list.add((_) {});
      expect(list.hasListeners, isTrue);
    });

    test('single listener is called on notify', () {
      final log = <int>[];
      final list = ListenerList<int>();
      list.add(log.add);
      list.notify(42);
      expect(log, [42]);
    });

    test('multiple listeners are all called', () {
      final log = <int>[];
      final list = ListenerList<int>();
      list.add((_) => log.add(1));
      list.add((_) => log.add(2));
      list.add((_) => log.add(3));
      list.notify(0);
      expect(log, [1, 2, 3]);
    });

    test('listeners are called in registration order', () {
      final order = <int>[];
      final list = ListenerList<int>();
      for (var i = 0; i < 10; i++) {
        final id = i;
        list.add((_) => order.add(id));
      }
      list.notify(0);
      expect(order, List.generate(10, (i) => i));
    });

    test('duplicate registrations each fire independently', () {
      final log = <int>[];
      void cb(int v) => log.add(v);
      final list = ListenerList<int>();
      list.add(cb);
      list.add(cb);
      list.notify(7);
      expect(log, [7, 7]);
    });

    test('listeners added during notify are not called in that same round', () {
      final log = <String>[];
      final list = ListenerList<int>();

      list.add((_) {
        log.add('original');
        list.add((_) => log.add('late'));
      });

      list.notify(0);
      expect(log, ['original']);
    });

    test('listener added during notify is called in the next notify', () {
      final log = <String>[];
      final list = ListenerList<int>();

      list.add((_) {
        log.add('original');
        list.add((_) => log.add('late'));
      });

      list.notify(0);
      log.clear();
      list.notify(0);
      expect(log, containsAll(['original', 'late']));
    });

    test(
      'backing array growth beyond initial capacity works without error',
      () {
        final list = ListenerList<int>();
        var count = 0;
        for (var i = 0; i < 100; i++) {
          list.add((_) => count++);
        }
        list.notify(0);
        expect(count, 100);
      },
    );
  });

  group('remove (outside notify)', () {
    test('removed listener is not called', () {
      final log = <int>[];
      void cb(int v) => log.add(v);
      final list = ListenerList<int>();
      list.add(cb);
      list.remove(cb);
      list.notify(1);
      expect(log, isEmpty);
    });

    test('hasListeners becomes false after last listener removed', () {
      void cb(int v) {}
      final list = ListenerList<int>();
      list.add(cb);
      list.remove(cb);
      expect(list.hasListeners, isFalse);
    });

    test('only the first occurrence of a duplicate is removed', () {
      final log = <int>[];
      void cb(int v) => log.add(v);
      final list = ListenerList<int>();
      list.add(cb);
      list.add(cb);
      list.remove(cb);
      list.notify(3);
      expect(log, [3]); // one occurrence remains
    });

    test('no notify after both occurrence of a duplicate is removed', () {
      final log = <int>[];
      void cb(int v) => log.add(v);
      final list = ListenerList<int>();
      list.add(cb);
      list.add(cb);
      list.remove(cb);
      list.remove(cb);
      list.notify(3);
      expect(log, []);
    });

    test('removing an unregistered listener is a no-op', () {
      final log = <int>[];
      final list = ListenerList<int>();
      list.add((_) => log.add(1));
      expect(() => list.remove((_) {}), returnsNormally);
      list.notify(0);
      expect(log, [1]);
    });

    test('order of remaining listeners is preserved after middle removal', () {
      final log = <int>[];
      void a(int v) => log.add(1);
      void b(int v) => log.add(2);
      void c(int v) => log.add(3);
      final list = ListenerList<int>();
      list.add(a);
      list.add(b);
      list.add(c);
      list.remove(b);
      list.notify(0);
      expect(log, [1, 3]);
    });

    test('order of remaining listeners is preserved after first removal', () {
      final log = <int>[];
      void a(int v) => log.add(1);
      void b(int v) => log.add(2);
      void c(int v) => log.add(3);
      final list = ListenerList<int>();
      list.add(a);
      list.add(b);
      list.add(c);
      list.remove(a);
      list.notify(0);
      expect(log, [2, 3]);
    });

    test('order of remaining listeners is preserved after last removal', () {
      final log = <int>[];
      void a(int v) => log.add(1);
      void b(int v) => log.add(2);
      void c(int v) => log.add(3);
      final list = ListenerList<int>();
      list.add(a);
      list.add(b);
      list.add(c);
      list.remove(c);
      list.notify(0);
      expect(log, [1, 2]);
    });

    test('repeated add/remove cycles leave the list empty', () {
      final log = <int>[];
      void cb(int v) => log.add(v);
      final list = ListenerList<int>();
      for (var round = 0; round < 5; round++) {
        list.add(cb);
        list.remove(cb);
      }
      list.notify(99);
      expect(log, isEmpty);
    });

    test('re-add after remove fires again', () {
      final log = <int>[];
      void cb(int v) => log.add(v);
      final list = ListenerList<int>();
      list.add(cb);
      list.remove(cb);
      list.add(cb);
      list.notify(5);
      expect(log, [5]);
    });

    test('removing many listeners in sequence leaves correct survivors', () {
      final list = ListenerList<int>();
      final fired = <int>[];
      final cbs = List.generate(20, (i) {
        void cb(int v) => fired.add(i);
        return cb;
      });
      for (final cb in cbs) {
        list.add(cb);
      }
      for (var i = 0; i < cbs.length; i += 2) {
        list.remove(cbs[i]);
      }
      list.notify(0);
      expect(fired, List.generate(10, (i) => i * 2 + 1));
    });
  });

  group('notify basics', () {
    test('notify on empty list is a no-op', () {
      expect(() => ListenerList<int>().notify(0), returnsNormally);
    });

    test('correct value is forwarded to every listener', () {
      final received = <int>[];
      final list = ListenerList<int>();
      list.add(received.add);
      list.add(received.add);
      list.notify(123);
      expect(received, [123, 123]);
    });

    test('multiple sequential notifies each reach all listeners', () {
      var calls = 0;
      final list = ListenerList<int>();
      list.add((_) => calls++);
      list.notify(1);
      list.notify(2);
      list.notify(3);
      expect(calls, 3);
    });

    test('notify after all listeners removed is a no-op', () {
      void cb(int v) {}
      final list = ListenerList<int>();
      list.add(cb);
      list.remove(cb);
      expect(() => list.notify(0), returnsNormally);
    });
  });

  group('remove during notify (tombstone)', () {
    test('listener removed before its slot fires is skipped', () {
      final log = <String>[];
      final list = ListenerList<int>();
      late void Function(int) b;
      list.add((_) {
        log.add('a');
        list.remove(b);
      });
      b = (_) => log.add('b');
      list.add(b);
      list.notify(0);
      expect(log, ['a']);
    });

    test('listener removed after it already ran does not double-fire', () {
      final log = <String>[];
      final list = ListenerList<int>();
      late void Function(int) a;
      a = (_) => log.add('a');
      list.add(a);
      list.add((_) {
        log.add('b');
        list.remove(a);
      });
      list.notify(0);
      expect(log, ['a', 'b']);
    });

    test('self-removal during notify is safe', () {
      final log = <int>[];
      final list = ListenerList<int>();
      late void Function(int) cb;
      cb = (v) {
        log.add(v);
        list.remove(cb);
      };
      list.add(cb);
      list.notify(1);
      expect(log, [1]);

      log.clear();
      list.notify(1);
      expect(log, isEmpty);
    });

    test('tombstoned listeners absent from subsequent notifies', () {
      final log = <String>[];
      final list = ListenerList<int>();
      late void Function(int) b;
      list.add((_) => list.remove(b));
      b = (_) => log.add('b');
      list.add(b);

      list.notify(0);
      log.clear();
      list.notify(0);
      expect(log, isEmpty);
    });

    test('all listeners self-remove -> hasListeners false after notify', () {
      final list = ListenerList<int>();
      late void Function(int) a, b, c;
      a = (_) => list.remove(a);
      b = (_) => list.remove(b);
      c = (_) => list.remove(c);
      list.add(a);
      list.add(b);
      list.add(c);
      list.notify(0);
      expect(list.hasListeners, isFalse);
    });

    test('survivors after tombstone compaction still fire correctly', () {
      final log = <int>[];
      final list = ListenerList<int>();
      late void Function(int) victim;
      victim = (_) {};
      list.add((_) => list.remove(victim));
      list.add(victim);
      list.add((v) => log.add(v));

      list.notify(0);
      log.clear();
      list.notify(9);
      expect(log, [9]);
    });

    test('multiple tombstones in one notify all cleaned up', () {
      final list = ListenerList<int>();
      final fired = <int>[];
      late void Function(int) v1, v2, v3;
      v1 = (_) {};
      v2 = (_) {};
      v3 = (_) {};

      list.add((_) => list.remove(v1));
      list.add(v1);
      list.add((_) => list.remove(v2));
      list.add(v2);
      list.add((_) => list.remove(v3));
      list.add(v3);
      list.add((v) => fired.add(v));

      list.notify(0);
      fired.clear();
      list.notify(5);
      // Only the three triggers and the survivor should remain.
      expect(fired, [5]);
    });
  });

  group('nested (reentrant) notify', () {
    test('inner notify visits listeners registered before the inner call', () {
      final log = <String>[];
      final list = ListenerList<int>();

      list.add((v) {
        log.add('a:$v');
        if (v == 1) list.notify(2);
      });
      list.add((v) => log.add('b:$v'));

      list.notify(1);
      expect(log, ['a:1', 'a:2', 'b:2', 'b:1']);
    });

    test('removal during inner notify is reflected after outer exits', () {
      final log = <int>[];
      final list = ListenerList<int>();
      late void Function(int) removable;
      removable = (v) => log.add(v);

      list.add((v) {
        if (v == 1) {
          list.remove(removable);
          list.notify(2); // inner
        }
      });
      list.add(removable);

      list.notify(1);
      log.clear();
      list.notify(3);
      expect(log, isEmpty); // removable is gone
    });
  });

  group('exception safety', () {
    test('exception in a listener propagates to caller', () {
      final list = ListenerList<int>();
      list.add((_) => throw StateError('boom'));
      expect(() => list.notify(0), throwsStateError);
    });

    test('listeners after a throwing one are not called', () {
      final log = <int>[];
      final list = ListenerList<int>();
      list.add((_) => throw StateError('boom'));
      list.add((_) => log.add(1));
      expect(() => list.notify(0), throwsStateError);
      expect(log, isEmpty);
    });

    test('list is usable after an exception during notify', () {
      final list = ListenerList<int>();
      late void Function(int) bad;
      bad = (_) {
        list.remove(bad);
        throw StateError('boom');
      };
      list.add(bad);

      expect(() => list.notify(0), throwsStateError);

      final log = <int>[];
      list.add(log.add);
      list.notify(7);
      expect(log, [7]);
    });
  });

  group('generic type parameter', () {
    test('works with String values', () {
      final log = <String>[];
      final list = ListenerList<String>();
      list.add(log.add);
      list.notify('hello');
      expect(log, ['hello']);
    });

    test('works with nullable int values', () {
      final log = <int?>[];
      final list = ListenerList<int?>();
      list.add(log.add);
      list.notify(null);
      list.notify(42);
      expect(log, [null, 42]);
    });

    test('works with custom object values', () {
      final list = ListenerList<List<int>>();
      List<int>? captured;
      list.add((v) => captured = v);
      list.notify([1, 2, 3]);
      expect(captured, [1, 2, 3]);
    });
  });

  group('stress', () {
    test('100 listeners all fire after heavy add/remove churn', () {
      final list = ListenerList<int>();
      var fired = 0;
      final cbs = List.generate(200, (_) {
        void cb(int v) => fired++;
        return cb;
      });
      for (final cb in cbs) {
        list.add(cb);
      }
      for (var i = 0; i < cbs.length; i += 2) {
        list.remove(cbs[i]);
      }
      list.notify(0);
      expect(fired, 100);
    });

    test('1000 sequential notifies accumulate correctly', () {
      var count = 0;
      final list = ListenerList<int>();
      list.add((_) => count++);
      for (var i = 0; i < 1000; i++) {
        list.notify(i);
      }
      expect(count, 1000);
    });

    test('repeated tombstone/compact cycles leave list consistent', () {
      final list = ListenerList<int>();
      var survived = 0;
      void keeper(int v) => survived++;
      list.add(keeper);
      list.notify(0); // initial fire

      for (var round = 0; round < 50; round++) {
        late void Function(int) temp;
        temp = (_) => list.remove(temp);
        list.add(temp);
        list.notify(0);
      }

      expect(survived, 51); // 1 initial + 50 rounds
      expect(list.hasListeners, isTrue);
    });
  });
}
