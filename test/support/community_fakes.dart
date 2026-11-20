import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/core/media/media_picker.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';

final communityNow = DateTime.utc(2026, 11, 20, 3);

class FakeMediaPicker implements MediaPicker {
  List<PickedFile> nextImages = const [
    PickedFile(path: '/tmp/a.png', name: 'a.png', size: 1000),
    PickedFile(path: '/tmp/b.png', name: 'b.png', size: 2000),
  ];
  PickedFile? nextVideo = const PickedFile(
    path: '/tmp/v.mp4',
    name: 'v.mp4',
    size: 5000,
  );
  final List<int> limits = [];

  @override
  Future<List<PickedFile>> images({required int limit}) async {
    limits.add(limit);
    return nextImages.take(limit).toList();
  }

  @override
  Future<PickedFile?> video() async => nextVideo;
}

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
    String? author,
    int page = 1,
    int pageSize = 20,
  }) async {
    final name =
        'feed ${tab.wire} coin=$coin market=${market?.wire} q=$query p=$page'
        '${author == null ? '' : ' author=$author'}';
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
    List<String> mentions = const [],
  }) async {
    calls.add(
      'add $postId "$content" parent=$parentId'
      '${mentions.isEmpty ? '' : ' mentions=${mentions.join(',')}'}',
    );
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

  // Writing (T-135).

  int _uploads = 0;
  final List<PostDraft> drafts = [];

  /// Files [upload] refuses, by path.
  final Set<String> refusePaths = {};

  @override
  Future<UploadForm> uploadForm(MediaKind kind) async {
    calls.add('form ${kind.wire}');
    _maybeFail('form');
    _uploads++;
    return UploadForm(
      uploadUrl: 'https://storage.test/upload',
      apiKey: 'key',
      timestamp: 1763600000,
      signature: 'sig',
      publicId: 'posts/u-me/m$_uploads',
      allowedFormats: kind == MediaKind.image
          ? const ['jpg', 'png', 'webp']
          : const ['mp4', 'webm'],
      overwrite: false,
      kind: kind,
      maxBytes: kind == MediaKind.image ? 10 * 1024 * 1024 : 100 * 1024 * 1024,
      maxDurationSeconds: kind == MediaKind.video ? 120 : null,
    );
  }

  @override
  Future<void> upload(
    UploadForm form,
    String path, {
    void Function(double share)? onProgress,
  }) async {
    calls.add('upload ${form.publicId} $path');
    onProgress?.call(0.5);
    if (refusePaths.contains(path)) throw const MediaRefused();
    onProgress?.call(1);
  }

  @override
  Future<Post> createPost(PostDraft draft) async {
    calls.add('create "${draft.title}" media=${draft.media.length}');
    _maybeFail('create');
    drafts.add(draft);
    return postOf(
      'new-post',
      title: draft.title,
      text: draft.content,
      mine: true,
    );
  }

  @override
  Future<Post> updatePost(String id, PostDraft draft) async {
    calls.add('update $id "${draft.title}" media=${draft.media.length}');
    _maybeFail('update');
    drafts.add(draft);
    return postOf(id, title: draft.title, text: draft.content, mine: true);
  }

  // Members (T-136).

  Map<String, MemberProfile> members = {};
  List<MemberComment> memberCommentItems = [];
  List<Author> people = [
    const Author(userId: 'u-An', displayName: 'An'),
    const Author(userId: 'u-Bao', displayName: 'Bao'),
  ];

  @override
  Future<MemberProfile> member(String id) async {
    calls.add('member $id');
    _maybeFail('member');
    return members[id] ?? memberOf(id);
  }

  @override
  Future<Engagement> follow(String id, {required bool on}) async {
    calls.add('follow $id $on');
    _maybeFail('follow');
    final m = members[id] ?? memberOf(id);
    return Engagement(active: on, count: m.followers + (on ? 1 : -1));
  }

  @override
  Future<Engagement> block(String id, {required bool on}) async {
    calls.add('block $id $on');
    _maybeFail('block');
    return Engagement(active: on, count: on ? 1 : 0);
  }

  @override
  Future<List<TokenMention>> tokenMentions(String id, {int limit = 10}) async {
    calls.add('mentions $id');
    return const [
      TokenMention(
        symbol: 'BTC',
        name: 'Bitcoin',
        posts: 6,
        sharePercent: 60,
        bullishPosts: 4,
        bearishPosts: 1,
      ),
    ];
  }

  @override
  Future<CommunityPage<MemberComment>> memberComments(
    String id, {
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('member comments $id p=$page');
    return CommunityPage(
      items: memberCommentItems,
      page: page,
      pageSize: pageSize,
      total: memberCommentItems.length,
    );
  }

  @override
  Future<CommunityPage<Post>> memberReactions(
    String id, {
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('member reactions $id p=$page');
    return CommunityPage(
      items: feedItems,
      page: page,
      pageSize: pageSize,
      total: feedItems.length,
    );
  }

  CommunityPage<Author> _people(int page, int pageSize) => CommunityPage(
    items: people,
    page: page,
    pageSize: pageSize,
    total: people.length,
  );

  @override
  Future<CommunityPage<Author>> followers(
    String id, {
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('followers $id');
    return _people(page, pageSize);
  }

  @override
  Future<CommunityPage<Author>> followingOf(
    String id, {
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('following $id');
    return _people(page, pageSize);
  }

  @override
  Future<CommunityPage<Author>> blocked({
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('blocked');
    return _people(page, pageSize);
  }

  @override
  Future<List<Author>> searchMembers(String query) async {
    calls.add('search members $query');
    return [
      for (final p in people)
        if ((p.displayName ?? '').toLowerCase().contains(query.toLowerCase()))
          p,
    ];
  }
}

MemberProfile memberOf(
  String id, {
  String name = 'Minh Tran',
  bool me = false,
  bool following = false,
  bool blocked = false,
  int followers = 12,
}) => MemberProfile(
  author: Author(userId: id, displayName: name),
  joinedAt: DateTime.utc(2026, 10, 1),
  posts: 8,
  likesReceived: 40,
  followers: followers,
  following: 3,
  followedByMe: following,
  blockedByMe: blocked,
  me: me,
  influenceScore: 72.5,
  depthScore: 64,
  bio: 'Swing trader, BTC and ETH.',
);
