import 'package:flutter/material.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/post_controller.dart';
import '../domain/community.dart';

String reasonName(AppLocalizations l, ReportReason reason) => switch (reason) {
  ReportReason.spam => l.communityReasonSpam,
  ReportReason.scam => l.communityReasonScam,
  ReportReason.abuse => l.communityReasonAbuse,
  ReportReason.misleading => l.communityReasonMisleading,
  ReportReason.other => l.communityReasonOther,
};

/// SCR-27 for a post, or for a comment when [comment] is true: a reason,
/// details (required for OTHER, at most 500). It closes with MSG34, or
/// with "already reported" (BR-46); another refusal stays in the sheet.
Future<void> showReportSheet(
  BuildContext context, {
  required bool comment,
  required Future<ReportOutcome> Function(ReportReason, String?) submit,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await showModalBottomSheet<ReportOutcome>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportForm(comment: comment, submit: submit),
  );
  if (outcome == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (outcome) {
        ReportOutcome.submitted => l.msg34,
        ReportOutcome.alreadyReported =>
          comment
              ? l.communityAlreadyReportedComment
              : l.communityAlreadyReportedPost,
      }),
    ),
  );
}

class _ReportForm extends StatefulWidget {
  const _ReportForm({required this.comment, required this.submit});

  final bool comment;
  final Future<ReportOutcome> Function(ReportReason, String?) submit;

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  static const maxDetails = 500;

  final _details = TextEditingController();
  ReportReason? _reason;
  String? _fieldError;
  String? _failure;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final reason = _reason;
    if (reason == null) return;
    final text = _details.text.trim();
    if (reason == ReportReason.other && text.isEmpty) {
      setState(() => _fieldError = l.communityReportDetailsRequired);
      return;
    }
    setState(() {
      _fieldError = null;
      _failure = null;
      _sending = true;
    });
    try {
      final outcome = await widget.submit(reason, text.isEmpty ? null : text);
      if (mounted) Navigator.of(context).pop(outcome);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failure = failureText(l, failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('report-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.comment
                    ? l.communityReportComment
                    : l.communityReportPost,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l.communityReportReason,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (r) => setState(() => _reason = r),
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        key: Key('report-${reason.wire}'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: reason,
                        title: Text(reasonName(l, reason)),
                      ),
                  ],
                ),
              ),
              TextField(
                key: const Key('report-details'),
                controller: _details,
                maxLength: maxDetails,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l.communityReportDetails,
                  helperText: l.communityReportDetailsHint,
                  errorText: _fieldError,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _failure!,
                    key: const Key('report-failure'),
                    style: TextStyle(color: context.cp.negative),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('report-submit'),
                onPressed: _reason == null || _sending ? null : _send,
                child: Text(l.communityReportSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
