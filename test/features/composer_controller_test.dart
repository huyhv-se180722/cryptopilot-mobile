import 'package:cryptopilot_mobile/features/community/application/composer_controller.dart';
import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/features/community/data/media_picker.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/community_fakes.dart';
import '../support/fakes.dart';

/// T-135: writing and editing a post (SCR-26, A-66).
void main() {
  late FakeCommunityApi api;
  late FakeMediaPicker picker;
  late ProviderContainer container;

  setUp(() {
    api = FakeCommunityApi();
    picker = FakeMediaPicker();
    container = ProviderContainer(
      overrides: [
        communityApiProvider.overrideWithValue(api),
        mediaPickerProvider.overrideWithValue(picker),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ComposerState state([String? id]) => container.read(composerProvider(id));
  ComposerController ctl([String? id]) =>
      container.read(composerProvider(id).notifier);

  void start([String? id]) => container.listen(composerProvider(id), (_, _) {});

  test('a title of 5 characters and a content are needed; coins stop at 5', () {
    start();
    ctl()
      ..setTitle('BTC')
      ..setContent('Body');
    expect(state().canPublish, isFalse);
    ctl().setTitle('  BTC holds  ');
    expect(state().canPublish, isTrue);
    for (final c in ['BTC', 'ETH', 'SOL', 'BNB', 'XRP', 'ADA']) {
      ctl().toggleCoin(c);
    }
    expect(state().coins, ['BTC', 'ETH', 'SOL', 'BNB', 'XRP']);
    ctl().toggleCoin('ETH');
    expect(state().coins, ['BTC', 'SOL', 'BNB', 'XRP']);
  });

  test(
    'images upload through the signed form, then the post names them',
    () async {
      start();
      ctl()
        ..setTitle('BTC holds 76k')
        ..setContent('Support held twice.')
        ..setMarket(Market.spot)
        ..setSentiment(PostSentiment.bullish)
        ..toggleCoin('BTC');
      await ctl().addImages();
      await settle();
      expect(picker.limits, [4]);
      expect(state().attachments.map((a) => a.status), [
        AttachmentStatus.ready,
        AttachmentStatus.ready,
      ]);
      expect(state().canAddVideo, isFalse);
      expect(state().canAddImages, isTrue);
      final post = await ctl().submit();
      expect(post!.id, 'new-post');
      final draft = api.drafts.single.toJson();
      expect(draft['marketType'], 'SPOT');
      expect(draft['sentiment'], 'BULLISH');
      expect(draft['coins'], ['BTC']);
      expect(draft['media'], [
        {'publicId': 'posts/u-me/m1', 'mediaType': 'IMAGE'},
        {'publicId': 'posts/u-me/m2', 'mediaType': 'IMAGE'},
      ]);
    },
  );

  test('a file over the size of its form, or refused by the storage, fails '
      '(MSG32) and holds the post until retried or removed', () async {
    start();
    ctl()
      ..setTitle('Title ok')
      ..setContent('Body');
    picker.nextImages = const [
      PickedFile(path: '/tmp/big.png', name: 'big.png', size: 20 * 1024 * 1024),
      PickedFile(path: '/tmp/bad.png', name: 'bad.png', size: 10),
    ];
    api.refusePaths.add('/tmp/bad.png');
    await ctl().addImages();
    await settle();
    final [big, bad] = state().attachments;
    expect(big.status, AttachmentStatus.failed);
    expect(big.tooLarge, 10 * 1024 * 1024);
    expect(api.calls.where((c) => c.contains('big.png')), isEmpty);
    expect(bad.status, AttachmentStatus.failed);
    expect(state().canPublish, isFalse);

    api.refusePaths.clear();
    await ctl().retry(bad);
    ctl().remove(big);
    expect(state().attachments.single.status, AttachmentStatus.ready);
    expect(state().canPublish, isTrue);
  });

  test('a video on a plan without video posting is refused (MSG29); a '
      'video stands alone', () async {
    start();
    api.failNext['form'] = problem(403, 'PLAN_FEATURE_NOT_INCLUDED', 'MSG29');
    await ctl().addVideo();
    await settle();
    final video = state().attachments.single;
    expect(video.status, AttachmentStatus.failed);
    expect(video.failure, isNotNull);
    expect(state().canAddImages, isFalse);
    ctl().remove(video);
    await ctl().addVideo();
    await settle();
    expect(state().attachments.single.status, AttachmentStatus.ready);
    expect(state().canAddImages, isFalse);
  });

  test('editing keeps the stored files and sends them back', () async {
    api.posts['p9'] = postOf(
      'p9',
      title: 'Old title',
      mine: true,
      media: const [
        PostMedia(
          publicId: 'posts/u-me/old',
          kind: MediaKind.image,
          url: 'https://res.cloudinary.com/x/old.png',
        ),
      ],
    );
    start('p9');
    expect(state('p9').loaded, isFalse);
    await settle();
    expect(state('p9').title, 'Old title');
    expect(state('p9').attachments.single.publicId, 'posts/u-me/old');
    ctl('p9').setTitle('New title');
    await ctl('p9').submit();
    expect(api.calls.last, 'update p9 "New title" media=1');
    expect(api.drafts.single.media.single.publicId, 'posts/u-me/old');
  });

  test('fields the server refuses are marked until edited', () async {
    start();
    ctl()
      ..setTitle('Title ok')
      ..setContent('Body');
    api.failNext['create'] = problem(
      400,
      'VALIDATION_FAILED',
      'MSG01',
      fields: {'title': 'MSG01'},
    );
    expect(await ctl().submit(), isNull);
    expect(state().fieldErrors, {'title'});
    expect(state().failure, isNotNull);
    ctl().setTitle('Title ok again');
    expect(state().fieldErrors, isEmpty);
  });
}
