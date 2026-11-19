import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/lesson_controller.dart';
import '../data/academy_progress_repository.dart';
import '../domain/academy.dart';
import 'academy_links.dart';
import 'academy_widgets.dart';
import 'markdown_view.dart';

/// A lesson page (D-155): cover and credit, the short summary, the body,
/// Mark as learned, the screen it teaches, the lessons before and after and
/// related ones.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = lessonControllerProvider(slug);
    final state = ref.watch(provider);
    final lesson = state.lesson;

    final Widget body;
    if (lesson != null) {
      body = _LessonBody(slug: slug, lesson: lesson, state: state);
    } else if (state.missing) {
      body = _Centered(
        children: [
          Text(
            l.academyNotFound,
            key: const Key('lesson-missing'),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/academy'),
            child: Text(l.academyBack),
          ),
        ],
      );
    } else if (state.failure case final failure?) {
      body = _Centered(
        children: [
          AcademyFailure(
            failure: failure,
            onRetry: ref.read(provider.notifier).load,
          ),
        ],
      );
    } else {
      body = const Center(
        key: Key('lesson-loading'),
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(lesson?.summary.topicName ?? l.academyTitle)),
      body: body,
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

class _LessonBody extends ConsumerWidget {
  const _LessonBody({
    required this.slug,
    required this.lesson,
    required this.state,
  });

  final String slug;
  final Lesson lesson;
  final LessonState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final summary = lesson.summary;
    final muted = text.bodySmall?.copyWith(color: context.cp.muted);
    return ListView(
      key: const Key('lesson-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (summary.coverImageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LessonCover(url: summary.coverImageUrl),
            ),
          ),
          if (lesson.coverCredit case final credit?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.academyPhotoCredit(credit), style: muted),
            ),
          const SizedBox(height: 12),
        ],
        Text(summary.title, style: text.headlineSmall),
        const SizedBox(height: 6),
        LessonMeta(lesson: summary),
        const SizedBox(height: 2),
        Text(l.academyUpdated(academyDate(lesson.updatedAt)), style: muted),
        const SizedBox(height: 12),
        Container(
          key: const Key('lesson-summary'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cp.raised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.academySummary, style: text.labelLarge),
              const SizedBox(height: 4),
              Text(summary.summary),
            ],
          ),
        ),
        const SizedBox(height: 8),
        MarkdownView(
          blocks: state.blocks,
          onLink: (href) => openAcademyLink(context, ref, href),
        ),
        const SizedBox(height: 8),
        _MarkButton(slug: slug, state: state),
        if (lesson.appLink case final link?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              key: const Key('lesson-try'),
              onPressed: () => openAcademyLink(context, ref, link),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l.academyTryInApp),
            ),
          ),
        const SizedBox(height: 16),
        if (lesson.previous case final previous?)
          _Neighbour(
            key: const Key('lesson-previous'),
            label: l.academyPrevious,
            link: previous,
            icon: Icons.arrow_back,
          ),
        if (lesson.next case final next?)
          _Neighbour(
            key: const Key('lesson-next'),
            label: l.academyNext,
            link: next,
            icon: Icons.arrow_forward,
          ),
        if (lesson.related.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l.academyRelated, style: text.titleMedium),
          for (final related in lesson.related) LessonCard(lesson: related),
        ],
        const AcademyDisclaimer(),
      ],
    );
  }
}

/// Mark as learned, which waits for the server; Learned and the way to
/// unmark once marked; the refusal under it.
class _MarkButton extends ConsumerWidget {
  const _MarkButton({required this.slug, required this.state});

  final String slug;
  final LessonState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final progress = ref.watch(academyProgressProvider);
    final learned = progress.learned(slug);
    final waiting =
        state.marking ||
        (progress.progress == null && progress.failure == null);
    void toggle() => ref
        .read(lessonControllerProvider(slug).notifier)
        .setLearned(learned: !learned);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (learned)
          OutlinedButton.icon(
            key: const Key('lesson-mark'),
            onPressed: waiting ? null : toggle,
            icon: Icon(Icons.check_circle, color: context.cp.positive),
            label: Text(l.academyLearned),
          )
        else
          FilledButton.icon(
            key: const Key('lesson-mark'),
            onPressed: waiting ? null : toggle,
            icon: const Icon(Icons.radio_button_unchecked),
            label: Text(l.academyMarkLearned),
          ),
        if (learned)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.academyUnmarkHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.cp.muted),
            ),
          ),
        if (state.markFailure case final failure?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              failureText(l, failure),
              key: const Key('lesson-mark-failure'),
              style: TextStyle(color: context.cp.negative),
            ),
          ),
      ],
    );
  }
}

class _Neighbour extends StatelessWidget {
  const _Neighbour({
    required this.label,
    required this.link,
    required this.icon,
    super.key,
  });

  final String label;
  final LessonLink link;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.cp.muted),
      ),
      subtitle: Text(link.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      // The next lesson replaces this one, so Back returns to the list.
      onTap: () => context.pushReplacement(lessonLocation(link.slug)),
    ),
  );
}
