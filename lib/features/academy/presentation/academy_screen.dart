import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/academy_controller.dart';
import '../data/academy_progress_repository.dart';
import '../domain/academy.dart';
import 'academy_widgets.dart';

/// The Academy (D-155): the Trader's progress, the beginner path, the way
/// to the glossary, and the lessons by topic, level and search, read page
/// after page as the list scrolls. Labels in Vietnamese, as on the web.
class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(academyControllerProvider);
    final controller = ref.read(academyControllerProvider.notifier);
    final lessons = state.lessons;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.academyTitle),
        actions: [
          IconButton(
            key: const Key('open-glossary'),
            tooltip: l.academyGlossary,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/academy/glossary'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          controller.load(),
          ref.read(academyProgressProvider.notifier).load(),
        ]),
        child: NotificationListener<ScrollNotification>(
          onNotification: (note) {
            if (note.metrics.extentAfter < 400) controller.loadMore();
            return false;
          },
          child: CustomScrollView(
            key: const Key('academy-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.list(
                  children: [
                    Text(
                      l.academySubtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: context.cp.muted),
                    ),
                    const SizedBox(height: 12),
                    const _ProgressCard(),
                    if (state.path case final path? when path.isNotEmpty)
                      _PathStrip(path: path),
                    _GlossaryTeaser(
                      onOpen: () => context.push('/academy/glossary'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.academyLessons,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('academy-search'),
                      onChanged: controller.search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: l.academySearch,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Chips(
                      children: [
                        _Chip(
                          key: const Key('topic-all'),
                          label: l.academyAllTopics,
                          selected: state.topic == null,
                          onTap: () => controller.selectTopic(null),
                        ),
                        for (final topic in state.topics ?? <AcademyTopic>[])
                          _Chip(
                            key: Key('topic-${topic.slug}'),
                            label: topic.name,
                            selected: state.topic == topic.slug,
                            onTap: () => controller.selectTopic(topic.slug),
                          ),
                      ],
                    ),
                    _Chips(
                      children: [
                        _Chip(
                          key: const Key('level-all'),
                          label: l.academyAllLevels,
                          selected: state.level == null,
                          onTap: () => controller.selectLevel(null),
                        ),
                        for (final level in LessonLevel.values)
                          _Chip(
                            key: Key('level-${level.wire}'),
                            label: levelLabel(l, level),
                            selected: state.level == level,
                            onTap: () => controller.selectLevel(level),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: switch ((lessons, state.failure)) {
                  (null, final failure?) => SliverToBoxAdapter(
                    child: AcademyFailure(
                      failure: failure,
                      onRetry: controller.load,
                    ),
                  ),
                  (null, _) => const SliverToBoxAdapter(
                    child: LessonSkeleton(),
                  ),
                  (final list?, _) when list.isEmpty => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        l.academyNoLessons,
                        key: const Key('academy-empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.cp.muted),
                      ),
                    ),
                  ),
                  (final list?, _) => SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (_, index) => LessonCard(lesson: list[index]),
                  ),
                },
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.list(
                  children: [
                    if (state.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const AcademyDisclaimer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The beginner path progress and how many lessons were read.
class _ProgressCard extends ConsumerWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final progress = ref.watch(
      academyProgressProvider.select((s) => s.progress),
    );
    if (progress == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('academy-progress'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.academyPathProgress(progress.pathCompleted, progress.pathTotal),
              style: text.titleSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.pathTotal == 0
                  ? 0
                  : progress.pathCompleted / progress.pathTotal,
            ),
            const SizedBox(height: 8),
            Text(
              l.academyReadProgress(
                progress.completed.length,
                progress.publishedTotal,
              ),
              style: text.bodySmall?.copyWith(color: context.cp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The beginner path in order, side by side.
class _PathStrip extends ConsumerWidget {
  const _PathStrip({required this.path});

  final List<LessonSummary> path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.academyPathTitle, style: text.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            key: const Key('academy-path'),
            scrollDirection: Axis.horizontal,
            itemCount: path.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final lesson = path[index];
              final learned = ref.watch(
                academyProgressProvider.select((s) => s.learned(lesson.slug)),
              );
              return SizedBox(
                width: 200,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    key: Key('path-${lesson.slug}'),
                    onTap: () => context.push(lessonLocation(lesson.slug)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: learned
                                    ? context.cp.positive
                                    : context.cp.raised,
                                child: learned
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        '${lesson.pathOrder ?? index + 1}',
                                        style: text.labelSmall,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.academyReadingTime(lesson.readingMinutes),
                                  style: text.bodySmall?.copyWith(
                                    color: context.cp.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lesson.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _GlossaryTeaser extends StatelessWidget {
  const _GlossaryTeaser({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: const Key('glossary-teaser'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(l.academyGlossaryTeaser),
      subtitle: Text(l.academyOpenGlossary),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpen,
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => Center(child: children[index]),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}
