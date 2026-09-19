import 'kernel.dart';

/// Base reactive unit.
abstract class Unit {
  Unit({this.name});

  final String? name;

  bool get isDisposed => _disposed;
  bool _disposed = false;

  /// Subscriptions this unit owns and must tear down on [dispose] — e.g. the
  /// event/store link created by `.on()`, `.map()`, `combine()` or `sample()`.
  /// Centralized here (rather than each subtype keeping its own list) so any
  /// unit can own links, and so there's exactly one place that guarantees
  /// they're released.
  final List<Subscription> _links = [];

  /// Keep [subs] alive for as long as this unit lives; they're unsubscribed
  /// automatically on [dispose].
  void attachLinks(Iterable<Subscription> subs) => _links.addAll(subs);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final l in _links) {
      l.unsubscribe();
    }
    _links.clear();
    onDispose();
  }

  void onDispose() {}
}

typedef Subscriber<T> = void Function(T value);

/// Subscription handle — call [unsubscribe] (or [dispose]) to detach.
final class Subscription {
  Subscription(this._cancel);

  final void Function() _cancel;
  bool _active = true;

  void unsubscribe() {
    if (!_active) return;
    _active = false;
    _cancel();
  }

  void dispose() => unsubscribe();

  bool get isActive => _active;
}

/// Slot wrapper so unsubscribe is identity-based (`==` on the slot, not on
/// the listener closure). Using `List.remove(listener)` directly is wrong
/// whenever the same listener/tear-off is registered more than once — it
/// always removes the *first* match, which can detach the wrong
/// subscription. It's also an O(n) list splice per call; here removal just
/// tombstones the slot and notify() compacts lazily, which is O(1) amortized
/// for the common "subscribe once, unsubscribe once" pattern.
final class _Slot<T> {
  _Slot(this.listener);
  final Subscriber<T> listener;
  bool removed = false;
}

mixin Subscribable<T> on Unit {
  final List<_Slot<T>> _subs = [];
  int _liveCount = 0;

  Subscription watch(Subscriber<T> listener) {
    if (isDisposed) {
      throw StateError('Cannot watch a disposed unit${name == null ? '' : ' ($name)'}');
    }
    final slot = _Slot<T>(listener);
    _subs.add(slot);
    _liveCount++;
    return Subscription(() {
      if (slot.removed) return;
      slot.removed = true;
      _liveCount--;
    });
  }

  void notify(T value) {
    if (isDisposed) return;
    if (_subs.isEmpty) return;
    // Snapshot indices, not the list itself, so unsubscribes that happen
    // mid-notify (including of slots not yet visited) are respected without
    // allocating a full copy of the listener list on every fire.
    final len = _subs.length;
    for (var i = 0; i < len; i++) {
      final slot = _subs[i];
      if (!slot.removed) slot.listener(value);
    }
    _compactIfNeeded();
  }

  void _compactIfNeeded() {
    // Only pay for compaction once enough dead slots have accumulated.
    if (_subs.length > 16 && _liveCount * 2 < _subs.length) {
      _subs.removeWhere((s) => s.removed);
    }
  }

  int get subscriberCount => _liveCount;

  @override
  void onDispose() {
    _subs.clear();
    _liveCount = 0;
    super.onDispose();
  }
}

/// Defer store subscriber notifications until end of kernel flush.
mixin DeferredNotify<T> on Subscribable<T> implements Notifiable {
  T? _pendingNotify;
  bool _hasPending = false;

  void scheduleNotify(T value) {
    _pendingNotify = value;
    _hasPending = true;
    Kernel.instance.markDirty(this);
  }

  @override
  void notifySubscribers() {
    if (!_hasPending) return;
    _hasPending = false;
    final v = _pendingNotify as T;
    notify(v);
  }
}
