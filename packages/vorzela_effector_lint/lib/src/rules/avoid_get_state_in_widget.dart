import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class AvoidGetStateInWidget extends DartLintRule {
  const AvoidGetStateInWidget() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_get_state_in_widget',
    problemMessage:
        'Avoid Store.getState()/value in Widget build — use UnitBuilder or sample.',
    correctionMessage:
        'Wrap UI in UnitBuilder, or read state via sample into an event/effect.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addMethodInvocation((node) {
      if (!isInsideWidgetBuild(node)) return;
      if (node.methodName.name != 'getState') return;
      final type = node.realTarget?.staticType;
      if (!isStoreDartType(type)) return;
      reporter.atNode(node, code);
    });

    context.registry.addPropertyAccess((node) {
      if (!isInsideWidgetBuild(node)) return;
      if (node.propertyName.name != 'value') return;
      if (!isStoreDartType(node.realTarget.staticType)) return;
      reporter.atNode(node, code);
    });
  }
}
