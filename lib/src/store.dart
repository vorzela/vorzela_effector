import 'event.dart';
import 'kernel.dart';
import 'unit.dart';

typedef Reducer<T, P> = T Function(T state, P payload);
typedef UpdateFilter<T> = bool Function(T previous, T next);

/// Writable or derived store (atom). Prefer `$name` naming like Effector.
final class Store<T> extends Unit with Subscribable<T>, DeferredNotify<T> {
  Store(
    T initial, {
    super.name,
    this.updateFilter,
    bool derived = false,
  })  : _state = initial,
        _derived = derived;

  T _state;
  final bool _derived;
  final UpdateFilter<T>? updateFilter;
  final List<Subscription> _links = [];

  T getState() => _state;

  /// Current value (alias of [getState] for Effector familiarity).
  T get value => _state;

  bool get isDerived => _derived;

  /// `$store.on(event, (state, payload) => next)`
  Store<T> on<P>(Event<P> event, Reducer<T, P> reducer) {
    if (_derived) {
      throw StateError('Cannot .on() a derived store');
    }
    final sub = event.to((payload) {
      final next = reducer(_state, payload);
      _set(next);
    });
    _links.add(sub);
    return this;
  }

  /// Reset store when [clock] fires.
  Store<T> reset(Event<void> clock, [T? to]) {
    if (_derived) throw StateError('Cannot reset a derived store');
    final target = to ?? _state;
    final sub = clock.to((_) => _set(target));
    _links.add(sub);
    return this;
  }

  void _set(T next) {
    if (isDisposed) return;
    if (updateFilter != null) {
      if (!updateFilter!(_state, next)) return;
    } else if (identical(_state, next) || _state == next) {
      return;
    }
    _state = next;
    scheduleNotify(next);
  }

  /// Internal write used by sample/combine/effects.
  void write(T next) {
    if (_derived) {
      // Derived stores are written only by their derivation pipeline.
    }
    _set(next);
  }

  /// Force write even for derived (used by combine/map internals).
  void writeDerived(T next) => _set(next);

  /// `$store.map((s) => …)` — derived read-only store.
  Store<R> map<R>(R Function(T state) fn, {String? name, UpdateFilter<R>? updateFilter}) {
    final derived = Store<R>(
      fn(_state),
      name: name ?? (this.name == null ? null : '${this.name}.map'),
      updateFilter: updateFilter,
      derived: true,
    );
    final sub = watch((v) => derived.writeDerived(fn(v)));
    derived._links.add(sub);
    return derived;
  }

  void attachLinks(List<Subscription> links) {
    _links.addAll(links);
  }

  @override
  void onDispose() {
    for (final l in _links) {
      l.unsubscribe();
    }
    _links.clear();
    super.onDispose();
  }
}

Store<T> createStore<T>(
  T initial, {
  String? name,
  UpdateFilter<T>? updateFilter,
}) =>
    Store<T>(initial, name: name, updateFilter: updateFilter);

bool isStore(Object? u) => u is Store;
