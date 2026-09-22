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
            builder: (context, life) {
              captured = life.textEditingController(text: 'hi');
              return TextField(controller: captured);
            },
          ),
        ),
      ),
    );

    expect(captured!.text, 'hi');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(() => captured!.addListener(() {}), throwsFlutterError);
  });

  testWidgets('Life keeps same controller across rebuilds', (tester) async {
    TextEditingController? first;
    TextEditingController? second;
    var tick = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AutoDispose(
                builder: (context, life) {
                  final c = life.textEditingController(text: 'x');
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

  testWidgets('bindText syncs store without stacking subscribers',
      (tester) async {
    final $name = createStore('');
    final setName = createEvent<String>();
    $name.on(setName, (_, v) => v);

    var tick = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AutoDispose(
                builder: (context, life) {
                  final c = life.bindText($name, setName.call);
                  return Column(
                    children: [
                      TextField(controller: c),
                      TextButton(
                        onPressed: () => setState(() => tick++),
                        child: Text('rebuild $tick'),
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

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    expect($name.getState(), 'Ada');
    // One bindText subscription only (plus nothing stacked on rebuild).
    expect($name.subscriberCount, 1);

    await tester.tap(find.text('rebuild 0'));
    await tester.pump();
    expect($name.subscriberCount, 1);

    setName('Bob');
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect($name.subscriberCount, 0);
  });

  testWidgets('StoreTextField accepts event shorthand', (tester) async {
    final $email = createStore('');
    final setEmail = createEvent<String>();
    $email.on(setEmail, (_, v) => v);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreTextField(
            store: $email,
            event: setEmail,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a@b.c');
    await tester.pump();
    expect($email.getState(), 'a@b.c');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect($email.subscriberCount, 0);
  });

  testWidgets('AutoDisposeMixin disposes AnimationController', (tester) async {
    AnimationController? anim;

    await tester.pumpWidget(
      MaterialApp(
        home: _AnimProbe(onReady: (c) => anim = c),
      ),
    );
    await tester.pump();
    expect(anim, isNotNull);

    // Unmount: AutoDisposeMixin must dispose the AnimationController before
    // TickerProviderStateMixin, or Flutter asserts on leaked tickers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _AnimProbe extends StatefulWidget {
  const _AnimProbe({required this.onReady});
  final void Function(AnimationController c) onReady;

  @override
  State<_AnimProbe> createState() => _AnimProbeState();
}

class _AnimProbeState extends State<_AnimProbe>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  @override
  Widget build(BuildContext context) {
    return buildWithLife((life) {
      final c = life.animationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
      );
      widget.onReady(c);
      return const SizedBox.shrink();
    });
  }
}
