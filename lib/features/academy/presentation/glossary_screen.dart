import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/glossary_controller.dart';
import 'academy_widgets.dart';

/// The glossary (D-155): search, the first letters A–Z with Đ, and each term
/// with the lesson that explains it.
class GlossaryScreen extends ConsumerWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(glossaryControllerProvider);
    final controller = ref.read(glossaryControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    final groups = state.groups;

    final List<Widget> content;
    if (state.failure case final failure?) {
      content = [AcademyFailure(failure: failure, onRetry: controller.load)];
    } else if (state.terms == null) {
      content = const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (groups.isEmpty) {
      content = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            l.academyNoTerms,
            key: const Key('glossary-empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.cp.muted),
          ),
        ),
      ];
    } else {
      content = [
        for (final MapEntry(key: letter, value: terms) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(letter, style: text.titleLarge),
          ),
          for (final term in terms)
            Padding(
              key: Key('term-${term.slug}'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(term.term, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(term.definition),
                  if (term.lessonSlug case final slug?)
                    TextButton(
                      key: Key('term-lesson-${term.slug}'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => context.push(lessonLocation(slug)),
                      child: Text(l.academyReadLesson),
                    ),
                ],
              ),
            ),
        ],
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.academyGlossary)),
      body: ListView(
        key: const Key('glossary-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l.academyGlossarySubtitle,
            style: text.bodyMedium?.copyWith(color: context.cp.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('glossary-search'),
            onChanged: controller.search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l.academySearchTerms,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              key: const Key('glossary-letters'),
              scrollDirection: Axis.horizontal,
              itemCount: glossaryLetters.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, index) {
                final letter = index == 0 ? null : glossaryLetters[index - 1];
                return Center(
                  child: ChoiceChip(
                    key: Key('letter-${letter ?? 'all'}'),
                    label: Text(letter ?? l.academyAllLetters),
                    selected: state.letter == letter,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => controller.selectLetter(letter),
                  ),
                );
              },
            ),
          ),
          ...content,
          const AcademyDisclaimer(),
        ],
      ),
    );
  }
}
