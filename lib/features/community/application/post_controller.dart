import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/state/load_after_build.dart';
import '../data/community_api.dart';
import '../domain/community.dart';
import 'feed_controller.dart';

@immutable
class PostState {
  const PostState({
    this.post,
    this.failure,
    this.comments,
    this.more = false,
    this.commentsFailure,
    this.loadingMore = false,
  });

  /// Null until it arrives.
  final Post? post;
  final ApiFailure? failure;

  /// Threads oldest first, null until the first page arrives.
  final List<Comment>? comments;
  final bool more;
  final ApiFailure? commentsFailure;
  final bool loadingMore;

  /// Hidden, deleted or never there for the caller (404 MSG41, BR-47).
  bool get missing =>
      post == null &&
      switch (failure) {
        ProblemFailure(:final problem) => problem.messageCode == 'MSG41',
        _ => false,
      };

  PostState copyWith({
    Post? post,
    ApiFailure? failure,
    bool clearFailure = false,
    List<Comment>? comments,
    bool? more,
    ApiFailure? commentsFailure,
    bool clearCommentsFailure = false,
    bool? loadingMore,
  }) => PostState(
    post: post ?? this.post,
    failure: clearFailure ? null : failure ?? this.failure,
    comments: comments ?? this.comments,
    more: more ?? this.more,
    commentsFailure: clearCommentsFailure
        ? null
        : commentsFailure ?? this.commentsFailure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// What a report came to (SCR-27).
enum ReportOutcome {
  /// MSG34.
  submitted,

  /// `POST_ALREADY_REPORTED` / `COMMENT_ALREADY_REPORTED` (BR-46).
  alreadyReported,
}

final postProvider = NotifierProvider.autoDispose
    .family<PostController, PostState, String>(PostController.new);

/// SCR-25: a post, its comments and what the Trader does with them; the
/// feed card follows every change.
class PostController extends Notifier<PostState> {
  PostController(this.id);

  static const pageSize = 20;
  static const maxComment = 2000;

  final String id;
  int _generation = 0;
  int _page = 0;

  @override
  PostState build() {
    ref.loadAfterBuild(load);
    return const PostState();
  }

  CommunityApi get _api => ref.read(communityApiProvider);

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final post = await _api.post(id);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(post: post, clearFailure: true);
      _syncFeed(post);
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
      return;
    }
    await loadComments();
  }

  /// The first page again, as many threads as were shown.
  Future<void> loadComments() async {
    final generation = _generation;
    final shown = state.comments?.length ?? 0;
    final size = shown <= pageSize ? pageSize : (shown > 100 ? 100 : shown);
    try {
      final page = await _api.comments(id, pageSize: size);
      if (!ref.mounted || generation != _generation) return;
      // The next page of [pageSize] after what is shown; seen ones are
      // skipped.
      _page = size ~/ pageSize;
      state = state.copyWith(
        comments: page.items,
        more: page.hasMore,
        clearCommentsFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(commentsFailure: failure);
    }
  }

  Future<void> loadMoreComments() async {
    if (!state.more || state.loadingMore || state.comments == null) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.comments(id, page: _page + 1, pageSize: pageSize);
      if (!ref.mounted || generation != _generation) return;
      _page += 1;
      final known = {for (final c in state.comments!) c.id};
      state = state.copyWith(
        comments: [
          ...state.comments!,
          for (final c in page.items)
            if (!known.contains(c.id)) c,
        ],
        more: page.hasMore,
        loadingMore: false,
      );
    } on ApiFailure {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  void _syncFeed(Post post) {
    if (ref.exists(feedProvider)) {
      ref.read(feedProvider.notifier).replace(post);
    }
  }

  void _setPost(Post post) {
    state = state.copyWith(post: post);
    _syncFeed(post);
  }

  Future<ApiFailure?> toggleLike() async {
    final post = state.post;
    if (post == null) return null;
    _setPost(
      post.copyWith(
        likedByMe: !post.likedByMe,
        likeCount: post.likeCount + (post.likedByMe ? -1 : 1),
      ),
    );
    try {
      final e = await _api.likePost(id, like: !post.likedByMe);
      if (ref.mounted) {
        _setPost(state.post!.copyWith(likedByMe: e.active, likeCount: e.count));
      }
      return null;
    } on ApiFailure catch (failure) {
      if (ref.mounted) _setPost(post);
      return failure;
    }
  }

  Future<ApiFailure?> toggleSave() async {
    final post = state.post;
    if (post == null) return null;
    _setPost(post.copyWith(savedByMe: !post.savedByMe));
    try {
      final e = await _api.savePost(id, save: !post.savedByMe);
      if (ref.mounted) _setPost(state.post!.copyWith(savedByMe: e.active));
      return null;
    } on ApiFailure catch (failure) {
      if (ref.mounted) _setPost(post);
      return failure;
    }
  }

  /// [sentiment] again takes the vote back (D-125).
  Future<ApiFailure?> vote(PostSentiment sentiment) async {
    final post = state.post;
    if (post == null) return null;
    try {
      final vote = await _api.vote(
        id,
        post.myVote == sentiment ? null : sentiment,
      );
      if (ref.mounted) _setPost(state.post!.copyWith(vote: vote));
      return null;
    } on ApiFailure catch (failure) {
      return failure;
    }
  }

  /// A new thread, or a reply to [parentId]; null when added.
  /// Up to 10 [mentions] are told (T-136).
  Future<ApiFailure?> addComment(
    String text, {
    String? parentId,
    List<String> mentions = const [],
  }) async {
    final content = text.trim();
    if (content.isEmpty || content.length > maxComment) return null;
    try {
      final comment = await _api.addComment(
        id,
        content,
        parentId: parentId,
        mentions: mentions.take(10).toList(),
      );
      if (!ref.mounted) return null;
      final comments = state.comments ?? const <Comment>[];
      state = state.copyWith(
        comments: parentId == null
            ? [...comments, comment]
            : [
                for (final c in comments)
                  c.id == parentId
                      ? c.copyWith(replies: [...c.replies, comment])
                      : c,
              ],
      );
      final post = state.post;
      if (post != null) {
        _setPost(post.copyWith(commentCount: post.commentCount + 1));
      }
      return null;
    } on ApiFailure catch (failure) {
      return failure;
    }
  }

  Future<ApiFailure?> editComment(Comment comment, String text) async {
    final content = text.trim();
    if (content.isEmpty || content.length > maxComment) return null;
    try {
      final edited = await _api.editComment(comment.id, content);
      if (ref.mounted) _swapComment(edited.copyWith(replies: comment.replies));
      return null;
    } on ApiFailure catch (failure) {
      return failure;
    }
  }

  /// A thread with replies stays as "Comment deleted": read them again.
  Future<ApiFailure?> deleteComment(Comment comment) async {
    try {
      await _api.deleteComment(comment.id);
      if (!ref.mounted) return null;
      final post = state.post;
      if (post != null && post.commentCount > 0) {
        _setPost(post.copyWith(commentCount: post.commentCount - 1));
      }
      await loadComments();
      return null;
    } on ApiFailure catch (failure) {
      return failure;
    }
  }

  Future<ApiFailure?> toggleCommentLike(Comment comment) async {
    _swapComment(
      comment.copyWith(
        likedByMe: !comment.likedByMe,
        likeCount: comment.likeCount + (comment.likedByMe ? -1 : 1),
      ),
    );
    try {
      final e = await _api.likeComment(comment.id, like: !comment.likedByMe);
      if (ref.mounted) {
        _swapComment(comment.copyWith(likedByMe: e.active, likeCount: e.count));
      }
      return null;
    } on ApiFailure catch (failure) {
      if (ref.mounted) _swapComment(comment);
      return failure;
    }
  }

  void _swapComment(Comment next) {
    final comments = state.comments;
    if (comments == null) return;
    Comment swap(Comment c) => c.id == next.id
        ? next
        : c.replies.any((r) => r.id == next.id)
        ? c.copyWith(replies: [for (final r in c.replies) swap(r)])
        : c;
    state = state.copyWith(comments: [for (final c in comments) swap(c)]);
  }

  /// The caller's own post (BR-47); it leaves the feed.
  Future<ApiFailure?> deletePost() async {
    try {
      await _api.deletePost(id);
      if (ref.exists(feedProvider)) ref.read(feedProvider.notifier).remove(id);
      return null;
    } on ApiFailure catch (failure) {
      return failure;
    }
  }

  /// SCR-27 for the post, or for [comment] when given.
  Future<ReportOutcome> report(
    ReportReason reason, {
    String? description,
    Comment? comment,
  }) async {
    final text = description?.trim();
    final details = text == null || text.isEmpty ? null : text;
    try {
      if (comment == null) {
        await _api.reportPost(id, reason, description: details);
      } else {
        await _api.reportComment(comment.id, reason, description: details);
      }
      return ReportOutcome.submitted;
    } on ProblemFailure catch (failure) {
      if (failure.code == 'POST_ALREADY_REPORTED' ||
          failure.code == 'COMMENT_ALREADY_REPORTED') {
        return ReportOutcome.alreadyReported;
      }
      rethrow;
    }
  }
}
