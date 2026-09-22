import 'package:flutter_test/flutter_test.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

/// Large-state smoke tests — assert latency budgets so regressions fail CI.
void main() {
  test('10k list store: write + map + scoped fork stay under budget', () async {
    final items = List<Map<String, Object>>.generate(
      10000,
      (i) => {'id': i, 'title': 'Product $i', 'price': i % 100},
    );
    final $catalog = createStore(items, name: 'catalog');
    final $count = $catalog.map((list) => list.length, name: 'catalog.count');
    final set = createEvent<List<Map<String, Object>>>();
    $catalog.on(set, (_, v) => v);

    final sw = Stopwatch()..start();
    final next = List<Map<String, Object>>.from(items)..[0] = {
      'id': 0,
      'title': 'Updated',
      'price': 1,
    };
    set(next);
    expect($count.getState(), 10000);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(200),
        reason: 'global list write+map should be cheap');

    final scope = fork();
    final other = List<Map<String, Object>>.generate(
      10000,
      (i) => {'id': i, 'title': 'Scoped $i', 'price': 0},
    );
    final sw2 = Stopwatch()..start();
    // ignore: discarded_futures
    await allSettled(set, scope: scope, params: other);
    expect(scope.getState($catalog)[0]['title'], 'Scoped 0');
    expect(scope.getState($count), 10000);
    expect($catalog.getState()[0]['title'], 'Updated');
    sw2.stop();
    expect(sw2.elapsedMilliseconds, lessThan(500));
  });

  test('1k nested map objects: skip-equal avoids notify storm', () {
    final nested = <String, dynamic>{
      for (var i = 0; i < 1000; i++)
        'k$i': {
          'a': i,
          'b': List.generate(5, (j) => {'x': j}),
        },
    };
    final $doc = createStore(nested, name: 'doc');
    var notifies = 0;
    $doc.watch((_) => notifies++);

    final set = createEvent<Map<String, dynamic>>();
    $doc.on(set, (_, v) => v);

    set(nested); // same reference / equal map contents after == 
    // Map == is identity/deep? In Dart Map == is deep for contents if both Maps
    // Actually Map equality is deep equality in Dart for LinkedHashMap.
    // identical check first in _set - same reference → no notify
    set(nested);
    expect(notifies, 0);

    final copy = Map<String, dynamic>.from(nested);
    copy['k0'] = {
      'a': 999,
      'b': List.generate(5, (j) => {'x': j}),
    };
    set(copy);
    expect(notifies, 1);
  });

  test('5k store graph: createStore+map+dispose does not explode', () {
    final sw = Stopwatch()..start();
    final stores = <Store<int>>[];
    for (var i = 0; i < 5000; i++) {
      final $s = createStore(i, name: 's$i');
      stores.add($s.map((v) => v + 1));
    }
    for (final s in stores) {
      s.dispose();
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });

  test('concurrent forks with large payloads stay isolated', () async {
    final $bag = createStore(<int>[], name: 'bag');
    final push = createEvent<List<int>>();
    $bag.on(push, (_, v) => v);

    final a = fork();
    final b = fork();
    final bigA = List<int>.generate(8000, (i) => i);
    final bigB = List<int>.generate(8000, (i) => -i);

    await Future.wait([
      allSettled(push, scope: a, params: bigA),
      allSettled(push, scope: b, params: bigB),
    ]);

    expect($bag.getState(), isEmpty);
    expect(a.getState($bag).length, 8000);
    expect(a.getState($bag)[1], 1);
    expect(b.getState($bag)[1], -1);
  });
}

