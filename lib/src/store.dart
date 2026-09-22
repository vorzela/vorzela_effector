import 'event.dart';
import 'kernel.dart';
import 'scope.dart';
import 'unit.dart';

typedef Reducer<T, P> = T Function(T state, P payload);
typedef UpdateFilter<T> = bool Function(T previous, T next);

/// Writable or derived store (atom). Prefer `$name` naming like Effector.
final class Store<T> extends Unit with Subscribable<T>, DeferredNotify<T> {
  Store(
    T initial, {
    super.name,
    this.sid,
    this.updateFilter,
    bool derived = false,
  })  : _state = initial,
        _initial = initial,
        _derived = derived {
    if (sid != null) {
      _sidRegistry[sid!] = this;
    }
  }

  /// Stable id for [serialize] / [hydrate] (Effector SID). Required for SSR.
  final String? sid;

  T _state;
  final T _initial;
  final bool _derived;
  final UpdateFilter<T>? updateFilter;

  /// Sources + compute for derived stores (scoped recompute).
  List<Store>? _sources;
  Object? Function()? _compute;
  final List<Store> _dependents = [];

  static final Map<String, Store> _sidRegistry = {};

  static Store? bySid(String sid) => _sidRegistry[sid];

  /// Current value — respects Zone [Scope] when inside allSettled / scopeBind.
  T getState() {
    final scope = Kernel.instance.currentScope;
    if (scope is Scope) {
      if (scope.contains(this)) return scope.read<T>(this);
      if (_derived && _compute != null) {
        final v = _compute!() as T;
        scope.writeValue(this, v);
        return v;
      }
    }
    return _state;
  }

  T get value => getState();

  T get defaultState => _initial;

  /// Global (unscoped) value.
  T get globalState => _state;

  bool get isDerived => _derived;

  bool get hasCompute => _compute != null;

  Object? computeValue() => _compute?.call();

  List<Store> get dependents => _dependents;

  List<Store>? get sources => _sources;

  /// Watch — routes to the active Zone [Scope] when present so Provider UI
  /// and scoped tests get isolated notifications.
  @override
  Subscription watch(Subscriber<T> listener) {
    final scope = Kernel.instance.currentScope;
    if (scope is Scope) {
      return scope.watchStore(this, listener);
    }
    return super.watch(listener);
  }

  Store<T> on<P>(Event<P> event, Reducer<T, P> reducer) {
    if (_derived) {
      throw StateError('Cannot .on() a derived store');
    }
    final sub = event.to((payload) {
      final next = reducer(getState(), payload);
      _set(next);
    });
    attachLinks([sub]);
    return this;
  }

  Store<T> reset(Event<void> clock, [T? to]) {
    if (_derived) throw StateError('Cannot reset a derived store');
    final target = to ?? _initial;
    final sub = clock.to((_) => _set(target));
    attachLinks([sub]);
    return this;
  }

  void _set(T next) {
    if (isDisposed) return;
    final active = Kernel.instance.currentScope;
    if (active is Scope) {
      final prev = active.contains(this) ? active.read<T>(this) : _state;
      if (!_shouldUpdate(prev, next)) return;
      active.writeValue(this, next);
      active.notifyStore(this, next);
      active.recomputeDependents(this);
      return;
    }
    if (!_shouldUpdate(_state, next)) return;
    _state = next;
    scheduleNotify(next);
  }

  bool _shouldUpdate(T prev, T next) {
    if (updateFilter != null) return updateFilter!(prev, next);
    return !(identical(prev, next) || prev == next);
  }

  void write(T next) {
    if (_derived) {
      throw StateError(
        'Cannot write to a derived store'
        '${name == null ? '' : ' ($name)'} — it is computed from .map()/'
        'combine() and updates only when its source(s) change.',
      );
    }
    _set(next);
  }

  void writeDerived(T next) => _set(next);

  /// Internal: install derivation metadata for scoped recompute.
  void installDerivation({
    required List<Store> sources,
    required Object? Function() compute,
  }) {
    _sources = sources;
    _compute = compute;
    for (final s in sources) {
      if (!s._dependents.contains(this)) {
        s._dependents.add(this);
      }
    }
  }

  Store<R> map<R>(
    R Function(T state) fn, {
    String? name,
    String? sid,
    UpdateFilter<R>? updateFilter,
  }) {
    final derived = Store<R>(
      fn(_state),
      name: name ?? (this.name == null ? null : '${this.name}.map'),
      sid: sid,
      updateFilter: updateFilter,
      derived: true,
    );
    final Store<T> source = this;
    derived.installDerivation(
      sources: [source],
      compute: () => fn(source.getState()),
    );
    derived.attachLinks([
      // Global graph: keep non-scoped derived in sync.
      watch((v) => derived.writeDerived(fn(v))),
    ]);
    return derived;
  }

  @override
  void onDispose() {
    if (sid != null) {
      _sidRegistry.remove(sid);
    }
    _dependents.clear();
    _sources = null;
    _compute = null;
    super.onDispose();
  }
}

Store<T> createStore<T>(
  T initial, {
  String? name,
  String? sid,
  UpdateFilter<T>? updateFilter,
}) =>
    Store<T>(initial, name: name, sid: sid, updateFilter: updateFilter);

bool isStore(Object? u) => u is Store;
