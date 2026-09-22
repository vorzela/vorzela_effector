/// Flutter bindings for vorzela_effector — prefer [StatelessWidget] + [UnitBuilder].
///
/// Subscriptions and [TextEditingController]s auto-dispose with the widget tree.
/// Wrap the tree in [ScopeProvider] for SSR / isolated ecommerce scopes.
library;

import 'package:flutter/widgets.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

export 'package:vorzela_effector/vorzela_effector.dart';
export 'src/flutter/auto_dispose.dart';
import 'src/flutter/scope_provider.dart';
export 'src/flutter/scope_provider.dart';

/// Bind [unit] to the nearest [ScopeProvider] (use for `onPressed`).
void Function([dynamic params]) bind(BuildContext context, Object unit) =>
    scopeBind(unit, scope: ScopeProvider.of(context));

/// Compatibility alias for [bind].
@Deprecated('Use bind(context, unit)')
void Function([dynamic params]) bindOf(BuildContext context, Object unit) =>
    bind(context, unit);

/// Rebuild when [unit] changes. Uses [ScopeProvider] when present.
///
/// Each [UnitBuilder] subscribes only to its own [unit] — siblings watching
/// other stores do **not** [setState] when this one updates.
///
/// ```dart
/// Column(children: [
///   UnitBuilder(unit: $cart, builder: (_, c) => Text('$c')),
///   UnitBuilder(unit: $user, builder: (_, u) => Text('$u')),
/// ])
/// ```
///
/// For nested builders, use [UnitBuilder.withChild] so the nested subtree is
/// passed as [child] and is not recreated inside the parent's builder
/// (same idea as [ListenableBuilder]):
///
/// ```dart
/// UnitBuilder.withChild(
///   unit: $header,
///   builder: (context, h, child) => Column(children: [Text('$h'), child!]),
///   child: UnitBuilder(unit: $body, builder: (_, b) => Text('$b')),
/// )
/// ```
class UnitBuilder<T> extends StatefulWidget {
  UnitBuilder({
    super.key,
    required this.unit,
    required Widget Function(BuildContext context, T value) builder,
    this.child,
  }) : _builder = ((context, value, _) => builder(context, value));

  /// Like [UnitBuilder], but [builder] receives the optional [child] slot.
  UnitBuilder.withChild({
    super.key,
    required this.unit,
    required Widget Function(BuildContext context, T value, Widget? child)
        builder,
    this.child,
  }) : _builder = builder;

  final Store<T> unit;
  final Widget? child;
  final Widget Function(BuildContext context, T value, Widget? child) _builder;

  @override
  State<UnitBuilder<T>> createState() => _UnitBuilderState<T>();
}

class _UnitBuilderState<T> extends State<UnitBuilder<T>> {
  late T _value;
  Subscription? _sub;
  Scope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ScopeProvider.maybeOf(context);
    if (scope != _scope || _sub == null) {
      _rebind(scope);
    }
  }

  void _rebind(Scope? scope) {
    _sub?.unsubscribe();
    _scope = scope;
    if (scope != null) {
      _value = scope.getState(widget.unit);
      _sub = scope.watchStore(widget.unit, (v) {
        if (!mounted) return;
        setState(() => _value = v);
      });
    } else {
      _value = widget.unit.getState();
      _sub = widget.unit.watch((v) {
        if (!mounted) return;
        setState(() => _value = v);
      });
    }
  }

  @override
  void didUpdateWidget(covariant UnitBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit != widget.unit) {
      _rebind(_scope);
    }
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget._builder(context, _value, widget.child);
}

/// Watch multiple stores; rebuild when any changes (respects [ScopeProvider]).
///
/// Same rebuild locality as [UnitBuilder]: only this widget [setState]s when
/// one of [units] fires — siblings watching other stores are untouched.
class MultiUnitBuilder extends StatefulWidget {
  MultiUnitBuilder({
    super.key,
    required this.units,
    required Widget Function(BuildContext context) builder,
    this.child,
  }) : _builder = ((context, _) => builder(context));

  MultiUnitBuilder.withChild({
    super.key,
    required this.units,
    required Widget Function(BuildContext context, Widget? child) builder,
    this.child,
  }) : _builder = builder;

  final List<Store> units;
  final Widget? child;
  final Widget Function(BuildContext context, Widget? child) _builder;

  @override
  State<MultiUnitBuilder> createState() => _MultiUnitBuilderState();
}

class _MultiUnitBuilderState extends State<MultiUnitBuilder> {
  final List<Subscription> _subs = [];
  Scope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ScopeProvider.maybeOf(context);
    if (scope != _scope || _subs.isEmpty) {
      _scope = scope;
      _bind();
    }
  }

  void _bind() {
    for (final s in _subs) {
      s.unsubscribe();
    }
    _subs.clear();
    final scope = _scope;
    for (final u in widget.units) {
      if (scope != null) {
        _subs.add(scope.watchStore(u, (_) {
          if (mounted) setState(() {});
        }));
      } else {
        _subs.add(u.watch((_) {
          if (mounted) setState(() {});
        }));
      }
    }
  }

  @override
  void didUpdateWidget(covariant MultiUnitBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.units != widget.units) _bind();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.unsubscribe();
    }
    _subs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget._builder(context, widget.child);
}

/// Button/InkWell helper that fires [unit] inside the nearest [ScopeProvider].
///
/// Prefer this over remembering `bind(context, event)` vs bare `event()`.
class UnitAction extends StatelessWidget {
  const UnitAction({
    super.key,
    required this.unit,
    this.params,
    required this.child,
  });

  final Object unit;
  final dynamic params;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final run = bind(context, unit);
    return GestureDetector(
      onTap: () => run(params),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// Opens [gate] on mount with optional [props], closes on dispose.
class GateScope<T> extends StatefulWidget {
  const GateScope({
    super.key,
    required this.gate,
    this.props,
    required this.child,
  });

  final Gate<T> gate;
  final T? props;
  final Widget child;

  @override
  State<GateScope<T>> createState() => _GateScopeState<T>();
}

class _GateScopeState<T> extends State<GateScope<T>> {
  @override
  void initState() {
    super.initState();
    widget.gate.open(widget.props as T);
  }

  @override
  void dispose() {
    widget.gate.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Thin subscription list for custom [State] code.
final class UnitHook {
  UnitHook();

  final List<Subscription> _subs = [];

  T watchStore<T>(Store<T> store, void Function() onChange, {Scope? scope}) {
    if (scope != null) {
      _subs.add(scope.watchStore(store, (_) => onChange()));
      return scope.getState(store);
    }
    _subs.add(store.watch((_) => onChange()));
    return store.getState();
  }

  void dispose() {
    for (final s in _subs) {
      s.unsubscribe();
    }
    _subs.clear();
  }
}
