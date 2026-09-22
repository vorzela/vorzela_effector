import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferBindInWidget extends DartLintRule {
  const PreferBindInWidget() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_bind_in_widget',
    problemMessage:
        'Bare Event/Effect call in a Widget may miss ScopeProvider — use bind() or UnitAction.',
    correctionMessage:
        'onPressed: bind(context, myEvent)  or  UnitAction(unit: myEvent, …)',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    final src = resolver.source.contents.data;
    final scopedFile = src.contains('ScopeProvider') ||
        src.contains('UnitAction') ||
        RegExp(r'\bbind\s*\(').hasMatch(src);

    context.registry.addFunctionExpressionInvocation((node) {
      if (!scopedFile) return;
      if (!isInsideWidgetClass(node)) return;
      if (!isEventDartType(node.function.staticType) &&
          !isEffectDartType(node.function.staticType)) {
        return;
      }
      if (_isInsideBindOrUnitAction(node)) return;
      reporter.atNode(node, code);
    });
  }

  bool _isInsideBindOrUnitAction(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation &&
          (current.methodName.name == 'bind' ||
              current.methodName.name == 'bindOf' ||
              current.methodName.name == 'scopeBind')) {
        return true;
      }
      if (current is InstanceCreationExpression) {
        final named = current.constructorName.type.name.lexeme;
        if (named == 'UnitAction' || named.endsWith('UnitAction')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}
