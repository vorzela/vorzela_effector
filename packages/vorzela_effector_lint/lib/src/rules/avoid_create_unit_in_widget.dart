import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

/// Forbid creating units inside Widget build (new graph every frame).
class AvoidCreateUnitInWidget extends DartLintRule {
  const AvoidCreateUnitInWidget() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_create_unit_in_widget',
    problemMessage:
        'Do not createStore/createEvent/createEffect/fork inside Widget build.',
    correctionMessage:
        'Declare units at library/top level (or in a model), not in build().',
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
      if (!isCreateUnitInvocation(node)) return;
      reporter.atNode(node.methodName, code);
    });
  }
}
