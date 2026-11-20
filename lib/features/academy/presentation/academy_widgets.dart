import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../data/academy_progress_repository.dart';
import '../domain/academy.dart';

/// The lesson page of [slug].
String lessonLocation(String slug) =>
    '/academy/lesson/${Uri.encodeComponent(slug)}';

String levelLabel(AppLocalizations l, LessonLevel level) => switch (level) {
  LessonLevel.beginner => l.academyLevelBeginner,
  LessonLevel.intermediate => l.academyLevelIntermediate,
  LessonLevel.advanced => l.academyLevelAdvanced,
};

/// `dd/MM/yyyy`, the same whatever the device language.
String academyDate(DateTime at) {
  final local = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// "Educational content only, not investment advice" on every Academy screen.
class AcademyDisclaimer extends StatelessWidget {
  const AcademyDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      key: const Key('academy-disclaimer'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: context.cp.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.academyDisclaimer,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.cp.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A failure of a read, with Try again.
class AcademyFailure extends StatelessWidget {
  const AcademyFailure({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            failureText(l, failure),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.cp.muted),
          ),
          TextButton(onPressed: onRetry, child: Text(l.academyRetry)),
        ],
      ),
    );
  }
}

/// A cover photo, or the topic's tint when there is none or it fails.
class LessonCover extends StatelessWidget {
  const LessonCover({required this.url, super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: context.cp.raised,
      child: Center(
        child: Icon(Icons.school_outlined, color: context.cp.muted),
      ),
    );
    final address = url;
    if (address == null) return placeholder;
    return Image.network(
      address,
      fit: BoxFit.cover,
      // The tint holds the place while the photo loads (device check).
      frameBuilder: (_, child, frame, sync) =>
          sync || frame != null ? child : placeholder,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Level · reading time, and Learned when the Trader marked the lesson.
class LessonMeta extends ConsumerWidget {
  const LessonMeta({required this.lesson, super.key});

  final LessonSummary lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final learned = ref.watch(
      academyProgressProvider.select((s) => s.learned(lesson.slug)),
    );
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.cp.muted);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(levelLabel(l, lesson.level), style: style),
        Text('·', style: style),
        Text(l.academyReadingTime(lesson.readingMinutes), style: style),
        if (learned)
          Row(
            key: Key('learned-${lesson.slug}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 14, color: context.cp.positive),
              const SizedBox(width: 4),
              Text(
                l.academyLearned,
                style: style?.copyWith(color: context.cp.positive),
              ),
            ],
          ),
      ],
    );
  }
}

/// A lesson in a list: cover, title, two lines of summary, level and time.
class LessonCard extends StatelessWidget {
  const LessonCard({required this.lesson, super.key});

  final LessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      key: Key('lesson-${lesson.slug}'),
      onTap: () => context.push(lessonLocation(lesson.slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 72,
                child: LessonCover(url: lesson.coverImageUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: context.cp.muted),
                  ),
                  const SizedBox(height: 4),
                  LessonMeta(lesson: lesson),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey rows while lessons load (shape of a [LessonCard]).
class LessonSkeleton extends StatelessWidget {
  const LessonSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.cp.raised,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Column(
      key: const Key('academy-skeleton'),
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(72, 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(double.infinity, 14),
                      bar(160, 12),
                      bar(100, 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
