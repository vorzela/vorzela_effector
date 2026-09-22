import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferFxEffectName extends DartLintRule {
  const PreferFxEffectName() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_fx_effect_name',
    problemMessage:
        'Name Effect variables with an Fx suffix (e.g. fetchUserFx).',
    correctionMessage: 'Rename to end with Fx.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addVariableDeclaration((node) {
      if (!_looksLikeEffect(node)) return;
      final name = variableName(node);
      if (name == null) return;
      if (name.endsWith('Fx') || name.endsWith('_fx')) return;
      reporter.atToken(node.name, code);
    });
  }

  bool _looksLikeEffect(VariableDeclaration node) {
    final init = node.initializer;
    if (init is MethodInvocation && init.methodName.name == 'createEffect') {
      return true;
    }
    if (isEffectDartType(init?.staticType)) return true;
    final list = node.parent;
    if (list is VariableDeclarationList) {
      final t = list.type;
      if (t != null && t.toSource().startsWith('Effect')) return true;
    }
    final frag = node.declaredFragment;
    if (frag != null) {
      return isEffectDartType(frag.element.type);
    }
    return false;
  }
}
