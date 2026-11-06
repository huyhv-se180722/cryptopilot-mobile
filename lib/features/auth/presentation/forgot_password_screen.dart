import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../data/auth_api.dart';
import '../domain/credentials_rules.dart';
import 'auth_scaffold.dart';

/// SCR-05 Forgot password (UC-04): always MSG12, so no address is revealed.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _cooldown = 60;

  final _email = TextEditingController();
  bool _pending = false;
  bool _sent = false;
  String? _emailError;
  String? _banner;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _wait = _cooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _wait <= 1) {
        timer.cancel();
        if (mounted) setState(() => _wait = 0);
        return;
      }
      setState(() => _wait--);
    });
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final email = _email.text.trim();
    final error = email.isEmpty
        ? l.msg01(l.authEmailField)
        : (looksLikeEmail(email) ? null : l.msg02);
    setState(() {
      _emailError = error;
      _banner = null;
    });
    if (error != null) return;
    setState(() => _pending = true);
    try {
      await ref.read(authApiProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _startCooldown();
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        final field = failure is ProblemFailure
            ? failure.problem.fieldErrors['email']
            : null;
        if (field != null) {
          _emailError = messageText(l, field, field: l.authEmailField);
        } else {
          _banner = failureText(l, failure);
        }
      });
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      showBack: true,
      title: _sent ? l.authForgotSentTitle : l.authForgotTitle,
      subtitle: _sent ? l.authForgotSentBody : l.authForgotSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_sent) FormBanner(message: l.msg12, positive: true),
          if (_banner != null) FormBanner(message: _banner!),
          TextField(
            key: const Key('forgot-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l.authEmailLabel,
              errorText: _emailError,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('forgot-submit'),
            onPressed: _pending || _wait > 0 ? null : _submit,
            child: Text(_wait > 0 ? l.authResendIn(_wait) : l.authForgotSubmit),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/login'),
            child: Text(l.authBackToSignIn),
          ),
        ],
      ),
    );
  }
}
