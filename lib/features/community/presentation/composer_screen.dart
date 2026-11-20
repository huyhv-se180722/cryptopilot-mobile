import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/market.dart';
import '../application/composer_controller.dart';
import '../domain/community.dart';
import 'coin_picker.dart';
import 'community_widgets.dart';

String _megabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb == mb.roundToDouble() ? mb.round() : mb.toStringAsFixed(1)} MB';
}

/// SCR-26 (A-66, T-135): a new post ([postId] null) or the caller's own
/// post edited; up to 4 images or one video, sent as they are picked.
class ComposerScreen extends ConsumerStatefulWidget {
  const ComposerScreen({this.postId, super.key});

  final String? postId;

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  ComposerController get _ctl =>
      ref.read(composerProvider(widget.postId).notifier);

  Future<void> _publish() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final post = await _ctl.submit();
    if (post == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(widget.postId == null ? l.msg33 : l.composerSaved),
      ),
    );
    if (widget.postId == null) {
      unawaited(router.pushReplacement(postLocation(post.id)));
    } else {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final state = ref.watch(composerProvider(widget.postId));
    // An edited post fills the fields once it is read.
    if (state.loaded && !_filled) {
      _filled = true;
      _title.text = state.title;
      _content.text = state.content;
    }
    final editing = widget.postId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? l.composerEdit : l.composerNew),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              key: const Key('composer-publish'),
              onPressed: state.canPublish ? _publish : null,
              child: state.submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(editing ? l.communitySaveChanges : l.composerPublish),
            ),
          ),
        ],
      ),
      body: switch (state) {
        ComposerState(loaded: false, :final loadFailure?) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(failureText(l, loadFailure)),
              TextButton(onPressed: _ctl.retryLoad, child: Text(l.commonRetry)),
            ],
          ),
        ),
        ComposerState(loaded: false) => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => ListView(
          key: const Key('composer'),
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            TextField(
              key: const Key('composer-title'),
              controller: _title,
              maxLength: PostDraft.maxTitle,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.composerTitle,
                hintText: l.composerTitleHint,
                errorText: state.fieldErrors.contains('title')
                    ? l.composerFieldInvalid
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _ctl.setTitle,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('composer-content'),
              controller: _content,
              minLines: 5,
              maxLines: 12,
              maxLength: PostDraft.maxContent,
              textCapitalization: TextCapitalization.sentences,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => currentLength > 9000
                  ? Text('$currentLength/$maxLength')
                  : null,
              decoration: InputDecoration(
                hintText: l.composerContent,
                alignLabelWithHint: true,
                errorText: state.fieldErrors.contains('content')
                    ? l.composerFieldInvalid
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _ctl.setContent,
            ),
            const SizedBox(height: 12),
            _Coins(state: state, onToggle: _ctl.toggleCoin),
            const SizedBox(height: 12),
            _Label(l.composerMarket),
            Wrap(
              spacing: 6,
              children: [
                for (final (market, label) in [
                  (null, l.composerNoMarket),
                  (Market.spot, l.marketSpot),
                  (Market.futures, l.marketFutures),
                ])
                  ChoiceChip(
                    key: Key('composer-market-${market?.wire ?? 'NONE'}'),
                    label: Text(label),
                    selected: state.market == market,
                    onSelected: (_) => _ctl.setMarket(market),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Label(l.composerStance),
            Wrap(
              spacing: 6,
              children: [
                for (final (sentiment, label, color) in [
                  (null, l.composerNoStance, null),
                  (PostSentiment.bullish, l.communityBullish, cp.positive),
                  (PostSentiment.bearish, l.communityBearish, cp.negative),
                ])
                  ChoiceChip(
                    key: Key('composer-stance-${sentiment?.wire ?? 'NONE'}'),
                    label: Text(label),
                    selected: state.sentiment == sentiment,
                    selectedColor: color?.withValues(alpha: 0.16),
                    onSelected: (_) => _ctl.setSentiment(sentiment),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Media(state: state, controller: _ctl),
            if (state.failure case final failure?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  failureText(l, failure),
                  key: const Key('composer-failure'),
                  style: TextStyle(color: cp.negative),
                ),
              ),
          ],
        ),
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _Coins extends ConsumerWidget {
  const _Coins({required this.state, required this.onToggle});

  final ComposerState state;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final coins = listedCoins(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l.composerCoins),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final coin in state.coins)
              InputChip(
                key: Key('composer-coin-chip-$coin'),
                label: Text(coin),
                deleteButtonTooltipMessage: l.composerRemoveCoin(coin),
                onDeleted: () => onToggle(coin),
              ),
            if (state.coins.length < PostDraft.maxCoins)
              ActionChip(
                key: const Key('composer-add-coin'),
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l.composerAddCoin),
                onPressed: () async {
                  final coin = await showCoinPicker(
                    context,
                    coins,
                    keyPrefix: 'composer-coin',
                    chosen: state.coins.toSet(),
                  );
                  if (coin != null && coin.isNotEmpty) onToggle(coin);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.state, required this.controller});

  final ComposerState state;
  final ComposerController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.composerMediaHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cp.muted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('composer-add-images'),
              onPressed: state.canAddImages ? controller.addImages : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(l.composerAddImages),
            ),
            OutlinedButton.icon(
              key: const Key('composer-add-video'),
              onPressed: state.canAddVideo ? controller.addVideo : null,
              icon: const Icon(Icons.videocam_outlined),
              label: Text(l.composerAddVideo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in state.attachments)
              _AttachmentTile(attachment: a, controller: controller),
          ],
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.controller});

  final Attachment attachment;
  final ComposerController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final a = attachment;
    final failed = a.status == AttachmentStatus.failed;
    final placeholder = ColoredBox(
      color: cp.raised,
      child: Icon(
        a.kind == MediaKind.video
            ? Icons.videocam_outlined
            : Icons.image_outlined,
        color: cp.muted,
      ),
    );
    final picture = switch ((a.path, a.url)) {
      (final path?, _) when a.kind == MediaKind.image => Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => placeholder,
      ),
      (_, final url?) when url.startsWith('https://') => Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
      _ => placeholder,
    };
    final error = failed
        ? (a.failure != null
              ? failureText(l, a.failure!)
              : l.msg32(_megabytes(a.tooLarge ?? 0)))
        : null;
    return SizedBox(
      key: Key('composer-media-${a.key}'),
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: failed ? cp.negative : cp.border,
                      width: failed ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ExcludeSemantics(child: picture),
                ),
              ),
              if (a.status == AttachmentStatus.uploading)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: Text(
                        l.composerUploading((a.progress * 100).round()),
                        key: Key('composer-progress-${a.key}'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  key: Key('composer-remove-${a.key}'),
                  tooltip: l.composerRemove,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  iconSize: 16,
                  icon: const Icon(Icons.close),
                  onPressed: () => controller.remove(a),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              key: Key('composer-error-${a.key}'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cp.negative),
            ),
            if (a.path != null && a.failure == null)
              TextButton(
                key: Key('composer-retry-${a.key}'),
                onPressed: () => unawaited(controller.retry(a)),
                child: Text(l.commonRetry),
              ),
          ],
        ],
      ),
    );
  }
}
