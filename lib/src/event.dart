import 'kernel.dart';
import 'unit.dart';

/// Effector-style event — call like a function: `incremented()` / `setName('a')`.
final class Event<T> extends Unit with Subscribable<T> {
  Event({super.name});

  final List<void Function(T)> _handlers = [];

  /// Subscribe a side-effect handler (graph links use this internally).
  Subscription to(void Function(T payload) handler) {
    _handlers.add(handler);
    return Subscription(() => _handlers.remove(handler));
  }

  /// Fire the event.
  void call([T? payload]) {
    if (isDisposed) return;
    final T value = payload as T;
    Kernel.instance.batch(() {
      final handlers = List<void Function(T)>.from(_handlers);
      for (final h in handlers) {
        h(value);
      }
      notify(value);
    });
  }
}

/// Void-payload event helper.
Event<void> createEvent({String? name}) => Event<void>(name: name);

Event<T> createEventTyped<T>({String? name}) => Event<T>(name: name);

bool isEvent(Object? u) => u is Event;
