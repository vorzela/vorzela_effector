import 'package:flutter/widgets.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

/// Provides a [Scope] to the widget subtree (Effector-react `Provider`).
///
/// If [scope] is omitted, a fresh [fork] is created once and owned by this
/// widget — screen authors rarely need to call `fork()` themselves.
class ScopeProvider extends StatefulWidget {
  const ScopeProvider({
    super.key,
    this.scope,
    required this.child,
  });

  /// Existing scope, or `null` to auto-[fork].
  final Scope? scope;
  final Widget child;

  static Scope of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_ScopeInherited>();
    assert(
      inherited != null,
      'No ScopeProvider found. Wrap your app/page with '
      'ScopeProvider(child: …) — it auto-forks if you omit scope:.',
    );
    return inherited!.scope;
  }

  static Scope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScopeInherited>()
        ?.scope;
  }

  @override
  State<ScopeProvider> createState() => _ScopeProviderState();
}

class _ScopeProviderState extends State<ScopeProvider> {
  Scope? _owned;

  Scope get _scope => widget.scope ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.scope == null) {
      _owned = fork();
    }
  }

  @override
  void didUpdateWidget(covariant ScopeProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scope != null && _owned != null) {
      _owned!.dispose();
      _owned = null;
    } else if (widget.scope == null && _owned == null) {
      _owned = fork();
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    _owned = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ScopeInherited(
      scope: _scope,
      child: widget.child,
    );
  }
}

class _ScopeInherited extends InheritedWidget {
  const _ScopeInherited({
    required this.scope,
    required super.child,
  });

  final Scope scope;

  @override
  bool updateShouldNotify(_ScopeInherited oldWidget) =>
      scope != oldWidget.scope;
}
