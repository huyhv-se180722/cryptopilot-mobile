import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/age_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/member_controllers.dart';
import '../domain/community.dart';
import 'community_widgets.dart';

/// A member page (A-66, T-136): head, follow and block, the coins they
/// post about, and their posts, comments and reactions.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({required this.id, super.key});

  final String id;

  Future<void> _tell(BuildContext context, Future<ApiFailure?> action) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await action;
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  Future<void> _block(
    BuildContext context,
    WidgetRef ref,
    MemberProfile profile,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = profile.author.displayName ?? l.communityUnknownAuthor;
    if (!profile.blockedByMe) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.memberBlockTitle(name)),
          content: Text(l.memberBlockBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const Key('member-block-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.memberBlock(name)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final failure = await ref.read(memberProvider(id).notifier).toggleBlock();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure != null
              ? failureText(l, failure)
              : profile.blockedByMe
              ? l.memberUnblocked(name)
              : l.memberBlocked(name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(memberProvider(id));
    final profile = state.profile;
    final name = profile?.author.displayName ?? l.communityUnknownAuthor;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(profile == null ? '' : name),
          actions: [
            if (profile != null &&
                (profile.me || state.canRelate || profile.blockedByMe))
              PopupMenuButton<String>(
                key: const Key('member-menu'),
                tooltip: l.memberMore,
                onSelected: (action) => action == 'blocks'
                    ? unawaited(context.push('/community/blocks'))
                    : unawaited(_block(context, ref, profile)),
                itemBuilder: (_) => [
                  if (profile.me)
                    PopupMenuItem(
                      key: const Key('member-blocks'),
                      value: 'blocks',
                      child: Text(l.memberBlockedList),
                    )
                  else
                    PopupMenuItem(
                      key: const Key('member-block'),
                      value: 'block',
                      child: Text(
                        profile.blockedByMe
                            ? l.memberUnblock
                            : l.memberBlock(name),
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: switch (state) {
          MemberState(profile: null, failure: null) => const Center(
            child: CircularProgressIndicator(),
          ),
          MemberState(profile: null) when state.missing => Center(
            key: const Key('member-missing'),
            child: Text(l.msg41),
          ),
          MemberState(profile: null, :final failure?) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(failureText(l, failure)),
                TextButton(
                  onPressed: ref.read(memberProvider(id).notifier).load,
                  child: Text(l.commonRetry),
                ),
              ],
            ),
          ),
          _ => NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: _Head(
                  profile: profile!,
                  coins: state.coins,
                  canRelate: state.canRelate,
                  onFollow: () => _tell(
                    context,
                    ref.read(memberProvider(id).notifier).toggleFollow(),
                  ),
                  onUnblock: () => _block(context, ref, profile),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsHeader(
                  TabBar(
                    key: const Key('member-tabs'),
                    tabs: [
                      Tab(text: l.memberTabPosts),
                      Tab(text: l.memberTabComments),
                      Tab(text: l.memberTabReactions),
                    ],
                  ),
                  Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ],
            body: TabBarView(
              children: [
                // An administrator's posts are their official ones, which
                // the feed by author leaves out (Q-98).
                if (state.administrator)
                  _OfficialList(posts: state.officialPosts)
                else
                  _ActivityList(memberId: id, list: MemberList.posts),
                _ActivityList(memberId: id, list: MemberList.comments),
                _ActivityList(memberId: id, list: MemberList.reactions),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader(this.tabs, this.color);

  final TabBar tabs;
  final Color color;

  @override
  double get minExtent => tabs.preferredSize.height;
  @override
  double get maxExtent => tabs.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) =>
      ColoredBox(color: color, child: tabs);

  @override
  bool shouldRebuild(_TabsHeader old) => old.tabs != tabs;
}

class _Head extends ConsumerWidget {
  const _Head({
    required this.profile,
    required this.coins,
    required this.canRelate,
    required this.onFollow,
    required this.onUnblock,
  });

  final MemberProfile profile;
  final List<TokenMention> coins;

  /// Another Trader's page: Follow shows (not an administrator, D-99).
  final bool canRelate;
  final VoidCallback onFollow;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final p = profile;
    final banner = p.bannerUrl;
    final id = p.author.userId;
    // Four equal shares of the width; a long label wraps (360 dp).
    Widget stat(String label, int value, {String? list}) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            Text(compactCount(value), style: text.titleSmall),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: cp.muted),
            ),
          ],
        ),
      );
      return Expanded(
        child: list == null
            ? child
            : InkWell(
                key: Key('member-$list'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('${memberLocation(id)}/$list'),
                child: child,
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3,
          child: banner != null && banner.startsWith('https://')
              ? ExcludeSemantics(
                  child: Image.network(
                    banner,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: cp.raised),
                  ),
                )
              : ColoredBox(color: cp.raised),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MemberAvatar(author: p.author, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.author.displayName ??
                                    l.communityUnknownAuthor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium,
                              ),
                            ),
                            if (p.me) ...[
                              const SizedBox(width: 6),
                              OfficialBadge(label: l.memberYou),
                            ],
                          ],
                        ),
                        Text(
                          l.memberJoined(
                            DateFormat(
                              'MMM yyyy',
                              'en',
                            ).format(p.joinedAt.toLocal()),
                          ),
                          style: text.bodySmall?.copyWith(color: cp.muted),
                        ),
                      ],
                    ),
                  ),
                  if (canRelate && !p.blockedByMe)
                    p.followedByMe
                        ? OutlinedButton(
                            key: const Key('member-follow'),
                            onPressed: onFollow,
                            child: Text(l.memberFollowingButton),
                          )
                        : FilledButton(
                            key: const Key('member-follow'),
                            onPressed: onFollow,
                            child: Text(l.memberFollow),
                          ),
                  if (p.blockedByMe)
                    OutlinedButton(
                      key: const Key('member-unblock'),
                      onPressed: onUnblock,
                      child: Text(l.memberUnblock),
                    ),
                ],
              ),
              if (p.bio case final bio? when bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(bio),
              ],
              if (p.websiteUrl case final site?
                  when site.startsWith('https://') ||
                      site.startsWith('http://')) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('member-site'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () =>
                        unawaited(ref.read(webLinksProvider).openAddress(site)),
                    icon: const Icon(Icons.link, size: 16),
                    label: Text(
                      Uri.tryParse(site)?.host ?? site,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  stat(l.memberPosts, p.posts),
                  stat(l.memberLikes, p.likesReceived),
                  stat(l.memberFollowers, p.followers, list: 'followers'),
                  stat(l.memberFollowing, p.following, list: 'following'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${l.memberInfluence(p.influenceScore.toStringAsFixed(1))} · '
                '${l.memberDepth(p.depthScore.toStringAsFixed(1))}',
                style: text.bodySmall?.copyWith(color: cp.muted),
              ),
              if (coins.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l.memberCoins, style: text.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final c in coins)
                      Chip(
                        key: Key('member-coin-${c.symbol}'),
                        avatar: CoinLogo(symbol: c.symbol, size: 18),
                        label: Text(
                          '${c.symbol} ${c.sharePercent.toStringAsFixed(0)}%',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (p.blockedByMe) ...[
                const SizedBox(height: 8),
                Text(
                  l.memberBlocked(
                    p.author.displayName ?? l.communityUnknownAuthor,
                  ),
                  key: const Key('member-blocked-note'),
                  style: text.bodySmall?.copyWith(color: cp.negative),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One activity tab of a member page.
class _ActivityList extends ConsumerWidget {
  const _ActivityList({required this.memberId, required this.list});

  final String memberId;
  final MemberList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final key = (memberId: memberId, list: list);
    final state = ref.watch(memberListProvider(key));
    final ctl = ref.read(memberListProvider(key).notifier);
    final items = state.items;
    if (items == null && state.failure != null) {
      return Center(
        child: TextButton(onPressed: ctl.load, child: Text(l.commonRetry)),
      );
    }
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        key: Key('member-empty-${list.name}'),
        child: Text(switch (list) {
          MemberList.posts => l.memberEmptyPosts,
          MemberList.comments => l.memberEmptyComments,
          _ => l.memberEmptyReactions,
        }, style: TextStyle(color: cp.muted)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) unawaited(ctl.loadMore());
        return false;
      },
      child: ListView.separated(
        key: Key('member-list-${list.name}'),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: cp.border),
        itemBuilder: (context, i) => switch (items[i]) {
          final Post post => PostCard(
            post: post,
            // Reactions are read only here; the post itself takes them.
            onLike: () => context.push(postLocation(post.id)),
            onSave: () => context.push(postLocation(post.id)),
          ),
          final MemberComment c => _CommentRow(comment: c),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// The official posts of an administrator.
class _OfficialList extends StatelessWidget {
  const _OfficialList({required this.posts});

  final List<Post> posts;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const Key('member-list-official'),
    padding: const EdgeInsets.only(bottom: 24),
    itemCount: posts.length,
    separatorBuilder: (_, _) => Divider(height: 1, color: context.cp.border),
    itemBuilder: (context, i) => PostCard(
      post: posts[i],
      pinned: true,
      onLike: () => context.push(postLocation(posts[i].id)),
      onSave: () => context.push(postLocation(posts[i].id)),
    ),
  );
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({required this.comment});

  final MemberComment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final now = ref.watch(clockProvider)();
    return ListTile(
      key: Key('member-comment-${comment.commentId}'),
      onTap: () => context.push(postLocation(comment.postId)),
      title: Text(
        comment.content,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${l.memberCommentedOn(comment.postTitle)} · '
        '${formatAge(l, comment.createdAt, now)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cp.muted),
      ),
    );
  }
}

/// Followers, following, or the caller's blocks (`memberId` ignored),
/// each opening the member page; a blocked one can be unblocked here.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({required this.memberId, required this.list, super.key});

  final String memberId;
  final MemberList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final key = (memberId: memberId, list: list);
    final state = ref.watch(memberListProvider(key));
    final ctl = ref.read(memberListProvider(key).notifier);
    final items = state.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (list) {
          MemberList.followers => l.memberFollowers,
          MemberList.following => l.memberFollowing,
          _ => l.memberBlockedList,
        }),
      ),
      body: items == null && state.failure != null
          ? Center(
              child: TextButton(
                onPressed: ctl.load,
                child: Text(l.commonRetry),
              ),
            )
          : items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              key: const Key('people-empty'),
              child: Text(l.memberNoPeople, style: TextStyle(color: cp.muted)),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 400) unawaited(ctl.loadMore());
                return false;
              },
              child: ListView(
                key: const Key('people-list'),
                children: [
                  for (final a in items.whereType<Author>())
                    ListTile(
                      key: Key('person-${a.userId}'),
                      leading: MemberAvatar(author: a, size: 36),
                      title: Text(a.displayName ?? l.communityUnknownAuthor),
                      onTap: () => context.push(memberLocation(a.userId)),
                      trailing: list == MemberList.blocked
                          ? OutlinedButton(
                              key: Key('unblock-${a.userId}'),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final failure = await ctl.unblock(a.userId);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      failure != null
                                          ? failureText(l, failure)
                                          : l.memberUnblocked(
                                              a.displayName ??
                                                  l.communityUnknownAuthor,
                                            ),
                                    ),
                                  ),
                                );
                              },
                              child: Text(l.memberUnblock),
                            )
                          : null,
                    ),
                ],
              ),
            ),
    );
  }
}
