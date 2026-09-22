import 'package:flutter/widgets.dart';
import 'package:vorzela_effector/flutter.dart';

final $cart = createStore(0);
final fetchUserFx = createEffect<void, void>((_) async {});
final incremented = createEvent();

class GoodPage extends StatelessWidget {
  const GoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopeProvider(
      child: UnitBuilder<int>(
        unit: $cart,
        builder: (context, count) => UnitAction(
          unit: incremented,
          child: Text('$count'),
        ),
      ),
    );
  }
}
