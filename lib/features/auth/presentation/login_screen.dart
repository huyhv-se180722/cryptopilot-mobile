import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/web/web_links.dart';
import '../data/auth_api.dart';
import '../domain/credentials_rules.dart';
import 'auth_scaffold.dart';
import 'password_field.dart';

/// SCR-04 Log in (UC-03). "Keep me signed in" starts on: a phone is a
/// personal device, and the 30-day refresh token is what keeps the session
/// across restarts.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _resendCooldown = 60;

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _pending = false;
  String? _banner;
  bool _bannerPositive = false;
  bool _offerResend = false;
  int _resendWait = 0;
  Timer? _resendTimer;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final state = ref.read(sessionControllerProvider);
    if (state is SignedOut && state.expired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _banner = AppLocalizations.of(context).msg44);
        }
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Map<String, String> _validate(AppLocalizations l) {
    final errors = <String, String>{};
    final email = _email.text.trim();
    if (email.isEmpty) {
      errors['email'] = l.msg01(l.authEmailField);
    } else if (!looksLikeEmail(email)) {
      errors['email'] = l.msg02;
    }
    if (_password.text.isEmpty) {
      errors['password'] = l.msg01(l.authPasswordField);
    }
    return errors;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final errors = _validate(l);
    setState(() {
      _fieldErrors = errors;
      _banner = null;
      _offerResend = false;
    });
    if (errors.isNotEmpty) return;
    setState(() => _pending = true);
    try {
      final session = await ref
          .read(authApiProvider)
          .login(
            email: _email.text.trim(),
            password: _password.text,
            rememberMe: _rememberMe,
          );
      await ref.read(sessionControllerProvider.notifier).signIn(session);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _showFailure(l, failure));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _showFailure(AppLocalizations l, ApiFailure failure) {
    _bannerPositive = false;
    if (failure is ProblemFailure && failure.problem.fieldErrors.isNotEmpty) {
      _fieldErrors = {
        for (final MapEntry(:key, :value)
            in failure.problem.fieldErrors.entries)
          key: messageText(
            l,
            value,
            field: key == 'email' ? l.authEmailField : l.authPasswordField,
          ),
      };
      return;
    }
    _offerResend =
        failure is ProblemFailure && failure.code == 'EMAIL_NOT_VERIFIED';
    _banner = failureText(l, failure);
  }

  Future<void> _resend() async {
    final l = AppLocalizations.of(context);
    setState(() => _resendWait = _resendCooldown);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendWait <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendWait = 0);
        return;
      }
      setState(() => _resendWait--);
    });
    try {
      await ref.read(authApiProvider).resendVerification(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _banner = l.authResendSent;
        _bannerPositive = true;
        _offerResend = false;
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _banner = failureText(l, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.authLoginTitle,
      subtitle: l.authLoginSubtitle,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_banner != null)
              FormBanner(
                message: _banner!,
                positive: _bannerPositive,
                action: _offerResend
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _resendWait > 0 ? null : _resend,
                          child: Text(
                            _resendWait > 0
                                ? l.authResendIn(_resendWait)
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
                errorText: _fieldErrors['email'],
              ),
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('login-password'),
              controller: _password,
              label: l.authPasswordLabel,
              errorText: _fieldErrors['password'],
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
              onPressed: _pending ? null : _submit,
              child: _pending
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
