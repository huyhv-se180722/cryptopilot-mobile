import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../../market/domain/market.dart';
import '../data/community_api.dart';
import '../../../core/media/media_picker.dart';
import '../domain/community.dart';
import 'feed_controller.dart';
import 'post_controller.dart';

enum AttachmentStatus { uploading, ready, failed }

/// A file of the post being written: kept from the post, or picked and
/// sent through the signed form (D-98).
@immutable
class Attachment {
  const Attachment({
    required this.key,
    required this.kind,
    required this.status,
    this.path,
    this.size = 0,
    this.url,
    this.publicId,
    this.progress = 0,
    this.tooLarge,
    this.failure,
  });

  final int key;
  final MediaKind kind;
  final AttachmentStatus status;

  /// The picked file on the phone and its size in bytes.
  final String? path;
  final int size;

  /// The stored file of a kept attachment (its picture).
  final String? url;
  final String? publicId;
  final double progress;

  /// Set when the file is refused (MSG32): the largest size, in bytes.
  final int? tooLarge;

  /// A refusal of the form (MSG29 for a video, MSG43).
  final ApiFailure? failure;

  Attachment copyWith({
    AttachmentStatus? status,
    String? publicId,
    double? progress,
    int? tooLarge,
    ApiFailure? failure,
    bool clearError = false,
  }) => Attachment(
    key: key,
    kind: kind,
    status: status ?? this.status,
    path: path,
    size: size,
    url: url,
    publicId: publicId ?? this.publicId,
    progress: progress ?? this.progress,
    tooLarge: clearError ? null : tooLarge ?? this.tooLarge,
    failure: clearError ? null : failure ?? this.failure,
  );
}

@immutable
class ComposerState {
  const ComposerState({
    this.loaded = true,
    this.loadFailure,
    this.title = '',
    this.content = '',
    this.market,
    this.coins = const [],
    this.sentiment,
    this.attachments = const [],
    this.submitting = false,
    this.failure,
    this.fieldErrors = const {},
  });

  /// False while an edited post is read.
  final bool loaded;
  final ApiFailure? loadFailure;
  final String title;
  final String content;
  final Market? market;
  final List<String> coins;
  final PostSentiment? sentiment;
  final List<Attachment> attachments;
  final bool submitting;
  final ApiFailure? failure;

  /// The fields the server refused (400 MSG01).
  final Set<String> fieldErrors;

  int get images => attachments.where((a) => a.kind == MediaKind.image).length;
  bool get hasVideo => attachments.any((a) => a.kind == MediaKind.video);

  /// Up to 4 images, or one video and nothing else (BR-44).
  bool get canAddImages => !hasVideo && images < PostDraft.maxImages;
  bool get canAddVideo => attachments.isEmpty;

  bool get titleValid {
    final n = title.trim().length;
    return n >= PostDraft.minTitle && n <= PostDraft.maxTitle;
  }

  bool get contentValid {
    final n = content.trim().length;
    return n >= 1 && n <= PostDraft.maxContent;
  }

  bool get uploading =>
      attachments.any((a) => a.status == AttachmentStatus.uploading);

  bool get canPublish =>
      loaded &&
      titleValid &&
      contentValid &&
      !submitting &&
      attachments.every((a) => a.status == AttachmentStatus.ready);

  ComposerState copyWith({
    bool? loaded,
    ApiFailure? loadFailure,
    String? title,
    String? content,
    Market? market,
    bool clearMarket = false,
    List<String>? coins,
    PostSentiment? sentiment,
    bool clearSentiment = false,
    List<Attachment>? attachments,
    bool? submitting,
    ApiFailure? failure,
    bool clearFailure = false,
    Set<String>? fieldErrors,
  }) => ComposerState(
    loaded: loaded ?? this.loaded,
    loadFailure: loadFailure ?? this.loadFailure,
    title: title ?? this.title,
    content: content ?? this.content,
    market: clearMarket ? null : market ?? this.market,
    coins: coins ?? this.coins,
    sentiment: clearSentiment ? null : sentiment ?? this.sentiment,
    attachments: attachments ?? this.attachments,
    submitting: submitting ?? this.submitting,
    failure: clearFailure ? null : failure ?? this.failure,
    fieldErrors: fieldErrors ?? this.fieldErrors,
  );
}

/// SCR-26 (A-66): a new post (null) or the caller's own post being edited.
final composerProvider = NotifierProvider.autoDispose
    .family<ComposerController, ComposerState, String?>(ComposerController.new);

class ComposerController extends Notifier<ComposerState> {
  ComposerController(this.postId);

  final String? postId;
  int _keys = 0;

  @override
  ComposerState build() {
    if (postId == null) return const ComposerState();
    ref.loadAfterBuild(_load);
    return const ComposerState(loaded: false);
  }

  CommunityApi get _api => ref.read(communityApiProvider);

  Future<void> _load() async {
    try {
      final post = await _api.post(postId!);
      if (!ref.mounted) return;
      state = ComposerState(
        title: post.title,
        content: post.text,
        market: post.market,
        coins: post.coins,
        sentiment: post.sentiment,
        attachments: [
          for (final m in post.media)
            Attachment(
              key: _keys++,
              kind: m.kind,
              status: AttachmentStatus.ready,
              url: m.kind == MediaKind.video ? m.thumbnailUrl : m.url,
              publicId: m.publicId,
              progress: 1,
            ),
        ],
      );
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(loadFailure: failure);
    }
  }

  Future<void> retryLoad() async {
    state = const ComposerState(loaded: false);
    await _load();
  }

  void _edit(ComposerState next) =>
      state = next.copyWith(clearFailure: true, fieldErrors: const {});

  void setTitle(String value) => _edit(state.copyWith(title: value));

  void setContent(String value) => _edit(state.copyWith(content: value));

  void setMarket(Market? market) => _edit(
    market == null
        ? state.copyWith(clearMarket: true)
        : state.copyWith(market: market),
  );

  void setSentiment(PostSentiment? sentiment) => _edit(
    sentiment == null
        ? state.copyWith(clearSentiment: true)
        : state.copyWith(sentiment: sentiment),
  );

  /// At most 5 coins; a coin again takes it off.
  void toggleCoin(String coin) {
    final coins = [...state.coins];
    if (!coins.remove(coin)) {
      if (coins.length >= PostDraft.maxCoins) return;
      coins.add(coin);
    }
    _edit(state.copyWith(coins: coins));
  }

  Future<void> addImages() async {
    if (!state.canAddImages) return;
    final files = await ref
        .read(mediaPickerProvider)
        .images(limit: PostDraft.maxImages - state.images);
    if (!ref.mounted) return;
    for (final file in files.take(PostDraft.maxImages - state.images)) {
      unawaited(_attach(file, MediaKind.image));
    }
  }

  Future<void> addVideo() async {
    if (!state.canAddVideo) return;
    final file = await ref.read(mediaPickerProvider).video();
    if (file == null || !ref.mounted || !state.canAddVideo) return;
    await _attach(file, MediaKind.video);
  }

  Future<void> _attach(PickedFile file, MediaKind kind) async {
    final attachment = Attachment(
      key: _keys++,
      kind: kind,
      status: AttachmentStatus.uploading,
      path: file.path,
      size: file.size,
    );
    state = state.copyWith(attachments: [...state.attachments, attachment]);
    await _send(attachment);
  }

  /// Sends a failed file again.
  Future<void> retry(Attachment attachment) async {
    _swap(
      attachment.copyWith(
        status: AttachmentStatus.uploading,
        progress: 0,
        clearError: true,
      ),
    );
    await _send(attachment);
  }

  Future<void> _send(Attachment attachment) async {
    final UploadForm form;
    try {
      form = await _api.uploadForm(attachment.kind);
    } on ApiFailure catch (failure) {
      _swapIfThere(
        attachment.key,
        (a) => a.copyWith(status: AttachmentStatus.failed, failure: failure),
      );
      return;
    }
    if (attachment.size > form.maxBytes) {
      _swapIfThere(
        attachment.key,
        (a) => a.copyWith(
          status: AttachmentStatus.failed,
          tooLarge: form.maxBytes,
        ),
      );
      return;
    }
    try {
      await _api.upload(
        form,
        attachment.path!,
        onProgress: (share) =>
            _swapIfThere(attachment.key, (a) => a.copyWith(progress: share)),
      );
      _swapIfThere(
        attachment.key,
        (a) => a.copyWith(
          status: AttachmentStatus.ready,
          publicId: form.publicId,
          progress: 1,
        ),
      );
    } on MediaRefused {
      _swapIfThere(
        attachment.key,
        (a) => a.copyWith(
          status: AttachmentStatus.failed,
          tooLarge: form.maxBytes,
        ),
      );
    }
  }

  void _swap(Attachment next) => _swapIfThere(next.key, (_) => next);

  /// A file removed meanwhile stays removed.
  void _swapIfThere(int key, Attachment Function(Attachment) change) {
    if (!ref.mounted) return;
    state = state.copyWith(
      attachments: [
        for (final a in state.attachments)
          if (a.key == key) change(a) else a,
      ],
    );
  }

  void remove(Attachment attachment) => state = state.copyWith(
    attachments: [
      for (final a in state.attachments)
        if (a.key != attachment.key) a,
    ],
  );

  /// The published or edited post (MSG33), or null when refused.
  Future<Post?> submit() async {
    if (!state.canPublish) return null;
    state = state.copyWith(
      submitting: true,
      clearFailure: true,
      fieldErrors: const {},
    );
    final draft = PostDraft(
      title: state.title,
      content: state.content,
      market: state.market,
      coins: state.coins,
      sentiment: state.sentiment,
      media: [
        for (final a in state.attachments)
          MediaRef(publicId: a.publicId!, kind: a.kind),
      ],
    );
    try {
      final id = postId;
      final post = id == null
          ? await _api.createPost(draft)
          : await _api.updatePost(id, draft);
      if (ref.exists(feedProvider)) {
        if (id == null) {
          unawaited(ref.read(feedProvider.notifier).load());
        } else {
          ref.read(feedProvider.notifier).replace(post);
        }
      }
      if (id != null && ref.exists(postProvider(id))) {
        unawaited(ref.read(postProvider(id).notifier).load());
      }
      if (ref.mounted) state = state.copyWith(submitting: false);
      return post;
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        submitting: false,
        failure: failure,
        fieldErrors: switch (failure) {
          ProblemFailure(:final problem) => problem.fieldErrors.keys.toSet(),
          _ => const {},
        },
      );
      return null;
    }
  }
}
