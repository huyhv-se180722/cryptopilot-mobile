import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/http/http_providers.dart';
import '../../market/domain/market.dart';
import '../domain/community.dart';

/// The community of SCR-24, SCR-25 and SCR-27 (A-64, T-133; read on
/// backend develop 03352518). Pages start at 1, 20 items unless asked,
/// at most 100. A post or comment the caller may not see is 404 MSG41
/// (BR-47).
abstract interface class CommunityApi {
  /// The feed of [tab]; [query] is 2 to 100 characters.
  Future<CommunityPage<Post>> feed({
    FeedTab tab = FeedTab.latest,
    String? coin,
    Market? market,
    String? query,
    int page = 1,
    int pageSize = 20,
  });

  /// Official posts, pinned on top of the feed (BR-61).
  Future<CommunityPage<Post>> pinned({int page = 1, int pageSize = 3});

  Future<Post> post(String id);

  /// A soft delete of the caller's own post (BR-47).
  Future<void> deletePost(String id);

  /// Threads oldest first, each with its replies.
  Future<CommunityPage<Comment>> comments(
    String postId, {
    int page = 1,
    int pageSize = 20,
  });

  /// 1 to 2,000 characters; [parentId] makes it a reply (400 MSG01).
  Future<Comment> addComment(String postId, String content, {String? parentId});

  Future<Comment> editComment(String id, String content);

  Future<void> deleteComment(String id);

  Future<Engagement> likePost(String id, {required bool like});

  Future<Engagement> savePost(String id, {required bool save});

  Future<Engagement> likeComment(String id, {required bool like});

  /// Bullish or Bearish, replacing an earlier vote; null takes it back
  /// (D-125).
  Future<Vote> vote(String id, PostSentiment? sentiment);

  /// 201 MSG34; 409 `POST_ALREADY_REPORTED` (BR-46) or
  /// `POST_REPORT_OWN_POST`; 400 MSG01 for OTHER without [description].
  Future<void> reportPost(
    String id,
    ReportReason reason, {
    String? description,
  });

  /// As [reportPost], with `COMMENT_ALREADY_REPORTED`.
  Future<void> reportComment(
    String id,
    ReportReason reason, {
    String? description,
  });
}

class DioCommunityApi implements CommunityApi {
  const DioCommunityApi(this._dio);

  final Dio _dio;

  static String _post(String id) => 'posts/${Uri.encodeComponent(id)}';

  static String _comment(String id) => 'comments/${Uri.encodeComponent(id)}';

  @override
  Future<CommunityPage<Post>> feed({
    FeedTab tab = FeedTab.latest,
    String? coin,
    Market? market,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      'posts',
      queryParameters: {
        'tab': tab.wire,
        'coin': ?coin,
        'market': ?market?.wire,
        'q': ?query,
        'page': page,
        'pageSize': pageSize,
      },
    ),
    decodePostPage,
  );

  @override
  Future<CommunityPage<Post>> pinned({int page = 1, int pageSize = 3}) =>
      apiCall(
        () => _dio.get<Object?>(
          'posts/pinned',
          queryParameters: {'page': page, 'pageSize': pageSize},
        ),
        decodePostPage,
      );

  @override
  Future<Post> post(String id) =>
      apiCall(() => _dio.get<Object?>(_post(id)), decodePost);

  @override
  Future<void> deletePost(String id) =>
      apiCall(() => _dio.delete<Object?>(_post(id)), (_) {});

  @override
  Future<CommunityPage<Comment>> comments(
    String postId, {
    int page = 1,
    int pageSize = 20,
  }) => apiCall(
    () => _dio.get<Object?>(
      '${_post(postId)}/comments',
      queryParameters: {'page': page, 'pageSize': pageSize},
    ),
    decodeCommentPage,
  );

  @override
  Future<Comment> addComment(
    String postId,
    String content, {
    String? parentId,
  }) => apiCall(
    () => _dio.post<Object?>(
      '${_post(postId)}/comments',
      data: {'content': content, 'parentCommentId': ?parentId},
    ),
    decodeComment,
  );

  @override
  Future<Comment> editComment(String id, String content) => apiCall(
    () => _dio.put<Object?>(_comment(id), data: {'content': content}),
    decodeComment,
  );

  @override
  Future<void> deleteComment(String id) =>
      apiCall(() => _dio.delete<Object?>(_comment(id)), (_) {});

  Future<Engagement> _toggle(String path, {required bool on}) => apiCall(
    () => on ? _dio.post<Object?>(path) : _dio.delete<Object?>(path),
    decodeEngagement,
  );

  @override
  Future<Engagement> likePost(String id, {required bool like}) =>
      _toggle('${_post(id)}/like', on: like);

  @override
  Future<Engagement> savePost(String id, {required bool save}) =>
      _toggle('${_post(id)}/save', on: save);

  @override
  Future<Engagement> likeComment(String id, {required bool like}) =>
      _toggle('${_comment(id)}/like', on: like);

  @override
  Future<Vote> vote(String id, PostSentiment? sentiment) => apiCall(
    () => sentiment == null
        ? _dio.delete<Object?>('${_post(id)}/vote')
        : _dio.put<Object?>(
            '${_post(id)}/vote',
            data: {'sentiment': sentiment.wire},
          ),
    decodeVote,
  );

  Future<void> _report(String path, ReportReason reason, String? text) =>
      apiCall(
        () => _dio.post<Object?>(
          path,
          data: {'reason': reason.wire, 'description': ?text},
        ),
        (_) {},
      );

  @override
  Future<void> reportPost(
    String id,
    ReportReason reason, {
    String? description,
  }) => _report('${_post(id)}/reports', reason, description);

  @override
  Future<void> reportComment(
    String id,
    ReportReason reason, {
    String? description,
  }) => _report('${_comment(id)}/reports', reason, description);
}

final communityApiProvider = Provider<CommunityApi>(
  (ref) => DioCommunityApi(ref.watch(apiDioProvider)),
);
