import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../application/reset_password_controller.dart';
import 'auth_scaffold.dart';
import 'password_field.dart';

/// SCR-06 Reset password, opened with the `token` of the mailed link (D-108).
/// Until App Links exist the link opens the website; this screen serves the
/// link once the app owns it (T-092). The checks and the call are
/// [ResetPasswordController]'s.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.token, super.key});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final changed = await ref
        .read(resetPasswordControllerProvider(widget.token).notifier)
        .submit(password: _password.text, confirm: _confirm.text);
    if (!changed || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.msg13)));
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(resetPasswordControllerProvider(widget.token));

    String? fieldError(String field, String label) =>
        switch (state.fieldErrors[field]) {
          null => null,
          passwordsDifferCode => l.authPasswordsDiffer,
          final code => messageText(l, code, field: label),
        };

    if (state.linkInvalid) {
      return AuthScaffold(
        title: l.authResetTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormBanner(message: l.msg07),
            FilledButton(
              onPressed: () => context.go('/forgot-password'),
              child: Text(l.authRequestNewLink),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(l.authBackToSignIn),
            ),
          ],
        ),
      );
    }
    return AuthScaffold(
      title: l.authResetTitle,
      subtitle: l.authResetSubtitle,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.failure case final failure?)
              FormBanner(message: failureText(l, failure)),
            PasswordField(
              key: const Key('reset-password'),
              controller: _password,
              label: l.authNewPasswordLabel,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              errorText: fieldError('newPassword', l.authNewPasswordField),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            PasswordRulesList(password: _password.text),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('reset-confirm'),
              controller: _confirm,
              label: l.authConfirmPasswordLabel,
              autofillHints: const [AutofillHints.newPassword],
              errorText: fieldError(
                'confirmPassword',
                l.authConfirmPasswordField,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('reset-submit'),
              onPressed: state.pending ? null : _submit,
              child: Text(l.authResetSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
