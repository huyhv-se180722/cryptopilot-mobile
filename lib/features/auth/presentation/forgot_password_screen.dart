import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../application/forgot_password_controller.dart';
import 'auth_scaffold.dart';

/// SCR-05 Forgot password (UC-04): always MSG12, so no address is revealed.
/// The request and its cooldown are [ForgotPasswordController]'s.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() =>
      ref.read(forgotPasswordControllerProvider.notifier).submit(_email.text);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(forgotPasswordControllerProvider);
    final emailError = state.emailError;
    return AuthScaffold(
      showBack: true,
      title: state.sent ? l.authForgotSentTitle : l.authForgotTitle,
      subtitle: state.sent ? l.authForgotSentBody : l.authForgotSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.sent) FormBanner(message: l.msg12, positive: true),
          if (state.failure case final failure?)
            FormBanner(message: failureText(l, failure)),
          TextField(
            key: const Key('forgot-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l.authEmailLabel,
              errorText: emailError == null
                  ? null
                  : messageText(l, emailError, field: l.authEmailField),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('forgot-submit'),
            onPressed: state.pending || state.wait > 0 ? null : _submit,
            child: Text(
              state.wait > 0 ? l.authResendIn(state.wait) : l.authForgotSubmit,
            ),
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
