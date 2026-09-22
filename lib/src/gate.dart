import 'event.dart';
import 'store.dart';

/// Effector-react style Gate — open on mount, close on unmount (auto lifecycle).
final class Gate<T> {
  Gate({this.name}) {
    open = createEvent<T>(name: name == null ? null : '$name.open');
    close = createEvent(name: name == null ? null : '$name.close');
    $status = createStore<bool>(false, name: name == null ? null : '$name.status');
    $status.on(open, (_, __) => true);
    $status.on(close, (_, __) => false);
    $state = createStore<T?>(null, name: name == null ? null : '$name.state');
    $state.on(open, (_, payload) => payload);
    $state.on(close, (_, __) => null);
  }

  final String? name;
  late final Event<T> open;
  late final Event<void> close;
  late final Store<bool> $status;
  late final Store<T?> $state;

  bool get isOpen => $status.getState();

  void dispose() {
    open.dispose();
    close.dispose();
    $status.dispose();
    $state.dispose();
  }
}

Gate<T> createGate<T>({String? name}) => Gate<T>(name: name);
