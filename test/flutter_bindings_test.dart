import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vorzela_effector/flutter.dart';

void main() {
  testWidgets('UnitBuilder rebuilds and unsubscribes on dispose', (tester) async {
    final $count = createStore(0);
    final inc = createEvent();
    $count.on(inc, (s, _) => s + 1);

    await tester.pumpWidget(
      MaterialApp(
        home: UnitBuilder<int>(
          unit: $count,
          builder: (context, value) => Text('$value', key: const Key('v')),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect($count.subscriberCount, 1);

    inc();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect($count.subscriberCount, 0);

    // No throw / no listener after dispose.
    inc();
    expect($count.getState(), 2);
  });

  testWidgets('GateScope opens on mount and closes on dispose', (tester) async {
    final gate = createGate<String>(name: 'feature');
    final opens = <String?>[];
    final closes = <void>[];
    gate.open.to(opens.add);
    gate.close.to((_) => closes.add(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GateScope<String>(
          gate: gate,
          props: 'room-1',
          child: const Text('body'),
        ),
      ),
    );
    expect(gate.isOpen, isTrue);
    expect(opens, ['room-1']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(gate.isOpen, isFalse);
    expect(closes, isNotEmpty);
  });

  testWidgets('StatelessWidget counter via UnitBuilder', (tester) async {
    final $count = createStore(0);
    final inc = createEvent();
    $count.on(inc, (s, _) => s + 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitBuilder<int>(
            unit: $count,
            builder: (context, n) => TextButton(
              onPressed: () => inc(),
              child: Text('Count $n'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);
  });

  testWidgets('sibling UnitBuilders only rebuild the changed store',
      (tester) async {
    final $a = createStore(0);
    final $b = createStore(0);
    final setA = createEvent<int>();
    final setB = createEvent<int>();
    $a.on(setA, (_, v) => v);
    $b.on(setB, (_, v) => v);

    var buildsA = 0;
    var buildsB = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            UnitBuilder<int>(
              unit: $a,
              builder: (_, v) {
                buildsA++;
                return Text('a=$v', key: const Key('a'));
              },
            ),
            UnitBuilder<int>(
              unit: $b,
              builder: (_, v) {
                buildsB++;
                return Text('b=$v', key: const Key('b'));
              },
            ),
          ],
        ),
      ),
    );

    final afterMountA = buildsA;
    final afterMountB = buildsB;

    setA(1);
    await tester.pump();
    expect(find.text('a=1'), findsOneWidget);
    expect(buildsA, afterMountA + 1);
    expect(buildsB, afterMountB, reason: '\$b watcher must not setState');

    setB(9);
    await tester.pump();
    expect(find.text('b=9'), findsOneWidget);
    expect(buildsB, afterMountB + 1);
    expect(buildsA, afterMountA + 1, reason: '\$a watcher must not setState');
  });

  testWidgets('UnitBuilder child slot is not rebuilt when unit changes',
      (tester) async {
    final $n = createStore(0);
    final bump = createEvent();
    $n.on(bump, (s, _) => s + 1);

    var childBuilds = 0;
    var parentBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnitBuilder.withChild(
          unit: $n,
          builder: (context, n, child) {
            parentBuilds++;
            return Column(
              children: [
                Text('n=$n'),
                child!,
              ],
            );
          },
          child: Builder(
            builder: (context) {
              childBuilds++;
              return const Text('static');
            },
          ),
        ),
      ),
    );

    final childAtMount = childBuilds;
    final parentAtMount = parentBuilds;

    bump();
    await tester.pump();
    expect(find.text('n=1'), findsOneWidget);
    expect(parentBuilds, parentAtMount + 1);
    expect(childBuilds, childAtMount,
        reason: 'child Element is preserved — not recreated in builder');
  });

  testWidgets('nested UnitBuilder store change does not rebuild parent',
      (tester) async {
    final $outer = createStore(0);
    final $inner = createStore(0);
    final setOuter = createEvent<int>();
    final setInner = createEvent<int>();
    $outer.on(setOuter, (_, v) => v);
    $inner.on(setInner, (_, v) => v);

    var outerBuilds = 0;
    var innerBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnitBuilder.withChild(
          unit: $outer,
          builder: (context, o, child) {
            outerBuilds++;
            return Column(
              children: [
                Text('o=$o'),
                child!,
              ],
            );
          },
          child: UnitBuilder<int>(
            unit: $inner,
            builder: (_, i) {
              innerBuilds++;
              return Text('i=$i');
            },
          ),
        ),
      ),
    );

    final outerAtMount = outerBuilds;
    final innerAtMount = innerBuilds;

    setInner(5);
    await tester.pump();
    expect(find.text('i=5'), findsOneWidget);
    expect(innerBuilds, greaterThan(innerAtMount));
    expect(outerBuilds, outerAtMount,
        reason: 'parent UnitBuilder must not setState for nested unit');
  });
}
