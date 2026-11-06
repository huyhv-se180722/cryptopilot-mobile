import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../domain/credentials_rules.dart';

/// A password input with a show / hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    this.errorText,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// The live BR-02 checklist under a new password.
class PasswordRulesList extends StatelessWidget {
  const PasswordRulesList({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rules = PasswordRules(password);
    final items = [
      (l.authRuleLength, rules.length),
      (l.authRuleLowercase, rules.lowercase),
      (l.authRuleUppercase, rules.uppercase),
      (l.authRuleDigit, rules.digit),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.authRulesTitle, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        for (final (label, met) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  met ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: met ? context.cp.positive : context.cp.muted,
                ),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
