import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/web/web_links.dart';
import '../application/login_controller.dart';
import 'auth_scaffold.dart';
import 'password_field.dart';

/// SCR-04 Log in (UC-03). "Keep me signed in" starts on: a phone is a
/// personal device, and the 30-day refresh token is what keeps the session
/// across restarts. The form's state and the calls are [LoginController]'s.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(loginControllerProvider.notifier)
      .submit(
        email: _email.text,
        password: _password.text,
        rememberMe: _rememberMe,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(loginControllerProvider);

    String? fieldError(String field, String label) {
      final code = state.fieldErrors[field];
      return code == null ? null : messageText(l, code, field: label);
    }

    final banner = switch (state) {
      LoginState(:final failure?) => failureText(l, failure),
      LoginState(notice: LoginNotice.resendSent) => l.authResendSent,
      LoginState(notice: LoginNotice.sessionExpired) => l.msg44,
      _ => null,
    };

    return AuthScaffold(
      title: l.authLoginTitle,
      subtitle: l.authLoginSubtitle,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (banner != null)
              FormBanner(
                message: banner,
                positive: state.notice == LoginNotice.resendSent,
                action: state.offerResend
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: state.resendWait > 0
                              ? null
                              : () => ref
                                    .read(loginControllerProvider.notifier)
                                    .resend(_email.text),
                          child: Text(
                            state.resendWait > 0
                                ? l.authResendIn(state.resendWait)
                                : l.authResendVerification,
                          ),
                        ),
                      )
                    : null,
              ),
            TextField(
              key: const Key('login-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.authEmailLabel,
                errorText: fieldError('email', l.authEmailField),
              ),
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('login-password'),
              controller: _password,
              label: l.authPasswordLabel,
              errorText: fieldError('password', l.authPasswordField),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _rememberMe,
              onChanged: (value) =>
                  setState(() => _rememberMe = value ?? false),
              title: Text(l.authRememberMe),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: Text(l.authForgotLink),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('login-submit'),
              onPressed: state.pending ? null : _submit,
              child: state.pending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.authLoginSubmit),
            ),
            const SizedBox(height: 24),
            Text(l.authNoAccount, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: () => ref.read(webLinksProvider).open('/register'),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l.authCreateAccountLink),
            ),
            Text(
              l.authCreateAccountHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
