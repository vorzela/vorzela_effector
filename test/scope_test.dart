import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

void main() {
  test('overlapping concurrent allSettled on different scopes stay isolated',
      () async {
    final $n = createStore(0, sid: 'n');
    final bump = createEventTyped<int>();
    $n.on(bump, (s, v) => s + v);

    final scopeA = fork();
    final scopeB = fork();

    final gate = Completer<void>();
    final slow = createEffect<int, int>((v) async {
      await gate.future;
      return v;
    });
    // Drive store via effect done → sample-like: on done write
    slow.done.to((d) {
      bump(d.result);
    });

    final fa = allSettled(slow, scope: scopeA, params: 10);
    final fb = allSettled(slow, scope: scopeB, params: 3);
    gate.complete();
    await Future.wait([fa, fb]);

    expect($n.getState(), 0);
    expect(scopeA.getState($n), 10);
    expect(scopeB.getState($n), 3);
  });

  test('scoped source write recomputes .map and combine inside the fork',
      () async {
    final $price = createStore(10, sid: 'price');
    final $qty = createStore(2, sid: 'qty');
    final setPrice = createEventTyped<int>();
    $price.on(setPrice, (_, v) => v);

    final $line = $price.map((p) => p * 2, sid: 'line');
    final $total = combine2($price, $qty, (p, q) => p * q, sid: 'total');

    final scope = fork();
    await allSettled(setPrice, scope: scope, params: 5);

    expect($price.getState(), 10);
    expect($line.getState(), 20);
    expect($total.getState(), 20);

    expect(scope.getState($price), 5);
    expect(scope.getState($line), 10);
    expect(scope.getState($total), 10);
  });

  test('scope-local watch fires on scoped writes only', () async {
    final $n = createStore(0);
    final bump = createEvent();
    $n.on(bump, (s, _) => s + 1);

    final scope = fork();
    final scoped = <int>[];
    final global = <int>[];
    scope.watchStore($n, scoped.add);
    // Global watch (no zone scope):
    $n.watch(global.add);

    await allSettled(bump, scope: scope);
    expect(scoped, [1]);
    expect(global, isEmpty);
    expect($n.getState(), 0);

    bump(); // global
    expect(global, [1]);
    expect(scoped, [1]);
  });

  test('fork handlers override effect body for that scope only', () async {
    var realCalls = 0;
    final fx = createEffect<int, int>((n) async {
      realCalls++;
      return n * 2;
    });
    final $out = createStore(0, sid: 'out');
    fx.done.to((d) => $out.write(d.result));

    final scope = fork(
      handlers: [
        (fx, (int n) async => n + 100),
      ],
    );

    await allSettled(fx, scope: scope, params: 5);
    expect(realCalls, 0);
    expect(scope.getState($out), 105);
    expect($out.getState(), 0);

    await allSettled(fx, params: 5);
    expect(realCalls, 1);
    expect($out.getState(), 10);
  });

  test('serialize / hydrate round-trip with sid', () async {
    final $cart = createStore(0, sid: 'cart.count');
    final add = createEventTyped<int>();
    $cart.on(add, (s, v) => s + v);

    final server = fork();
    await allSettled(add, scope: server, params: 3);
    await allSettled(add, scope: server, params: 2);

    final payload = serialize(server);
    expect(payload, {'cart.count': 5});

    final client = fork();
    hydrate(client, payload);
    expect(client.getState($cart), 5);
    expect($cart.getState(), 0);
  });

  test('fork(valuesMap:) seeds by sid', () {
    final $user = createStore('guest', sid: 'user');
    final scope = fork(valuesMap: {'user': 'alice'});
    expect(scope.getState($user), 'alice');
  });

  test('ecommerce: parallel catalog + cart scopes do not leak', () async {
    final $items = createStore(<String>[], sid: 'catalog.items');
    final $cart = createStore(<String>[], sid: 'cart.lines');
    final setItems = createEventTyped<List<String>>();
    final addLine = createEventTyped<String>();
    $items.on(setItems, (_, v) => v);
    $cart.on(addLine, (s, v) => [...s, v]);

    final catalogScope = fork();
    final checkoutScope = fork(values: [
      ($cart, <String>['sku-a']),
    ]);

    await Future.wait([
      allSettled(setItems, scope: catalogScope, params: ['a', 'b', 'c']),
      allSettled(addLine, scope: checkoutScope, params: 'sku-b'),
    ]);

    expect($items.getState(), isEmpty);
    expect($cart.getState(), isEmpty);
    expect(catalogScope.getState($items), ['a', 'b', 'c']);
    expect(checkoutScope.getState($cart), ['sku-a', 'sku-b']);
    expect(catalogScope.getState($cart), isEmpty);
  });


  test('sample target store writes stay inside the active scope', () async {
    final $src = createStore('a', sid: 'src');
    final $dst = createStore('', sid: 'dst');
    final clock = createEvent();
    sample(clock: clock, source: $src, target: $dst);

    final scope = fork(values: [($src, 'scoped')]);
    await allSettled(clock, scope: scope);

    expect($dst.getState(), '');
    expect(scope.getState($dst), 'scoped');
  });

  test('reset inside a scope restores defaultState in that scope only', () async {
    final $n = createStore(0, sid: 'n.reset');
    final set = createEventTyped<int>();
    final clear = createEvent();
    $n.on(set, (_, v) => v);
    $n.reset(clear);

    final scope = fork();
    await allSettled(set, scope: scope, params: 9);
    expect(scope.getState($n), 9);
    await allSettled(clear, scope: scope);
    expect(scope.getState($n), 0);
    expect($n.getState(), 0);
  });
}
