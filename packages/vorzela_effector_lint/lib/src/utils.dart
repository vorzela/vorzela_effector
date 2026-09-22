import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

bool isTestPath(CustomLintResolver resolver) {
  final path = resolver.source.fullName.replaceAll(r'\', '/');
  return path.contains('/test/') || path.endsWith('_test.dart');
}

final storeType = TypeChecker.fromName(
  'Store',
  packageName: 'vorzela_effector',
);
final eventType = TypeChecker.fromName(
  'Event',
  packageName: 'vorzela_effector',
);
final effectType = TypeChecker.fromName(
  'Effect',
  packageName: 'vorzela_effector',
);

bool isStoreDartType(DartType? type) {
  if (type == null) return false;
  if (storeType.isAssignableFromType(type)) return true;
  final s = type.getDisplayString();
  return s == 'Store' || s.startsWith('Store<');
}

bool isEventDartType(DartType? type) {
  if (type == null) return false;
  if (eventType.isAssignableFromType(type)) return true;
  final s = type.getDisplayString();
  return s == 'Event' || s.startsWith('Event<');
}

bool isEffectDartType(DartType? type) {
  if (type == null) return false;
  if (effectType.isAssignableFromType(type)) return true;
  final s = type.getDisplayString();
  return s == 'Effect' || s.startsWith('Effect<');
}

bool isVorzelaUnitType(DartType? type) =>
    isStoreDartType(type) || isEventDartType(type) || isEffectDartType(type);

/// True when [node] is inside a Widget `build` method.
bool isInsideWidgetBuild(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is MethodDeclaration && current.name.lexeme == 'build') {
      return _enclosingClassLooksLikeWidget(current);
    }
    current = current.parent;
  }
  return false;
}

/// True when [node] is inside any method of a Widget-like class.
bool isInsideWidgetClass(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is MethodDeclaration) {
      return _enclosingClassLooksLikeWidget(current);
    }
    current = current.parent;
  }
  return false;
}

bool _enclosingClassLooksLikeWidget(MethodDeclaration method) {
  final parent = method.thisOrAncestorOfType<ClassDeclaration>();
  if (parent == null) return false;
  final name = parent.name.lexeme;
  if (name.endsWith('Widget') ||
      name.endsWith('State') ||
      name.endsWith('Page') ||
      name.endsWith('Screen') ||
      name.endsWith('View')) {
    return true;
  }
  final extendsClause = parent.extendsClause;
  if (extendsClause == null) return false;
  final superName = extendsClause.superclass.name.lexeme;
  return superName.contains('StatelessWidget') ||
      superName.contains('StatefulWidget') ||
      superName.contains('State') ||
      superName.contains('ConsumerWidget') ||
      superName.contains('HookWidget');
}

bool isCreateUnitInvocation(MethodInvocation node) {
  final name = node.methodName.name;
  return name == 'createStore' ||
      name == 'createEvent' ||
      name == 'createEventTyped' ||
      name == 'createEffect' ||
      name == 'createGate' ||
      name == 'combine' ||
      name == 'combine2' ||
      name == 'combine3' ||
      name == 'sample' ||
      name == 'fork';
}

String? variableName(VariableDeclaration node) {
  return node.name.lexeme;
}
