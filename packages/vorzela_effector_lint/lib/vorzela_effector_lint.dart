import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/avoid_create_event_typed.dart';
import 'src/rules/avoid_create_unit_in_widget.dart';
import 'src/rules/avoid_get_state_in_widget.dart';
import 'src/rules/avoid_watch_in_widget.dart';
import 'src/rules/prefer_bind_in_widget.dart';
import 'src/rules/prefer_dollar_store_name.dart';
import 'src/rules/prefer_fx_effect_name.dart';

/// Entrypoint for `custom_lint` — must stay `createPlugin` in this library.
PluginBase createPlugin() => _VorzelaEffectorLint();

class _VorzelaEffectorLint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const PreferDollarStoreName(),
        const PreferFxEffectName(),
        const AvoidGetStateInWidget(),
        const AvoidWatchInWidget(),
        const AvoidCreateUnitInWidget(),
        const PreferBindInWidget(),
        const AvoidCreateEventTyped(),
      ];
}
