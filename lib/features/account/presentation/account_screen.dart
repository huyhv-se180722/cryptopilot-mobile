import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../data/profile_api.dart';
import '../domain/profile.dart';

/// The account screen of A-59 (PENDING): who is signed in, the e-mail and push
/// switches of the SCR-07 Notifications tab, appearance, links to the web
/// screens, the disclaimer and Log out.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  Profile? _profile;
  ApiFailure? _loadFailure;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailure = null);
    try {
      final profile = await ref.read(profileApiProvider).profile();
      if (mounted) setState(() => _profile = profile);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _loadFailure = failure);
    }
  }

  Future<void> _save(Profile next) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final before = _profile;
    setState(() {
      _profile = next;
      _saving = true;
    });
    try {
      await ref
          .read(profileApiProvider)
          .saveNotifications(email: next.notifyEmail, push: next.notifyPush);
      messenger.showSnackBar(SnackBar(content: Text(l.msg14)));
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _profile = before);
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.accountSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.accountSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final profile = _profile;
    final themeMode = ref.watch(themeModeProvider);
    final web = ref.read(webLinksProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (profile != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(
                  profile.displayName.isEmpty
                      ? '?'
                      : profile.displayName.characters.first.toUpperCase(),
                ),
              ),
              title: Text(profile.displayName, style: text.titleMedium),
              subtitle: Text(profile.email),
            )
          else if (_loadFailure != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(failureText(l, _loadFailure!)),
              trailing: TextButton(
                onPressed: _load,
                child: Text(l.commonRetry),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 16),
          _Section(title: l.accountNotifications),
          Text(l.accountNotificationsHint, style: text.bodySmall),
          SwitchListTile(
            key: const Key('notify-email'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountNotifyEmail),
            value: profile?.notifyEmail ?? false,
            onChanged: profile == null || _saving
                ? null
                : (value) => _save(profile.copyWith(notifyEmail: value)),
          ),
          SwitchListTile(
            key: const Key('notify-push'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountNotifyPush),
            value: profile?.notifyPush ?? false,
            onChanged: profile == null || _saving
                ? null
                : (value) => _save(profile.copyWith(notifyPush: value)),
          ),
          const SizedBox(height: 16),
          _Section(title: l.accountAppearance),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l.themeSystem),
              ),
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) =>
                ref.read(themeModeProvider.notifier).select(selection.first),
          ),
          const SizedBox(height: 24),
          _Section(title: l.accountOnWeb),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountProfileLink),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => web.open('/profile'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountSubscriptionLink),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => web.open('/subscription'),
          ),
          const SizedBox(height: 16),
          _Section(title: l.accountAbout),
          const SizedBox(height: 8),
          Text(
            l.msg42,
            style: text.bodySmall?.copyWith(color: context.cp.muted),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            key: const Key('sign-out'),
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: Text(l.accountSignOut),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: context.cp.muted,
      letterSpacing: 0.8,
    ),
  );
}
