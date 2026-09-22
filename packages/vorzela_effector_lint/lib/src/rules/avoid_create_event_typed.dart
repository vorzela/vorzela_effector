import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class AvoidCreateEventTyped extends DartLintRule {
  const AvoidCreateEventTyped() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_create_event_typed',
    problemMessage: 'createEventTyped is deprecated — use createEvent<T>().',
    correctionMessage: 'Replace with createEvent<YourType>().',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'createEventTyped') return;
      reporter.atNode(node.methodName, code);
    });
    context.registry.addFunctionExpressionInvocation((node) {
      final fn = node.function;
      if (fn is! SimpleIdentifier) return;
      if (fn.name != 'createEventTyped') return;
      reporter.atNode(fn, code);
    });
  }
}
