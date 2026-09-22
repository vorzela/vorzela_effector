import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

/// Forbid `.watch` inside Widget build (stacks listeners every frame).
class AvoidWatchInWidget extends DartLintRule {
  const AvoidWatchInWidget() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_watch_in_widget',
    problemMessage:
        'Do not call .watch() in Widget build — it stacks listeners every frame.',
    correctionMessage: 'Use UnitBuilder, or watch once in initState / Life.',
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
      if (node.methodName.name != 'watch') return;
      final type = node.realTarget?.staticType;
      if (!isVorzelaUnitType(type)) return;
      reporter.atNode(node.methodName, code);
    });
  }
}
