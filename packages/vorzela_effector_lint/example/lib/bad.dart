import 'package:flutter/widgets.dart';
import 'package:vorzela_effector/flutter.dart';

// expect_lint: prefer_dollar_store_name
final cart = createStore(0);

// expect_lint: prefer_fx_effect_name
final fetchUser = createEffect<void, void>((_) async {});

final incremented = createEvent();

// expect_lint: avoid_create_event_typed
final typed = createEventTyped<int>();

class BadPage extends StatelessWidget {
  const BadPage({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_create_unit_in_widget
    final $local = createStore(1);
    // expect_lint: avoid_get_state_in_widget
    final v = $local.getState();
    // expect_lint: avoid_watch_in_widget
    $local.watch((_) {});
    return ScopeProvider(
      child: GestureDetector(
        // expect_lint: prefer_bind_in_widget
        onTap: () => incremented(),
        child: Text('$v'),
      ),
    );
  }
}
