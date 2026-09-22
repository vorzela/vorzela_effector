import 'package:flutter/widgets.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

/// Provides a [Scope] to the widget subtree (Effector-react `Provider`).
///
/// [UnitBuilder] / [MultiUnitBuilder] under this widget read and watch
/// forked state — safe for ecommerce SSR and multi-tenant UI trees.
class ScopeProvider extends InheritedWidget {
  const ScopeProvider({
    super.key,
    required this.scope,
    required super.child,
  });

  final Scope scope;

  static Scope of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ScopeProvider>();
    assert(
      provider != null,
      'No ScopeProvider found. Wrap your app/page with '
      'ScopeProvider(scope: fork(), child: …).',
    );
    return provider!.scope;
  }

  static Scope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ScopeProvider>()
        ?.scope;
  }

  @override
  bool updateShouldNotify(ScopeProvider oldWidget) =>
      scope != oldWidget.scope;
}
