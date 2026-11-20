import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../application/post_controller.dart';
import '../domain/community.dart';
import 'community_widgets.dart';
import 'report_sheet.dart';

/// SCR-25 (A-64): a post, its media and reactions, its comments with one
/// level of replies, and the comment box.
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  PostController get _ctl => ref.read(postProvider(widget.id).notifier);

  void _tell(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _react(Future<ApiFailure?> action) async {
    final failure = await action;
    if (failure != null && mounted) {
      _tell(failureText(AppLocalizations.of(context), failure));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final failure = await _ctl.addComment(text, parentId: _replyTo?.id);
    if (!mounted) return;
    setState(() => _sending = false);
    if (failure != null) {
      _tell(failureText(AppLocalizations.of(context), failure));
      return;
    }
    _input.clear();
    setState(() => _replyTo = null);
    _focus.unfocus();
  }

  void _reply(Comment comment) {
    setState(() => _replyTo = comment);
    _focus.requestFocus();
  }

  Future<void> _edit(Comment comment) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditCommentDialog(initial: comment.content),
    );
    if (text == null || !mounted) return;
    await _react(_ctl.editComment(comment, text));
  }

  Future<void> _deleteComment(Comment comment) async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(
      l.communityCommentDeleteTitle,
      l.communityCommentDeleteBody,
    );
    if (ok) await _react(_ctl.deleteComment(comment));
  }

  Future<bool> _confirm(String title, [String? body]) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.communityDelete),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deletePost() async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(l.communityDeleteTitle)) return;
    final failure = await _ctl.deletePost();
    if (!mounted) return;
    if (failure != null) {
      _tell(failureText(l, failure));
      return;
    }
    _tell(l.communityDeleted);
    context.pop();
  }

  Future<void> _report({Comment? comment}) => showReportSheet(
    context,
    comment: comment != null,
    submit: (reason, details) =>
        _ctl.report(reason, description: details, comment: comment),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(postProvider(widget.id));
    final post = state.post;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (post != null)
            PopupMenuButton<String>(
              key: const Key('post-menu'),
              tooltip: l.communityMenu,
              onSelected: (action) => switch (action) {
                'report' => unawaited(_report()),
                'delete' => unawaited(_deletePost()),
                // SCR-26 in the app since T-135 (the web before).
                _ => unawaited(context.push('${postLocation(post.id)}/edit')),
              },
              itemBuilder: (_) => [
                if (!post.mine)
                  PopupMenuItem(
                    key: const Key('post-report'),
                    value: 'report',
                    child: Text(l.communityReport),
                  ),
                if (post.mine) ...[
                  PopupMenuItem(
                    key: const Key('post-edit'),
                    value: 'edit',
                    child: Text(l.composerEdit),
                  ),
                  PopupMenuItem(
                    key: const Key('post-delete'),
                    value: 'delete',
                    child: Text(l.communityDelete),
                  ),
                ],
              ],
            ),
        ],
      ),
      body: switch (state) {
        PostState(post: null, failure: null) => const Center(
          child: CircularProgressIndicator(),
        ),
        PostState(post: null) when state.missing => Center(
          key: const Key('post-missing'),
          child: Text(l.msg41),
        ),
        PostState(post: null, :final failure?) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(failureText(l, failure)),
              TextButton(onPressed: _ctl.load, child: Text(l.commonRetry)),
            ],
          ),
        ),
        _ => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _ctl.load,
                child: ListView(
                  key: const Key('post-detail'),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _PostBody(
                      post: post!,
                      onLike: () => _react(_ctl.toggleLike()),
                      onSave: () => _react(_ctl.toggleSave()),
                      onVote: (s) => _react(_ctl.vote(s)),
                    ),
                    _Comments(
                      state: state,
                      onLike: (c) => _react(_ctl.toggleCommentLike(c)),
                      onReply: _reply,
                      onEdit: _edit,
                      onDelete: _deleteComment,
                      onReport: (c) => _report(comment: c),
                      onMore: _ctl.loadMoreComments,
                      onRetry: _ctl.loadComments,
                    ),
                  ],
                ),
              ),
            ),
            _Composer(
              input: _input,
              focus: _focus,
              replyTo: _replyTo,
              sending: _sending,
              onCancelReply: () => setState(() => _replyTo = null),
              onSend: _send,
            ),
          ],
        ),
      },
    );
  }
}

class _PostBody extends ConsumerWidget {
  const _PostBody({
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onVote,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final ValueChanged<PostSentiment> onVote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AuthorLine(
              author: post.author,
              createdAt: post.createdAt,
              edited: post.edited,
              official: post.official,
              avatar: 40,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  post.text,
                  key: const Key('post-content'),
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
                for (final medium in post.media) ...[
                  const SizedBox(height: 10),
                  _Medium(medium: medium),
                ],
                const SizedBox(height: 10),
                CoinTags(coins: post.coins, market: post.market),
              ],
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ReactionButton(
                key: const Key('post-like'),
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                active: post.likedByMe,
                activeColor: cp.negative,
                count: post.likeCount,
                tooltip: post.likedByMe ? l.communityUnlike : l.communityLike,
                onPressed: onLike,
              ),
              ReactionButton(
                key: const Key('post-save'),
                icon: Icons.bookmark_border,
                activeIcon: Icons.bookmark,
                active: post.savedByMe,
                tooltip: post.savedByMe ? l.communityUnsave : l.communitySave,
                onPressed: onSave,
              ),
              const SizedBox(width: 4),
              _VoteChip(
                key: const Key('vote-bullish'),
                label: l.communityBullish,
                tooltip: l.communityVoteBullish,
                count: post.bullishCount,
                active: post.myVote == PostSentiment.bullish,
                color: cp.positive,
                icon: Icons.trending_up,
                onTap: () => onVote(PostSentiment.bullish),
              ),
              const SizedBox(width: 6),
              _VoteChip(
                key: const Key('vote-bearish'),
                label: l.communityBearish,
                tooltip: l.communityVoteBearish,
                count: post.bearishCount,
                active: post.myVote == PostSentiment.bearish,
                color: cp.negative,
                icon: Icons.trending_down,
                onTap: () => onVote(PostSentiment.bearish),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.label,
    required this.tooltip,
    required this.count,
    required this.active,
    required this.color,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String tooltip;
  final int count;
  final bool active;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: FilterChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text('$label ${compactCount(count)}'),
      selected: active,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: active ? color : context.cp.border),
      onSelected: (_) => onTap(),
    ),
  );
}

class _Medium extends ConsumerWidget {
  const _Medium({required this.medium});

  final PostMedia medium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final video = medium.kind == MediaKind.video;
    final poster = video ? medium.thumbnailUrl : medium.url;
    final ratio = (medium.width ?? 0) > 0 && (medium.height ?? 0) > 0
        ? medium.width! / medium.height!
        : 16 / 9;
    final frame = poster != null && poster.startsWith('https://')
        ? MediaFrame(
            url: poster,
            video: video,
            aspectRatio: ratio.clamp(0.75, 2.0),
          )
        : AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: context.cp.raised,
              child: Center(
                child: Icon(
                  video ? Icons.play_circle_outline : Icons.image_outlined,
                  size: 40,
                  color: context.cp.muted,
                ),
              ),
            ),
          );
    return Semantics(
      button: true,
      label: video ? l.communityWatchVideo : l.communityOpenImage,
      child: InkWell(
        key: Key('medium-${medium.publicId}'),
        onTap: video
            ? () =>
                  unawaited(ref.read(webLinksProvider).openAddress(medium.url))
            : () => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) => _ImageViewer(url: medium.url),
                ),
              ),
        child: frame,
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: Stack(
      children: [
        Center(
          child: InteractiveViewer(
            maxScale: 4,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
        SafeArea(
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            color: Colors.white,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    ),
  );
}

class _Comments extends StatelessWidget {
  const _Comments({
    required this.state,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onMore,
    required this.onRetry,
  });

  final PostState state;
  final ValueChanged<Comment> onLike;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;
  final ValueChanged<Comment> onReport;
  final Future<void> Function() onMore;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final comments = state.comments;
    final count = state.post?.commentCount ?? 0;
    Widget tile(Comment c, {required bool reply}) => _CommentTile(
      comment: c,
      reply: reply,
      onLike: () => onLike(c),
      onReply: reply ? null : () => onReply(c),
      onEdit: () => onEdit(c),
      onDelete: () => onDelete(c),
      onReport: () => onReport(c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: cp.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l.communityCommentsCount(count),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (comments == null && state.commentsFailure != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text(failureText(l, state.commentsFailure!))),
                TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
              ],
            ),
          )
        else if (comments == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (comments.isEmpty)
          Padding(
            key: const Key('comments-empty'),
            padding: const EdgeInsets.all(16),
            child: Text(
              l.communityNoComments,
              style: TextStyle(color: cp.muted),
            ),
          )
        else ...[
          for (final c in comments) ...[
            tile(c, reply: false),
            for (final r in c.replies) tile(r, reply: true),
          ],
          if (state.more)
            Center(
              child: TextButton(
                key: const Key('comments-more'),
                onPressed: state.loadingMore ? null : onMore,
                child: Text(l.communityLoadMore),
              ),
            ),
        ],
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.reply,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  final Comment comment;
  final bool reply;
  final VoidCallback onLike;
  final VoidCallback? onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final gone = comment.deleted || comment.hidden;
    return Padding(
      key: Key('comment-${comment.id}'),
      padding: EdgeInsets.fromLTRB(reply ? 52 : 16, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthorLine(
            author: comment.author,
            createdAt: comment.createdAt,
            avatar: 28,
            trailing: gone
                ? null
                : PopupMenuButton<String>(
                    key: Key('comment-menu-${comment.id}'),
                    tooltip: l.communityMenu,
                    onSelected: (a) => switch (a) {
                      'edit' => onEdit(),
                      'delete' => onDelete(),
                      _ => onReport(),
                    },
                    itemBuilder: (_) => [
                      if (comment.mine) ...[
                        PopupMenuItem(
                          key: Key('comment-edit-${comment.id}'),
                          value: 'edit',
                          child: Text(l.communityEditComment),
                        ),
                        PopupMenuItem(
                          key: Key('comment-delete-${comment.id}'),
                          value: 'delete',
                          child: Text(l.communityDelete),
                        ),
                      ] else
                        PopupMenuItem(
                          key: Key('comment-report-${comment.id}'),
                          value: 'report',
                          child: Text(l.communityReport),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 12, top: 2),
            child: gone
                ? Text(
                    l.communityCommentDeleted,
                    style: TextStyle(
                      color: cp.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(comment.content),
          ),
          if (!gone)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                children: [
                  ReactionButton(
                    key: Key('comment-like-${comment.id}'),
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    active: comment.likedByMe,
                    activeColor: cp.negative,
                    count: comment.likeCount,
                    tooltip: comment.likedByMe
                        ? l.communityUnlike
                        : l.communityLike,
                    onPressed: onLike,
                  ),
                  if (onReply != null)
                    TextButton(
                      key: Key('comment-reply-${comment.id}'),
                      onPressed: onReply,
                      child: Text(l.communityReply),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.focus,
    required this.replyTo,
    required this.sending,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController input;
  final FocusNode focus;
  final Comment? replyTo;
  final bool sending;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final target = replyTo;
    return Material(
      color: cp.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cp.border)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (target != null)
                Row(
                  key: const Key('replying-to'),
                  children: [
                    Expanded(
                      child: Text(
                        l.communityReplyingTo(
                          target.author.displayName ?? l.communityUnknownAuthor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: cp.muted),
                      ),
                    ),
                    IconButton(
                      key: const Key('cancel-reply'),
                      tooltip: l.communityCancelReply,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onCancelReply,
                    ),
                  ],
                ),
              ValueListenableBuilder(
                valueListenable: input,
                builder: (context, value, _) {
                  final empty = value.text.trim().isEmpty;
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('comment-input'),
                          controller: input,
                          focusNode: focus,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: PostController.maxComment,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => currentLength > 1800
                              ? Text('$currentLength/$maxLength')
                              : null,
                          decoration: InputDecoration(
                            hintText: target == null
                                ? l.communityCommentPlaceholder
                                : l.communityReplyPlaceholder,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('comment-send'),
                        tooltip: target == null
                            ? l.communitySend
                            : l.communitySendReply,
                        onPressed: empty || sending ? null : onSend,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initial});

  final String initial;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.communityEditComment),
      content: TextField(
        key: const Key('comment-edit-field'),
        controller: _text,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        maxLength: PostController.maxComment,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('comment-edit-save'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(l.communitySaveChanges),
        ),
      ],
    );
  }
}
