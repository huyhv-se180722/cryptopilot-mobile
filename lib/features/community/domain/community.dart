import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';
import '../../market/domain/market.dart';

/// The community (SCR-24, SCR-25, SCR-27; A-64, T-133), read on backend
/// develop 03352518. Every enum refuses a value it does not know.

T _enum<T extends Enum>(List<T> values, String wire, String Function(T) of) {
  for (final value in values) {
    if (of(value) == wire) return value;
  }
  throw DecodeException('unknown value $wire');
}

/// The feed's tabs; FOLLOWING waits for follows (A-64 phase 3).
enum FeedTab {
  latest('LATEST'),
  trending('TRENDING'),
  mostLiked('MOST_LIKED'),
  saved('SAVED'),
  mine('MINE');

  const FeedTab(this.wire);

  final String wire;
}

enum PostSentiment {
  bullish('BULLISH'),
  bearish('BEARISH');

  const PostSentiment(this.wire);

  final String wire;

  static PostSentiment decode(String wire) =>
      _enum(values, wire, (v) => v.wire);
}

enum PostType {
  text('TEXT'),
  video('VIDEO');

  const PostType(this.wire);

  final String wire;
}

enum OfficialCategory {
  announcement('ANNOUNCEMENT'),
  platformUpdate('PLATFORM_UPDATE'),
  education('EDUCATION');

  const OfficialCategory(this.wire);

  final String wire;
}

/// BR-47: HIDDEN and DELETED posts are not shown to other users.
enum PostStatus {
  published('PUBLISHED'),
  hidden('HIDDEN'),
  deleted('DELETED');

  const PostStatus(this.wire);

  final String wire;
}

enum MediaKind {
  image('IMAGE'),
  video('VIDEO');

  const MediaKind(this.wire);

  final String wire;
}

/// SCR-27 (BR-46): OTHER needs a description.
enum ReportReason {
  spam('SPAM'),
  scam('SCAM'),
  abuse('ABUSE'),
  misleading('MISLEADING'),
  other('OTHER');

  const ReportReason(this.wire);

  final String wire;
}

@immutable
class Author {
  const Author({required this.userId, this.displayName, this.avatarUrl});

  final String userId;
  final String? displayName;
  final String? avatarUrl;
}

@immutable
class PostMedia {
  const PostMedia({
    required this.publicId,
    required this.kind,
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.durationSeconds,
  });

  final String publicId;
  final MediaKind kind;
  final String url;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? durationSeconds;
}

/// What a feed card and the detail share; the reactions change in place.
@immutable
class Post {
  const Post({
    required this.id,
    required this.author,
    required this.title,
    required this.text,
    required this.type,
    required this.official,
    required this.status,
    required this.coins,
    required this.media,
    required this.likeCount,
    required this.commentCount,
    required this.bullishCount,
    required this.bearishCount,
    required this.likedByMe,
    required this.savedByMe,
    required this.mine,
    required this.createdAt,
    required this.updatedAt,
    this.market,
    this.officialCategory,
    this.sentiment,
    this.myVote,
  });

  final String id;
  final Author author;
  final String title;

  /// The excerpt on a feed card, the whole content in the detail.
  final String text;
  final PostType type;
  final Market? market;
  final bool official;
  final OfficialCategory? officialCategory;
  final PostStatus status;
  final PostSentiment? sentiment;
  final List<String> coins;

  /// The cover on a feed card, every image or the video in the detail.
  final List<PostMedia> media;
  final int likeCount;
  final int commentCount;
  final int bullishCount;
  final int bearishCount;
  final PostSentiment? myVote;
  final bool likedByMe;
  final bool savedByMe;

  /// False on a feed card (the summary does not say).
  final bool mine;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Edited when its last change is a minute past its creation (web).
  bool get edited => updatedAt.difference(createdAt).inSeconds > 60;

  Post copyWith({
    bool? likedByMe,
    int? likeCount,
    bool? savedByMe,
    int? commentCount,
    Vote? vote,
  }) => Post(
    id: id,
    author: author,
    title: title,
    text: text,
    type: type,
    market: market,
    official: official,
    officialCategory: officialCategory,
    status: status,
    sentiment: sentiment,
    coins: coins,
    media: media,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    bullishCount: vote?.bullishCount ?? bullishCount,
    bearishCount: vote?.bearishCount ?? bearishCount,
    myVote: vote == null ? myVote : vote.myVote,
    likedByMe: likedByMe ?? this.likedByMe,
    savedByMe: savedByMe ?? this.savedByMe,
    mine: mine,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.deleted,
    required this.hidden,
    required this.likeCount,
    required this.likedByMe,
    required this.mine,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.replies = const [],
  });

  final String id;
  final String postId;
  final String? parentId;
  final Author author;
  final String content;
  final bool deleted;
  final bool hidden;
  final int likeCount;
  final bool likedByMe;
  final bool mine;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// One level: a reply has none.
  final List<Comment> replies;

  Comment copyWith({
    bool? likedByMe,
    int? likeCount,
    String? content,
    DateTime? updatedAt,
    List<Comment>? replies,
  }) => Comment(
    id: id,
    postId: postId,
    parentId: parentId,
    author: author,
    content: content ?? this.content,
    deleted: deleted,
    hidden: hidden,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    mine: mine,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    replies: replies ?? this.replies,
  );
}

/// A like or a save: whether it is on now and the new count.
@immutable
class Engagement {
  const Engagement({required this.active, required this.count});

  final bool active;
  final int count;
}

@immutable
class Vote {
  const Vote({
    required this.bullishCount,
    required this.bearishCount,
    this.myVote,
  });

  final PostSentiment? myVote;
  final int bullishCount;
  final int bearishCount;
}

@immutable
class CommunityPage<T> {
  const CommunityPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;
}

// Decoders.

int _int(Map<String, Object?> json, String key) => switch (json[key]) {
  final int value => value,
  _ => throw DecodeException('$key is not a whole number'),
};

int? _optionalInt(Map<String, Object?> json, String key) => switch (json[key]) {
  null => null,
  final int value => value,
  _ => throw DecodeException('$key is not a whole number'),
};

List<Object?> _list(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => const [],
      final List<Object?> list => list,
      _ => throw DecodeException('$key is not a list'),
    };

Author decodeAuthor(Object? body) {
  final json = asJsonObject(body, 'author');
  return Author(
    userId: readString(json, 'userId'),
    displayName: readOptionalString(json, 'displayName'),
    avatarUrl: readOptionalString(json, 'avatarUrl'),
  );
}

PostMedia decodeMedia(Object? body) {
  final json = asJsonObject(body, 'media');
  return PostMedia(
    publicId: readString(json, 'publicId'),
    kind: _enum(MediaKind.values, readString(json, 'mediaType'), (v) => v.wire),
    url: readString(json, 'url'),
    thumbnailUrl: readOptionalString(json, 'thumbnailUrl'),
    width: _optionalInt(json, 'width'),
    height: _optionalInt(json, 'height'),
    durationSeconds: _optionalInt(json, 'durationSeconds'),
  );
}

/// A feed card (`PostSummaryResponse`) or the detail (`PostDetailResponse`).
Post decodePost(Object? body) {
  final json = asJsonObject(body, 'post');
  final detail = json.containsKey('content');
  final market = readOptionalString(json, 'marketType');
  final category = readOptionalString(json, 'officialCategory');
  final sentiment = readOptionalString(json, 'sentiment');
  final vote = readOptionalString(json, 'myVote');
  final cover = json['cover'];
  return Post(
    id: readString(json, 'id'),
    author: decodeAuthor(json['author']),
    title: readString(json, 'title'),
    text: readOptionalString(json, detail ? 'content' : 'excerpt') ?? '',
    type: _enum(PostType.values, readString(json, 'postType'), (v) => v.wire),
    market: market == null ? null : Market.decode(market),
    official: readBool(json, 'official'),
    officialCategory: category == null
        ? null
        : _enum(OfficialCategory.values, category, (v) => v.wire),
    status: _enum(PostStatus.values, readString(json, 'status'), (v) => v.wire),
    sentiment: sentiment == null ? null : PostSentiment.decode(sentiment),
    coins: [
      for (final coin in _list(json, 'coins'))
        switch (coin) {
          final String symbol => symbol,
          _ => throw const DecodeException('coins holds a non-string'),
        },
    ],
    media: detail
        ? [for (final item in _list(json, 'media')) decodeMedia(item)]
        : [if (cover != null) decodeMedia(cover)],
    likeCount: _int(json, 'likeCount'),
    commentCount: _int(json, 'commentCount'),
    bullishCount: _int(json, 'bullishCount'),
    bearishCount: _int(json, 'bearishCount'),
    myVote: vote == null ? null : PostSentiment.decode(vote),
    likedByMe: readBool(json, 'likedByMe'),
    savedByMe: readBool(json, 'savedByMe'),
    mine: detail && readBool(json, 'mine'),
    createdAt: readInstant(json, 'createdAt'),
    updatedAt: readInstant(json, 'updatedAt'),
  );
}

Comment decodeComment(Object? body) {
  final json = asJsonObject(body, 'comment');
  return Comment(
    id: readString(json, 'id'),
    postId: readString(json, 'postId'),
    parentId: readOptionalString(json, 'parentCommentId'),
    author: decodeAuthor(json['author']),
    content: readOptionalString(json, 'content') ?? '',
    deleted: readBool(json, 'deleted'),
    hidden: readBool(json, 'hidden'),
    likeCount: _int(json, 'likeCount'),
    likedByMe: readBool(json, 'likedByMe'),
    mine: readBool(json, 'mine'),
    createdAt: readInstant(json, 'createdAt'),
    updatedAt: readInstant(json, 'updatedAt'),
    replies: [for (final reply in _list(json, 'replies')) decodeComment(reply)],
  );
}

Engagement decodeEngagement(Object? body) {
  final json = asJsonObject(body, 'engagement');
  return Engagement(
    active: readBool(json, 'active'),
    count: _int(json, 'count'),
  );
}

Vote decodeVote(Object? body) {
  final json = asJsonObject(body, 'vote');
  final mine = readOptionalString(json, 'myVote');
  return Vote(
    myVote: mine == null ? null : PostSentiment.decode(mine),
    bullishCount: _int(json, 'bullishCount'),
    bearishCount: _int(json, 'bearishCount'),
  );
}

CommunityPage<T> _page<T>(Object? body, T Function(Object?) item) {
  final json = asJsonObject(body, 'page');
  return CommunityPage(
    items: [for (final entry in _list(json, 'items')) item(entry)],
    page: _int(json, 'page'),
    pageSize: _int(json, 'pageSize'),
    total: _int(json, 'total'),
  );
}

CommunityPage<Post> decodePostPage(Object? body) => _page(body, decodePost);

CommunityPage<Comment> decodeCommentPage(Object? body) =>
    _page(body, decodeComment);

// Writing (SCR-26, A-66, T-135).

/// The signed form of `POST /media/upload-signature` (D-98): the file goes
/// straight to [uploadUrl] with these fields, then the post names
/// [publicId].
@immutable
class UploadForm {
  const UploadForm({
    required this.uploadUrl,
    required this.apiKey,
    required this.timestamp,
    required this.signature,
    required this.publicId,
    required this.allowedFormats,
    required this.overwrite,
    required this.kind,
    required this.maxBytes,
    this.maxDurationSeconds,
  });

  final String uploadUrl;
  final String apiKey;
  final int timestamp;
  final String signature;
  final String publicId;
  final List<String> allowedFormats;
  final bool overwrite;
  final MediaKind kind;
  final int maxBytes;
  final int? maxDurationSeconds;
}

/// A file a post names: kept from the post or uploaded for it.
@immutable
class MediaRef {
  const MediaRef({required this.publicId, required this.kind});

  final String publicId;
  final MediaKind kind;

  Map<String, Object?> toJson() => {
    'publicId': publicId,
    'mediaType': kind.wire,
  };
}

/// What `POST /posts` and `PUT /posts/{id}` take (SRS 3.7.2): a title of
/// 5 to 150 characters, up to 10,000 of content, up to 5 coins, up to 4
/// images or one video (BR-44).
@immutable
class PostDraft {
  const PostDraft({
    required this.title,
    required this.content,
    this.market,
    this.coins = const [],
    this.media = const [],
    this.sentiment,
  });

  static const minTitle = 5;
  static const maxTitle = 150;
  static const maxContent = 10000;
  static const maxCoins = 5;
  static const maxImages = 4;

  final String title;
  final String content;
  final Market? market;
  final List<String> coins;
  final List<MediaRef> media;
  final PostSentiment? sentiment;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'content': content.trim(),
    'marketType': ?market?.wire,
    'coins': coins,
    'media': [for (final m in media) m.toJson()],
    'sentiment': ?sentiment?.wire,
  };
}

UploadForm decodeUploadForm(Object? body) {
  final json = asJsonObject(body, 'upload form');
  final url = readString(json, 'uploadUrl');
  if (!url.startsWith('https://')) {
    throw const DecodeException('uploadUrl must be https');
  }
  return UploadForm(
    uploadUrl: url,
    apiKey: readString(json, 'apiKey'),
    timestamp: _int(json, 'timestamp'),
    signature: readString(json, 'signature'),
    publicId: readString(json, 'publicId'),
    allowedFormats: [
      for (final f in _list(json, 'allowedFormats'))
        switch (f) {
          final String format => format,
          _ => throw const DecodeException('allowedFormats holds a non-string'),
        },
    ],
    overwrite: readBool(json, 'overwrite'),
    kind: _enum(MediaKind.values, readString(json, 'mediaType'), (v) => v.wire),
    maxBytes: _int(json, 'maxBytes'),
    maxDurationSeconds: _optionalInt(json, 'maxDurationSeconds'),
  );
}
