import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';

final communityNow = DateTime.utc(2026, 11, 20, 3);

Post postOf(
  String id, {
  String title = 'BTC holds 76k',
  String text = 'Support held twice.\nWatching 78k.',
  String author = 'Minh Tran',
  bool official = false,
  bool mine = false,
  bool liked = false,
  bool saved = false,
  int likes = 12,
  int comments = 4,
  PostSentiment? myVote,
  List<String> coins = const ['BTC'],
  List<PostMedia> media = const [],
  Market? market = Market.spot,
  Duration age = const Duration(hours: 2),
}) => Post(
  id: id,
  author: Author(userId: 'u-$author', displayName: author),
  title: title,
  text: text,
  type: media.any((m) => m.kind == MediaKind.video)
      ? PostType.video
      : PostType.text,
  market: market,
  official: official,
  officialCategory: official ? OfficialCategory.announcement : null,
  status: PostStatus.published,
  coins: coins,
  media: media,
  likeCount: likes,
  commentCount: comments,
  bullishCount: 8,
  bearishCount: 3,
  myVote: myVote,
  likedByMe: liked,
  savedByMe: saved,
  mine: mine,
  createdAt: communityNow.subtract(age),
  updatedAt: communityNow.subtract(age),
);

Comment commentOf(
  String id, {
  String content = 'Agree',
  String author = 'An',
  String? parentId,
  bool mine = false,
  bool deleted = false,
  List<Comment> replies = const [],
}) => Comment(
  id: id,
  postId: 'p1',
  parentId: parentId,
  author: Author(userId: 'u-$author', displayName: author),
  content: deleted ? '' : content,
  deleted: deleted,
  hidden: false,
  likeCount: 2,
  likedByMe: false,
  mine: mine,
  createdAt: communityNow.subtract(const Duration(hours: 1)),
  updatedAt: communityNow.subtract(const Duration(hours: 1)),
  replies: replies,
);

class FakeCommunityApi implements CommunityApi {
  final List<String> calls = [];

  List<Post> feedItems = [postOf('p1'), postOf('p2', title: 'ETH lagging')];
  List<Post> pinnedItems = [];
  int feedTotal = -1;
  Map<String, Post> posts = {};
  List<Comment> commentItems = [
    commentOf(
      'c1',
      replies: [commentOf('r1', author: 'Bao', parentId: 'c1')],
    ),
    commentOf('c2', author: 'Chi', mine: true),
  ];
  int commentTotal = -1;

  /// Thrown by the next call whose name starts with the key.
  final Map<String, Object> failNext = {};

  /// Thrown by every call whose name starts with the key.
  final Map<String, Object> failAlways = {};

  void _maybeFail(String name) {
    for (final entry in failAlways.entries) {
      if (name.startsWith(entry.key)) throw entry.value;
    }
    for (final key in failNext.keys.toList()) {
      if (name.startsWith(key)) throw failNext.remove(key)!;
    }
  }

  @override
  Future<CommunityPage<Post>> feed({
    FeedTab tab = FeedTab.latest,
    String? coin,
    Market? market,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final name =
        'feed ${tab.wire} coin=$coin market=${market?.wire} q=$query p=$page';
    calls.add(name);
    _maybeFail('feed');
    final start = (page - 1) * pageSize;
    final items = feedItems.skip(start).take(pageSize).toList();
    return CommunityPage(
      items: items,
      page: page,
      pageSize: pageSize,
      total: feedTotal < 0 ? feedItems.length : feedTotal,
    );
  }

  @override
  Future<CommunityPage<Post>> pinned({int page = 1, int pageSize = 3}) async {
    calls.add('pinned');
    _maybeFail('pinned');
    return CommunityPage(
      items: pinnedItems,
      page: page,
      pageSize: pageSize,
      total: pinnedItems.length,
    );
  }

  @override
  Future<Post> post(String id) async {
    calls.add('post $id');
    _maybeFail('post');
    return posts[id] ??
        feedItems.firstWhere((p) => p.id == id, orElse: () => postOf(id));
  }

  @override
  Future<void> deletePost(String id) async {
    calls.add('delete post $id');
    _maybeFail('delete post');
  }

  @override
  Future<CommunityPage<Comment>> comments(
    String postId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('comments $postId p=$page size=$pageSize');
    _maybeFail('comments');
    final start = (page - 1) * pageSize;
    return CommunityPage(
      items: commentItems.skip(start).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: commentTotal < 0 ? commentItems.length : commentTotal,
    );
  }

  @override
  Future<Comment> addComment(
    String postId,
    String content, {
    String? parentId,
  }) async {
    calls.add('add $postId "$content" parent=$parentId');
    _maybeFail('add');
    return commentOf(
      'new-${calls.length}',
      content: content,
      author: 'Me',
      parentId: parentId,
      mine: true,
    );
  }

  @override
  Future<Comment> editComment(String id, String content) async {
    calls.add('edit $id "$content"');
    _maybeFail('edit');
    return commentOf(id, content: content, author: 'Chi', mine: true);
  }

  @override
  Future<void> deleteComment(String id) async {
    calls.add('delete comment $id');
    _maybeFail('delete comment');
  }

  @override
  Future<Engagement> likePost(String id, {required bool like}) async {
    calls.add('like $id $like');
    _maybeFail('like');
    final post = feedItems.firstWhere(
      (p) => p.id == id,
      orElse: () => postOf(id),
    );
    return Engagement(
      active: like,
      count: post.likeCount + (like ? 1 : 0) - (post.likedByMe ? 1 : 0),
    );
  }

  @override
  Future<Engagement> savePost(String id, {required bool save}) async {
    calls.add('save $id $save');
    _maybeFail('save');
    return Engagement(active: save, count: save ? 1 : 0);
  }

  @override
  Future<Engagement> likeComment(String id, {required bool like}) async {
    calls.add('like comment $id $like');
    _maybeFail('like comment');
    return Engagement(active: like, count: like ? 3 : 2);
  }

  @override
  Future<Vote> vote(String id, PostSentiment? sentiment) async {
    calls.add('vote $id ${sentiment?.wire}');
    _maybeFail('vote');
    return Vote(
      myVote: sentiment,
      bullishCount: sentiment == PostSentiment.bullish ? 9 : 8,
      bearishCount: sentiment == PostSentiment.bearish ? 4 : 3,
    );
  }

  @override
  Future<void> reportPost(
    String id,
    ReportReason reason, {
    String? description,
  }) async {
    calls.add('report post $id ${reason.wire} $description');
    _maybeFail('report');
  }

  @override
  Future<void> reportComment(
    String id,
    ReportReason reason, {
    String? description,
  }) async {
    calls.add('report comment $id ${reason.wire} $description');
    _maybeFail('report');
  }
}
