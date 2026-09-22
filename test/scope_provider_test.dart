import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vorzela_effector/flutter.dart';

void main() {
  testWidgets('ScopeProvider UnitBuilder rebuilds from scoped state only',
      (tester) async {
    final $count = createStore(0, sid: 'ui.count');
    final inc = createEvent();
    $count.on(inc, (s, _) => s + 1);

    final scope = fork();

    await tester.pumpWidget(
      ScopeProvider(
        scope: scope,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: UnitBuilder<int>(
                unit: $count,
                builder: (context, v) => Text('count=$v'),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: bind(context, inc),
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('count=0'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('count=1'), findsOneWidget);
    expect($count.getState(), 0);
    expect(scope.getState($count), 1);
  });

  testWidgets('two ScopeProviders isolate sibling trees', (tester) async {
    final $n = createStore(0);
    final bump = createEvent();
    $n.on(bump, (s, _) => s + 1);

    final a = fork();
    final b = fork();

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(
              child: ScopeProvider(
                scope: a,
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      UnitBuilder<int>(
                        unit: $n,
                        builder: (_, v) => Text('a=$v'),
                      ),
                      TextButton(
                        onPressed: bind(context, bump),
                        child: const Text('bumpA'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ScopeProvider(
                scope: b,
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      UnitBuilder<int>(
                        unit: $n,
                        builder: (_, v) => Text('b=$v'),
                      ),
                      TextButton(
                        onPressed: bind(context, bump),
                        child: const Text('bumpB'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('bumpA'));
    await tester.pump();
    expect(find.text('a=1'), findsOneWidget);
    expect(find.text('b=0'), findsOneWidget);

    await tester.tap(find.text('bumpB'));
    await tester.pump();
    expect(find.text('a=1'), findsOneWidget);
    expect(find.text('b=1'), findsOneWidget);
    expect($n.getState(), 0);
  });


  testWidgets('ScopeProvider auto-forks when scope is omitted', (tester) async {
    final $n = createStore(0, name: 'auto.n');
    final bump = createEvent();
    $n.on(bump, (s, _) => s + 1);

    await tester.pumpWidget(
      ScopeProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: UnitBuilder<int>(
                unit: $n,
                builder: (_, v) => Text('n=$v'),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: bind(context, bump),
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('n=1'), findsOneWidget);
    expect($n.getState(), 0);
  });

  testWidgets('UnitAction fires inside ScopeProvider', (tester) async {
    final $n = createStore(0);
    final bump = createEvent();
    $n.on(bump, (s, _) => s + 1);
    final scope = fork();

    await tester.pumpWidget(
      ScopeProvider(
        scope: scope,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                UnitBuilder<int>(
                  unit: $n,
                  builder: (_, v) => Text('x=$v'),
                ),
                UnitAction(unit: bump, child: const Text('go')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('x=1'), findsOneWidget);
    expect(scope.getState($n), 1);
  });
}
