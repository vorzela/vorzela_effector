/// Flutter bindings for vorzela_effector — prefer [StatelessWidget] + [UnitBuilder].
///
/// Subscriptions and [TextEditingController]s auto-dispose with the widget tree.
library;

import 'package:flutter/widgets.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

export 'package:vorzela_effector/vorzela_effector.dart';
export 'src/flutter/auto_dispose.dart';

/// Rebuild when [unit] (a [Store]) changes. Auto-disposes the subscription.
class UnitBuilder<T> extends StatefulWidget {
  const UnitBuilder({
    super.key,
    required this.unit,
    required this.builder,
  });

  final Store<T> unit;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<UnitBuilder<T>> createState() => _UnitBuilderState<T>();
}

class _UnitBuilderState<T> extends State<UnitBuilder<T>> {
  late T _value;
  Subscription? _sub;

  @override
  void initState() {
    super.initState();
    _value = widget.unit.getState();
    _sub = widget.unit.watch((v) {
      if (!mounted) return;
      setState(() => _value = v);
    });
  }

  @override
  void didUpdateWidget(covariant UnitBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit != widget.unit) {
      _sub?.unsubscribe();
      _value = widget.unit.getState();
      _sub = widget.unit.watch((v) {
        if (!mounted) return;
        setState(() => _value = v);
      });
    }
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

/// Watch multiple stores; rebuild when any changes.
class MultiUnitBuilder extends StatefulWidget {
  const MultiUnitBuilder({
    super.key,
    required this.units,
    required this.builder,
  });

  final List<Store> units;
  final Widget Function(BuildContext context) builder;

  @override
  State<MultiUnitBuilder> createState() => _MultiUnitBuilderState();
}

class _MultiUnitBuilderState extends State<MultiUnitBuilder> {
  final List<Subscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    for (final s in _subs) {
      s.unsubscribe();
    }
    _subs.clear();
    for (final u in widget.units) {
      _subs.add(u.watch((_) {
        if (mounted) setState(() {});
      }));
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
  Widget build(BuildContext context) => widget.builder(context);
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
/// Call only from `initState` (not every build) — prefer [AutoDisposeMixin].
final class UnitHook {
  UnitHook();

  final List<Subscription> _subs = [];

  T watchStore<T>(Store<T> store, void Function() onChange) {
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
