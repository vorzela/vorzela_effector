import 'kernel.dart';
import 'unit.dart';

/// Effector-style event — call like a function: `incremented()` / `setName('a')`.
final class Event<T> extends Unit with Subscribable<T> {
  Event({super.name});

  // Slot-wrapped (not a bare `List<Function>`) for the same reason `watch()`
  // uses slots in Subscribable: `List.remove(handler)` matches by equality
  // and always removes the *first* match, so registering the same handler
  // (e.g. a top-level function or tear-off) via `.to()` more than once could
  // make unsubscribing one Subscription silently detach a *different* one.
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
      // Snapshot indices (not a copy of every slot) so a handler that
      // unsubscribes mid-fire is respected without extra allocation —
      // same trick as [Subscribable.notify].
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
    // Match Subscribable: only pay for compaction once enough dead slots
    // have accumulated. Hot events with a few live `.to()` handlers must
    // not `removeWhere` on every fire.
    if (_handlerSlots.length > 16 &&
        _handlerLiveCount * 2 < _handlerSlots.length) {
      _handlerSlots.removeWhere((s) => s.removed);
    }
  }

  @override
  void onDispose() {
    // Release closures held by `.to()` handlers too — previously only the
    // `watch()` list (via Subscribable.onDispose) was cleared, so a disposed
    // Event still pinned every `.to()` handler closure (and whatever they
    // captured) in memory forever.
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

/// Void-payload event helper.
Event<void> createEvent({String? name}) => Event<void>(name: name);

Event<T> createEventTyped<T>({String? name}) => Event<T>(name: name);

bool isEvent(Object? u) => u is Event;
