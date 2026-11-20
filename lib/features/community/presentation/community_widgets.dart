import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/format/age_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/market.dart';
import '../domain/community.dart';

/// `/community/{id}` (SCR-25), pushed over the feed or a notification.
String postLocation(String id) => '/community/${Uri.encodeComponent(id)}';

/// 5.3K, 12K, 1.2M: counts as the feed footer shows them (web).
String compactCount(int n) {
  if (n < 1000) return '$n';
  final (scaled, unit) = n < 1000000 ? (n / 1000, 'K') : (n / 1e6, 'M');
  final text = scaled < 10
      ? scaled.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')
      : '${scaled.floor()}';
  return '$text$unit';
}

/// Two letters for an avatar without a picture (web `initials`).
String initialsOf(String? name) {
  final words = (name ?? '')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2);
  final letters = words.map((w) => w[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.author, this.size = 32, super.key});

  final Author author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final letters = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cp.raised, shape: BoxShape.circle),
      child: Text(
        initialsOf(author.displayName),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: cp.muted,
        ),
      ),
    );
    final url = author.avatarUrl;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: url == null || !url.startsWith('https://')
            ? letters
            : ClipOval(
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 3).round(),
                  frameBuilder: (_, child, frame, sync) =>
                      sync || frame != null ? child : letters,
                  errorBuilder: (_, _, _) => letters,
                ),
              ),
      ),
    );
  }
}

/// Avatar, name, age and "edited" (and Official) on one line.
class AuthorLine extends ConsumerWidget {
  const AuthorLine({
    required this.author,
    required this.createdAt,
    this.edited = false,
    this.official = false,
    this.trailing,
    this.avatar = 32,
    super.key,
  });

  final Author author;
  final DateTime createdAt;
  final bool edited;
  final bool official;
  final Widget? trailing;
  final double avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final small = Theme.of(context).textTheme.bodySmall;
    final now = ref.watch(clockProvider)();
    final when = [
      formatAge(l, createdAt, now),
      if (edited) l.communityEdited,
    ].join(' · ');
    return Row(
      children: [
        MemberAvatar(author: author, size: avatar),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author.displayName ?? l.communityUnknownAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (official) ...[
                    const SizedBox(width: 6),
                    OfficialBadge(label: l.communityOfficial),
                  ],
                ],
              ),
              Text(when, style: small?.copyWith(color: cp.muted)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class OfficialBadge extends StatelessWidget {
  const OfficialBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: primary),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: primary),
      ),
    );
  }
}

/// `#BTC #SOL · Futures`.
class CoinTags extends StatelessWidget {
  const CoinTags({required this.coins, this.market, super.key});

  final List<String> coins;
  final Market? market;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final parts = [
      ...coins.map((c) => '#$c'),
      if (market != null)
        market == Market.spot ? l.marketSpot : l.marketFutures,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: cp.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// A count with an icon that toggles (like, save); 48 dp to tap.
class ReactionButton extends StatelessWidget {
  const ReactionButton({
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.tooltip,
    required this.onPressed,
    this.count,
    this.activeColor,
    super.key,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final String tooltip;
  final VoidCallback? onPressed;
  final int? count;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final color = active
        ? activeColor ?? Theme.of(context).colorScheme.primary
        : cp.muted;
    return Semantics(
      button: true,
      toggled: active,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      active ? activeIcon : icon,
                      size: 20,
                      color: color,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 4),
                    ExcludeSemantics(
                      child: Text(
                        compactCount(count!),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A feed card (SCR-24): author, title, excerpt, cover, tags and the
/// reactions; it opens SCR-25.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.onLike,
    required this.onSave,
    this.pinned = false,
    super.key,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final cover = post.media.isEmpty ? null : post.media.first;
    final coverImage = cover?.kind == MediaKind.video
        ? cover?.thumbnailUrl
        : cover?.url;
    return InkWell(
      key: Key('post-${post.id}'),
      onTap: () => context.push(postLocation(post.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pinned)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.push_pin_outlined, size: 14, color: cp.muted),
                    const SizedBox(width: 4),
                    Text(
                      l.communityPinned,
                      style: text.labelSmall?.copyWith(color: cp.muted),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AuthorLine(
                author: post.author,
                createdAt: post.createdAt,
                edited: post.edited,
                official: post.official,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (post.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: cp.muted),
                    ),
                  ],
                  if (coverImage != null &&
                      coverImage.startsWith('https://')) ...[
                    const SizedBox(height: 8),
                    MediaFrame(
                      url: coverImage,
                      video: cover?.kind == MediaKind.video,
                    ),
                  ],
                  const SizedBox(height: 6),
                  CoinTags(coins: post.coins, market: post.market),
                ],
              ),
            ),
            Row(
              children: [
                ReactionButton(
                  key: Key('like-${post.id}'),
                  icon: Icons.favorite_border,
                  activeIcon: Icons.favorite,
                  active: post.likedByMe,
                  activeColor: cp.negative,
                  count: post.likeCount,
                  tooltip: post.likedByMe ? l.communityUnlike : l.communityLike,
                  onPressed: onLike,
                ),
                ReactionButton(
                  icon: Icons.mode_comment_outlined,
                  activeIcon: Icons.mode_comment,
                  active: false,
                  count: post.commentCount,
                  tooltip: l.communityComments,
                  onPressed: () => context.push(postLocation(post.id)),
                ),
                const Spacer(),
                ReactionButton(
                  key: Key('save-${post.id}'),
                  icon: Icons.bookmark_border,
                  activeIcon: Icons.bookmark,
                  active: post.savedByMe,
                  tooltip: post.savedByMe ? l.communityUnsave : l.communitySave,
                  onPressed: onSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An image, or a video's poster with ▶, at 16:9 with rounded corners.
class MediaFrame extends StatelessWidget {
  const MediaFrame({
    required this.url,
    this.video = false,
    this.aspectRatio = 16 / 9,
    super.key,
  });

  final String url;
  final bool video;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final placeholder = ColoredBox(color: cp.raised);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                frameBuilder: (_, child, frame, sync) =>
                    sync || frame != null ? child : placeholder,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
            if (video)
              const Center(
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.play_arrow, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
