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
}
