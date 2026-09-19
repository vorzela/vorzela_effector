import 'package:flutter_test/flutter_test.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

void main() {
  test('store.on event updates state', () {
    final $count = createStore(0);
    final inc = createEvent();
    $count.on(inc, (s, _) => s + 1);

    expect($count.getState(), 0);
    inc();
    expect($count.getState(), 1);
    inc();
    expect($count.getState(), 2);
  });

  test('watch notifies subscribers', () {
    final $n = createStore(0);
    final set = createEventTyped<int>();
    $n.on(set, (_, v) => v);

    final seen = <int>[];
    final sub = $n.watch(seen.add);
    set(10);
    set(20);
    expect(seen, [10, 20]);
    sub.unsubscribe();
    set(30);
    expect(seen, [10, 20]);
  });

  test('map creates derived store', () {
    final $n = createStore(2);
    final doubleIt = createEvent();
    $n.on(doubleIt, (s, _) => s * 2);
    final $sq = $n.map((v) => v * v);

    expect($sq.getState(), 4);
    doubleIt();
    expect($n.getState(), 4);
    expect($sq.getState(), 16);
  });

  test('combine2 derives from two stores', () {
    final $a = createStore(1);
    final $b = createStore(2);
    final setA = createEventTyped<int>();
    final setB = createEventTyped<int>();
    $a.on(setA, (_, v) => v);
    $b.on(setB, (_, v) => v);
    final $sum = combine2($a, $b, (a, b) => a + b);

    expect($sum.getState(), 3);
    setA(5);
    expect($sum.getState(), 7);
  });

  test('sample clocks source into target', () {
    final $form = createStore('hello');
    final submit = createEvent();
    final saved = <String>[];
    final save = createEventTyped<String>();
    save.to(saved.add);

    sample(
      clock: submit,
      source: $form,
      fn: (form, _) => form as String,
      target: save,
    );

    submit();
    expect(saved, ['hello']);
  });

  test('effect done and pending', () async {
    final fx = createEffect<int, int>((n) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return n * 2;
    });

    final results = <int>[];
    fx.done.to((d) => results.add(d.result));

    expect(fx.$pending.getState(), isFalse);
    final future = fx(3);
    expect(fx.$pending.getState(), isTrue);
    expect(await future, 6);
    expect(fx.$pending.getState(), isFalse);
    expect(results, [6]);
  });

  test('stale effect results are ignored after newer call', () async {
    final results = <int>[];
    final fx = createEffect<int, int>((n) async {
      await Future<void>.delayed(Duration(milliseconds: n));
      return n;
    });
    fx.done.to((d) => results.add(d.result));

    final slow = fx(50);
    final fast = fx(5);
    await fast;
    await slow;
    // Only the latest generation should commit.
    expect(results, [5]);
  });

  test('abort ignores late effect result', () async {
    final results = <int>[];
    final fx = createEffect<void, int>((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return 1;
    });
    fx.done.to((d) => results.add(d.result));

    final f = fx(null);
    fx.abort();
    await f;
    expect(results, isEmpty);
    expect(fx.$pending.getState(), isFalse);
  });

  test('gate open close status', () {
    final gate = createGate<String>(name: 'page');
    expect(gate.isOpen, isFalse);
    gate.open('props');
    expect(gate.isOpen, isTrue);
    expect(gate.$state.getState(), 'props');
    gate.close();
    expect(gate.isOpen, isFalse);
    expect(gate.$state.getState(), isNull);
  });

  test('scope dispose clears owned units', () {
    final scope = fork();
    final $s = createStore(0);
    final ev = createEvent();
    $s.on(ev, (s, _) => s + 1);
    scope.own($s);
    scope.own(ev);
    ev();
    expect($s.getState(), 1);
    scope.dispose();
    expect(scope.isDisposed, isTrue);
    expect($s.isDisposed, isTrue);
  });

  test('store dispose unsubscribes watchers', () {
    final $s = createStore(0);
    final set = createEventTyped<int>();
    $s.on(set, (_, v) => v);
    var calls = 0;
    $s.watch((_) => calls++);
    set(1);
    expect(calls, 1);
    $s.dispose();
    expect(() => $s.watch((_) {}), throwsStateError);
  });

  test('scope.setState does not mutate global store', () {
    final $s = createStore(0);
    final scope = fork();
    scope.setState($s, 99);
    expect(scope.getState($s), 99);
    expect($s.getState(), 0);
  });

  test('sample link is torn down when target is disposed', () {
    final clock = createEvent();
    final target = createEventTyped<int>();
    final seen = <int>[];
    target.to(seen.add);

    sample(
      clock: clock,
      source: createStore(7),
      fn: (s, _) => s as int,
      target: target,
    );

    clock();
    expect(seen, [7]);
    target.dispose();
    clock();
    expect(seen, [7]);
  });

  test('overlapping effects clear \$pending when stale call finishes last',
      () async {
    final fx = createEffect<int, int>((n) async {
      await Future<void>.delayed(Duration(milliseconds: n));
      return n;
    });

    final slow = fx(40);
    final fast = fx(5);
    await fast;
    await slow;
    expect(fx.$pending.getState(), isFalse);
  });

  test('combine recomputes once per batch', () {
    final $a = createStore(1);
    final $b = createStore(2);
    final setA = createEventTyped<int>();
    final setB = createEventTyped<int>();
    $a.on(setA, (_, v) => v);
    $b.on(setB, (_, v) => v);

    var computes = 0;
    final $sum = combine([$a, $b], (vals) {
      computes++;
      return (vals[0] as int) + (vals[1] as int);
    });

    expect($sum.getState(), 3);
    final baseline = computes;

    Kernel.instance.batch(() {
      setA(10);
      setB(20);
    });

    expect($sum.getState(), 30);
    expect(computes - baseline, 1);
  });

  test('unsubscribe is identity-based for duplicate listeners', () {
    final $s = createStore(0);
    final set = createEventTyped<int>();
    $s.on(set, (_, v) => v);

    void listener(int _) {}
    final a = $s.watch(listener);
    final b = $s.watch(listener);
    expect($s.subscriberCount, 2);
    a.unsubscribe();
    expect($s.subscriberCount, 1);
    b.unsubscribe();
    expect($s.subscriberCount, 0);
  });

  test('nested combine settles in the same flush', () {
    final $a = createStore(1);
    final setA = createEventTyped<int>();
    $a.on(setA, (_, v) => v);

    final $doubled = combine([$a], (vals) => (vals[0] as int) * 2);
    final $plusOne = combine([$doubled], (vals) => (vals[0] as int) + 1);

    setA(5);
    // Without dirty re-drain, $plusOne would still be stale until next tick.
    expect($doubled.getState(), 10);
    expect($plusOne.getState(), 11);
  });

  test('kernel fails fast on runaway self-update loop', () {
    final $s = createStore(0);
    final bump = createEventTyped<int>();
    $s.on(bump, (_, v) => v);
    // Watcher writes the same store → unbounded dirty cascade.
    final sub = $s.watch((v) {
      if (v < 100000) bump(v + 1);
    });

    expect(() => bump(1), throwsStateError);
    sub.unsubscribe();

    // Kernel recovers for subsequent batches.
    bump(0);
    expect($s.getState(), 0);
  });
}

