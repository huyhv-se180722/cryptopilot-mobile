import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../data/auth_api.dart';
import '../domain/credentials_rules.dart';
import 'auth_scaffold.dart';
import 'password_field.dart';

/// SCR-06 Reset password, opened with the `token` of the mailed link (D-108).
/// Until App Links exist the link opens the website; this screen serves the
/// link once the app owns it (T-092).
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
  bool _pending = false;
  bool _linkInvalid = false;
  String? _banner;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _linkInvalid = (widget.token ?? '').isEmpty;
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final errors = <String, String>{};
    if (_password.text.isEmpty) {
      errors['newPassword'] = l.msg01(l.authNewPasswordField);
    } else if (!PasswordRules(_password.text).all) {
      errors['newPassword'] = l.msg03;
    }
    if (_confirm.text.isEmpty) {
      errors['confirmPassword'] = l.msg01(l.authConfirmPasswordField);
    } else if (_confirm.text != _password.text) {
      errors['confirmPassword'] = l.authPasswordsDiffer;
    }
    setState(() {
      _fieldErrors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _pending = true);
    try {
      await ref
          .read(authApiProvider)
          .resetPassword(
            token: widget.token!,
            newPassword: _password.text,
            confirmPassword: _confirm.text,
          );
      // Every session of the account ended on the server.
      await ref.read(sessionControllerProvider.notifier).forget();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.msg13)));
      context.go('/login');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _showFailure(l, failure));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _showFailure(AppLocalizations l, ApiFailure failure) {
    if (failure is ProblemFailure) {
      if (failure.code == 'TOKEN_INVALID_OR_EXPIRED') {
        _linkInvalid = true;
        return;
      }
      final fields = failure.problem.fieldErrors;
      if (fields.isNotEmpty) {
        _fieldErrors = {
          for (final MapEntry(:key, :value) in fields.entries)
            key == 'confirmPasswordMatching'
                ? 'confirmPassword'
                : key: messageText(
              l,
              value,
              field: key == 'newPassword'
                  ? l.authNewPasswordField
                  : l.authConfirmPasswordField,
            ),
        };
        return;
      }
    }
    _banner = failureText(l, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_linkInvalid) {
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
            if (_banner != null) FormBanner(message: _banner!),
            PasswordField(
              key: const Key('reset-password'),
              controller: _password,
              label: l.authNewPasswordLabel,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              errorText: _fieldErrors['newPassword'],
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
              errorText: _fieldErrors['confirmPassword'],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('reset-submit'),
              onPressed: _pending ? null : _submit,
              child: Text(l.authResetSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
