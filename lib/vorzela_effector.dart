/// Effector-style reactive state for Dart.
///
/// ```dart
/// final \$count = createStore(0);
/// final inc = createEvent();
/// \$count.on(inc, (s, _) => s + 1);
/// inc();
/// ```
library;

export 'src/combine.dart';
export 'src/effect.dart';
export 'src/event.dart';
export 'src/gate.dart';
export 'src/kernel.dart' show Kernel;
export 'src/sample.dart';
export 'src/scope.dart';
export 'src/store.dart';
export 'src/unit.dart' show Unit, Subscription, Subscriber;
