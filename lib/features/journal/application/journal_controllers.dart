import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/media/media_picker.dart';
import '../../../core/state/load_after_build.dart';
import '../data/journal_api.dart';
import '../domain/journal.dart';

@immutable
class JournalState {
  const JournalState({
    this.filter = const JournalFilter(),
    this.items,
    this.page = 0,
    this.total = 0,
    this.failure,
    this.loadingMore = false,
  });

  final JournalFilter filter;

  /// Null until the first page arrives; newest first.
  final List<JournalEntry>? items;
  final int page;
  final int total;
  final ApiFailure? failure;
  final bool loadingMore;

  bool get hasMore => items != null && items!.length < total;

  JournalState copyWith({
    List<JournalEntry>? items,
    int? page,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingMore,
  }) => JournalState(
    filter: filter,
    items: items ?? this.items,
    page: page ?? this.page,
    total: total ?? this.total,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final journalControllerProvider =
    NotifierProvider.autoDispose<JournalController, JournalState>(
      JournalController.new,
    );

/// SCR-20 (UC-22): the trades of the filter's period, 20 a page, newest
/// first; the last 30 days at first.
class JournalController extends Notifier<JournalState> {
  static const pageSize = 20;

  int _generation = 0;

  @override
  JournalState build() {
    ref.loadAfterBuild(load);
    return const JournalState();
  }

  JournalApi get _api => ref.read(journalApiProvider);

  (DateTime?, DateTime?) _period(JournalFilter filter) {
    final days = filter.days;
    if (days == null) return (null, null);
    final today = ref.read(clockProvider)().toUtc();
    return (today.subtract(Duration(days: days - 1)), today);
  }

  Future<void> load() => _loadFirst(state.filter);

  Future<void> setFilter(JournalFilter filter) {
    state = JournalState(filter: filter);
    return _loadFirst(filter);
  }

  Future<void> _loadFirst(JournalFilter filter) async {
    final generation = ++_generation;
    final (from, to) = _period(filter);
    try {
      final page = await _api.list(
        filter: filter,
        from: from,
        to: to,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      state = JournalState(
        filter: filter,
        items: page.items,
        page: 1,
        total: page.total,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final generation = _generation;
    final (from, to) = _period(state.filter);
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.list(
        filter: state.filter,
        from: from,
        to: to,
        page: state.page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final e in state.items!) e.id};
      state = state.copyWith(
        items: [
          ...state.items!,
          for (final e in page.items)
            if (!known.contains(e.id)) e,
        ],
        page: page.page,
        total: page.total,
        loadingMore: false,
        clearFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure, loadingMore: false);
    }
  }

  /// A trade left the list (deleted) or changed (reviewed).
  void changed(JournalDetail? detail, {String? removedId}) {
    final items = state.items;
    if (items == null) return;
    state = state.copyWith(
      items: [
        for (final e in items)
          if (e.id != removedId)
            detail != null && e.id == detail.entry.id ? detail.entry : e,
      ],
      total: removedId == null ? state.total : state.total - 1,
    );
  }
}

/// The strategies a review can name, read once per screen.
final strategiesProvider = FutureProvider.autoDispose<List<Strategy>>(
  (ref) => ref.read(journalApiProvider).strategies(),
);

/// Why a chart image did not reach the storage.
enum ReviewImageProblem {
  /// Larger than the form's `maxBytes` (MSG32).
  tooLarge,

  /// A format the storage does not take (MSG32).
  format,

  /// The storage refused the upload.
  refused,

  /// The signed form could not be read ([ReviewImage.failure]).
  form,
}

/// The chart image a review names (SRS 3.6.1): the stored one, or a file
/// picked on the phone and uploaded with a signed form (D-98).
@immutable
class ReviewImage {
  const ReviewImage({
    this.url,
    this.path,
    this.name,
    this.size = 0,
    this.key,
    this.progress,
    this.problem,
    this.failure,
    this.maxBytes,
  });

  /// The stored image, shown from the storage.
  final String? url;

  /// A picked file, shown from the phone until the review is saved.
  final String? path;

  /// Of [path], whose extension is checked against the form's formats.
  final String? name;

  /// In bytes, of [path].
  final int size;

  /// The storage key the review names; null until an upload finishes.
  final String? key;

  /// 0 to 1 while uploading.
  final double? progress;
  final ReviewImageProblem? problem;
  final ApiFailure? failure;

  /// The size limit the form gave, for MSG32.
  final int? maxBytes;

  bool get uploading => progress != null;

  /// Ready to be named by the review.
  bool get ready => key != null && !uploading;
}

@immutable
class JournalEntryState {
  const JournalEntryState({
    this.detail,
    this.failure,
    this.saving = false,
    this.image,
  });

  final JournalDetail? detail;
  final ApiFailure? failure;
  final bool saving;

  /// The image the review will name; null for none.
  final ReviewImage? image;

  bool get missing =>
      failure is ProblemFailure &&
      (failure! as ProblemFailure).problem.messageCode == 'MSG41';

  /// The review replaces the stored one, image included, and the detail
  /// returns only the image's address (Q-97): its key is read back from
  /// the address, and a trade whose image address has another shape keeps
  /// its review read only so the image is never lost.
  bool get reviewEditable =>
      detail != null &&
      (detail!.chartImageUrl == null ||
          chartImageKeyOf(detail!.chartImageUrl) != null);

  /// No upload running, and no picked file left without a key.
  bool get canSave =>
      reviewEditable && !saving && (image == null || image!.ready);

  JournalEntryState copyWith({
    JournalDetail? detail,
    bool? saving,
    ReviewImage? image,
    bool clearImage = false,
  }) => JournalEntryState(
    detail: detail ?? this.detail,
    saving: saving ?? this.saving,
    image: clearImage ? null : image ?? this.image,
  );
}

ReviewImage? _storedImage(JournalDetail detail) {
  final url = detail.chartImageUrl;
  return url == null ? null : ReviewImage(url: url, key: chartImageKeyOf(url));
}

final journalEntryControllerProvider = NotifierProvider.autoDispose
    .family<JournalEntryController, JournalEntryState, String>(
      JournalEntryController.new,
    );

/// SCR-21 (UC-23): the facts of a trade, read only for a SIMULATED one
/// (BR-40), and its review (MSG14 when saved); a MANUAL trade can be deleted.
class JournalEntryController extends Notifier<JournalEntryState> {
  JournalEntryController(this.id);

  final String id;

  @override
  JournalEntryState build() {
    ref.loadAfterBuild(load);
    return const JournalEntryState();
  }

  JournalApi get _api => ref.read(journalApiProvider);

  Future<void> load() async {
    try {
      final detail = await _api.entry(id);
      if (ref.mounted) {
        state = JournalEntryState(detail: detail, image: _storedImage(detail));
      }
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = JournalEntryState(detail: state.detail, failure: failure);
      }
    }
  }

  /// Picks one image and uploads it at once (SRS 3.6.1: one chart image
  /// per review); it replaces the image shown when the review is saved.
  Future<void> pickImage() async {
    if (!state.reviewEditable || (state.image?.uploading ?? false)) return;
    final files = await ref.read(mediaPickerProvider).images(limit: 1);
    if (files.isEmpty || !ref.mounted) return;
    final file = files.single;
    await _upload(file.path, file.name, file.size);
  }

  /// Uploads a picked file again after a refusal.
  Future<void> retryImage() async {
    final image = state.image;
    final path = image?.path;
    if (image == null || path == null || image.uploading) return;
    await _upload(path, image.name ?? path, image.size);
  }

  /// The review will have no image.
  void removeImage() {
    if (state.image?.uploading ?? false) return;
    state = state.copyWith(clearImage: true);
  }

  Future<void> _upload(String path, String name, int size) async {
    ReviewImage picked({
      double? progress,
      String? key,
      ReviewImageProblem? problem,
      ApiFailure? failure,
      int? maxBytes,
    }) => ReviewImage(
      path: path,
      name: name,
      size: size,
      key: key,
      progress: progress,
      problem: problem,
      failure: failure,
      maxBytes: maxBytes,
    );
    bool current() => ref.mounted && state.image?.path == path;
    state = state.copyWith(image: picked(progress: 0));
    final ChartImageForm form;
    try {
      form = await _api.chartImageForm(id);
    } on ApiFailure catch (failure) {
      if (current()) {
        state = state.copyWith(
          image: picked(problem: ReviewImageProblem.form, failure: failure),
        );
      }
      return;
    }
    if (!current()) return;
    // Checked before the upload, as the storage would refuse them.
    final problem = !form.accepts(name)
        ? ReviewImageProblem.format
        : size > form.maxBytes
        ? ReviewImageProblem.tooLarge
        : null;
    if (problem != null) {
      state = state.copyWith(
        image: picked(problem: problem, maxBytes: form.maxBytes),
      );
      return;
    }
    try {
      await _api.uploadChartImage(
        form,
        path,
        onProgress: (share) {
          if (current()) state = state.copyWith(image: picked(progress: share));
        },
      );
    } on ChartImageRefused {
      if (current()) {
        state = state.copyWith(
          image: picked(
            problem: ReviewImageProblem.refused,
            maxBytes: form.maxBytes,
          ),
        );
      }
      return;
    }
    if (current()) state = state.copyWith(image: picked(key: form.publicId));
  }

  /// Throws [ApiFailure] (MSG15 on a field, MSG32 on the image, MSG41). Not
  /// offered unless [JournalEntryState.canSave].
  Future<void> saveReview({
    String? strategyId,
    String? setupDescription,
    String? lessonsLearned,
    String? mistakes,
  }) async {
    if (!state.canSave) return;
    String? text(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    final key = state.image?.key;
    state = state.copyWith(saving: true);
    try {
      final detail = await _api.review(
        id,
        strategyId: strategyId,
        setupDescription: text(setupDescription),
        lessonsLearned: text(lessonsLearned),
        mistakes: text(mistakes),
        chartImagePublicId: key,
      );
      if (!ref.mounted) return;
      final url = detail.chartImageUrl;
      state = JournalEntryState(
        detail: detail,
        // The key just sent names the stored image.
        image: url == null ? null : ReviewImage(url: url, key: key),
      );
      if (ref.exists(journalControllerProvider)) {
        ref.read(journalControllerProvider.notifier).changed(detail);
      }
    } on ApiFailure {
      if (ref.mounted) state = state.copyWith(saving: false);
      rethrow;
    }
  }

  /// A MANUAL trade (BR-41). Throws [ApiFailure] (MSG43 on a SIMULATED one).
  Future<void> delete() async {
    await _api.delete(id);
    if (ref.exists(journalControllerProvider)) {
      ref.read(journalControllerProvider.notifier).changed(null, removedId: id);
    }
  }
}
