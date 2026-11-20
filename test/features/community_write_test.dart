import 'dart:io';

import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/community/data/community_api.dart';
import 'package:cryptopilot_mobile/features/community/domain/community.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';
import 'community_test.dart' show detailJson;

/// T-135 (A-66, D-160): writing posts and uploading their files (D-98).
Map<String, Object?> formJson({
  String url = 'https://api.cloudinary.com/v1_1/x/image/upload',
}) => {
  'uploadUrl': url,
  'apiKey': '123',
  'timestamp': 1763600000,
  'signature': 'abc',
  'publicId': 'cryptopilot/posts/u1/f1',
  'allowedFormats': ['jpg', 'png', 'webp'],
  'overwrite': false,
  'mediaType': 'IMAGE',
  'maxBytes': 10485760,
  'maxDurationSeconds': null,
};

void main() {
  test('the signed form; an address that is not https is refused', () {
    final form = decodeUploadForm(formJson());
    expect(form.kind, MediaKind.image);
    expect(form.maxBytes, 10485760);
    expect(form.allowedFormats, ['jpg', 'png', 'webp']);
    expect(
      () => decodeUploadForm(formJson(url: 'http://storage.test/upload')),
      throwsA(isA<DecodeException>()),
    );
  });

  test('a draft sends only what it has, trimmed', () {
    const draft = PostDraft(
      title: '  BTC holds  ',
      content: ' Support held. ',
      coins: ['BTC'],
      media: [MediaRef(publicId: 'p/1', kind: MediaKind.image)],
    );
    expect(draft.toJson(), {
      'title': 'BTC holds',
      'content': 'Support held.',
      'coins': ['BTC'],
      'media': [
        {'publicId': 'p/1', 'mediaType': 'IMAGE'},
      ],
    });
    const full = PostDraft(
      title: 'Title',
      content: 'Body',
      market: Market.futures,
      sentiment: PostSentiment.bearish,
    );
    expect(full.toJson()['marketType'], 'FUTURES');
    expect(full.toJson()['sentiment'], 'BEARISH');
  });

  group('DioCommunityApi', () {
    late RecordingAdapter api;
    late RecordingAdapter storage;
    late CommunityApi community;

    setUp(() {
      api = RecordingAdapter();
      storage = RecordingAdapter();
      community = DioCommunityApi(
        dioOn(api)..options.headers['Authorization'] = 'Bearer secret',
        storage: Dio()..httpClientAdapter = storage,
      );
    });

    test(
      'the form asks for a kind; create and update send the draft',
      () async {
        api.answers
          ..add((200, formJson()))
          ..add((200, detailJson()))
          ..add((200, detailJson()));
        await community.uploadForm(MediaKind.video);
        const draft = PostDraft(title: 'Title', content: 'Body');
        await community.createPost(draft);
        await community.updatePost('p1', draft);
        final [form, create, update] = api.requests;
        expect((form.method, form.path), ('POST', 'media/upload-signature'));
        expect(form.data, {'mediaType': 'VIDEO'});
        expect((create.method, create.path), ('POST', 'posts'));
        expect((update.method, update.path), ('PUT', 'posts/p1'));
        expect(update.data, draft.toJson());
      },
    );

    test('a file goes to the storage with the signed fields and none of the '
        "app's tokens", () async {
      final dir = await Directory.systemTemp.createTemp('upload');
      addTearDown(() => _remove(dir));
      final file = File('${dir.path}/chart.png')..writeAsBytesSync([1, 2, 3]);
      storage.answers.add((200, {'public_id': 'cryptopilot/posts/u1/f1'}));
      final shares = <double>[];
      await community.upload(
        decodeUploadForm(formJson()),
        file.path,
        onProgress: shares.add,
      );
      final sent = storage.requests.single;
      expect(
        sent.uri.toString(),
        'https://api.cloudinary.com/v1_1/x/image/upload',
      );
      expect(sent.headers.containsKey('Authorization'), isFalse);
      final fields = {
        for (final f in (sent.data as FormData).fields) f.key: f.value,
      };
      expect(fields, {
        'api_key': '123',
        'timestamp': '1763600000',
        'signature': 'abc',
        'public_id': 'cryptopilot/posts/u1/f1',
        'allowed_formats': 'jpg,png,webp',
        'overwrite': 'false',
      });
      expect((sent.data as FormData).files.single.key, 'file');
      expect(shares.last, 1);
    });

    test('a refusal of the storage is the file\'s', () async {
      final dir = await Directory.systemTemp.createTemp('upload');
      addTearDown(() => _remove(dir));
      final file = File('${dir.path}/big.png')..writeAsBytesSync([1]);
      storage.answers.add((
        400,
        {
          'error': {'message': 'File size too large'},
        },
      ));
      await expectLater(
        community.upload(decodeUploadForm(formJson()), file.path),
        throwsA(isA<MediaRefused>()),
      );
    });
  });
}

/// Windows may still hold the file the multipart stream opened.
Future<void> _remove(Directory dir) async {
  try {
    await dir.delete(recursive: true);
  } on FileSystemException {
    // Left to the system's temp cleanup.
  }
}
