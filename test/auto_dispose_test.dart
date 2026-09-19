import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vorzela_effector/flutter.dart';

void main() {
  testWidgets('AutoDispose disposes TextEditingController', (tester) async {
    TextEditingController? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutoDispose(
            builder: (context, d) {
              captured = d.textEditingController(text: 'hi');
              return TextField(controller: captured);
            },
          ),
        ),
      ),
    );

    expect(captured, isNotNull);
    expect(captured!.text, 'hi');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // ChangeNotifier throws once disposed.
    expect(() => captured!.addListener(() {}), throwsFlutterError);
  });

  testWidgets('AutoDispose keeps same controller across rebuilds',
      (tester) async {
    TextEditingController? first;
    TextEditingController? second;
    var tick = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AutoDispose(
                builder: (context, d) {
                  final c = d.textEditingController(text: 'x');
                  if (tick == 0) {
                    first = c;
                  } else {
                    second = c;
                  }
                  return Column(
                    children: [
                      TextField(controller: c),
                      TextButton(
                        onPressed: () => setState(() => tick++),
                        child: const Text('rebuild'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('rebuild'));
    await tester.pump();

    expect(identical(first, second), isTrue);
  });

  testWidgets('StoreTextField syncs store and auto-disposes controller',
      (tester) async {
    final $name = createStore('');
    final setName = createEventTyped<String>();
    $name.on(setName, (_, v) => v);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreTextField(
            store: $name,
            onChanged: setName.call,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    expect($name.getState(), 'Ada');

    setName('Bob');
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect($name.subscriberCount, 0);
  });
}
