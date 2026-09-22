import 'kernel.dart';
import 'unit.dart';

/// Effector-style event — call like a function: `incremented()` / `setName('a')`.
final class Event<T> extends Unit with Subscribable<T> {
  Event({super.name});

  final List<_HandlerSlot<T>> _handlerSlots = [];
  int _handlerLiveCount = 0;

  /// Subscribe a side-effect handler (graph links use this internally).
  Subscription to(void Function(T payload) handler) {
    final slot = _HandlerSlot<T>(handler);
    _handlerSlots.add(slot);
    _handlerLiveCount++;
    return Subscription(() {
      if (slot.removed) return;
      slot.removed = true;
      _handlerLiveCount--;
    });
  }

  /// Fire the event.
  void call([T? payload]) {
    if (isDisposed) return;
    final T value = payload as T;
    Kernel.instance.batch(() {
      final len = _handlerSlots.length;
      for (var i = 0; i < len; i++) {
        final slot = _handlerSlots[i];
        if (!slot.removed) slot.listener(value);
      }
      _compactHandlersIfNeeded();
      notify(value);
    });
  }

  void _compactHandlersIfNeeded() {
    if (_handlerSlots.length > 16 &&
        _handlerLiveCount * 2 < _handlerSlots.length) {
      _handlerSlots.removeWhere((s) => s.removed);
    }
  }

  @override
  void onDispose() {
    _handlerSlots.clear();
    _handlerLiveCount = 0;
    super.onDispose();
  }
}

final class _HandlerSlot<T> {
  _HandlerSlot(this.listener);
  final void Function(T) listener;
  bool removed = false;
}

/// Create an event.
///
/// Void: `createEvent()` · Typed: `createEvent<String>()`.
Event<T> createEvent<T extends Object?>({String? name}) =>
    Event<T>(name: name);

/// Compatibility alias — prefer [createEvent].
@Deprecated('Use createEvent<T>() instead')
Event<T> createEventTyped<T>({String? name}) => createEvent<T>(name: name);

bool isEvent(Object? u) => u is Event;
