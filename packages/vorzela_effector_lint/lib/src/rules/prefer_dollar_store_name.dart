import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferDollarStoreName extends DartLintRule {
  const PreferDollarStoreName() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_dollar_store_name',
    problemMessage:
        'Name Store variables with a \$ prefix (e.g. \$cart, \$user).',
    correctionMessage: 'Rename to start with \$ so stores are easy to spot.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addVariableDeclaration((node) {
      if (!_looksLikeStore(node)) return;
      final name = variableName(node);
      if (name == null) return;
      if (name.startsWith(r'$') || name.startsWith(r'_$')) return;
      reporter.atToken(node.name, code);
    });
  }

  bool _looksLikeStore(VariableDeclaration node) {
    final init = node.initializer;
    if (init is MethodInvocation && init.methodName.name == 'createStore') {
      return true;
    }
    if (isStoreDartType(init?.staticType)) return true;
    final list = node.parent;
    if (list is VariableDeclarationList) {
      final t = list.type;
      if (t != null) {
        final src = t.toSource();
        if (src.startsWith('Store')) return true;
      }
    }
    final frag = node.declaredFragment;
    if (frag != null) {
      return isStoreDartType(frag.element.type);
    }
    return false;
  }
}
