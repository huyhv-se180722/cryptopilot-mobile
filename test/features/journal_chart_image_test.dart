import 'dart:io';

import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/journal/data/journal_api.dart';
import 'package:cryptopilot_mobile/features/journal/domain/journal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';
import 'plan_journal_test.dart' show journalJson;

/// T-091 follow-up (Q-97): the chart image of a journal review.
const key =
    'cryptopilot/journal/5f0c8a52-0d7b-4c39-9c51-2f1d1c0e9a77/'
    '0b6f1c2e-1111-4222-8333-444455556666';

Map<String, Object?> formJson() => {
  'uploadUrl': 'https://api.cloudinary.com/v1_1/demo/image/upload',
  'apiKey': '1234',
  'timestamp': 1763700000,
  'signature': 'abc',
  'publicId': key,
  'allowedFormats': ['jpg', 'jpeg', 'png', 'webp'],
  'maxBytes': 5242880,
};

/// A file to upload; Windows may still hold it when the test ends.
File tempImage(String name, List<int> bytes) {
  final dir = Directory.systemTemp.createTempSync('cp_chart');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Left to the system's temp cleanup.
    }
  });
  return File('${dir.path}/$name')..writeAsBytesSync(bytes);
}

void main() {
  group('the key of a stored image', () {
    test('read from its address, with or without a version', () {
      expect(
        chartImageKeyOf(
          'https://res.cloudinary.com/demo/image/upload/v1763700000/$key.png',
        ),
        key,
      );
      expect(
        chartImageKeyOf(
          'https://res.cloudinary.com/demo/image/upload/$key.webp',
        ),
        key,
      );
    });

    test('none from an address of another shape', () {
      expect(chartImageKeyOf(null), isNull);
      expect(chartImageKeyOf('https://cdn.example.com/chart.png'), isNull);
      expect(
        chartImageKeyOf(
          'https://res.cloudinary.com/demo/image/upload/v1/folder/chart.png',
        ),
        isNull,
      );
    });
  });

  group('the signed form', () {
    test('decoded; formats in lower case; a file is checked by its name', () {
      final form = decodeChartImageForm({
        ...formJson(),
        'allowedFormats': ['PNG', 'jpg'],
      });
      expect(form.publicId, key);
      expect(form.maxBytes, 5242880);
      expect(form.accepts('chart.PNG'), isTrue);
      expect(form.accepts('chart.gif'), isFalse);
      expect(form.accepts('chart'), isFalse);
    });

    test('an address that is not https, or a bad field, is refused', () {
      expect(
        () => decodeChartImageForm({
          ...formJson(),
          'uploadUrl': 'http://api.cloudinary.com/x',
        }),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeChartImageForm({...formJson(), 'maxBytes': '5'}),
        throwsA(isA<DecodeException>()),
      );
    });
  });

  group('DioJournalApi', () {
    late RecordingAdapter adapter;
    late RecordingAdapter storage;
    late JournalApi api;

    setUp(() {
      adapter = RecordingAdapter();
      storage = RecordingAdapter();
      api = DioJournalApi(
        dioOn(adapter),
        storage: Dio()..httpClientAdapter = storage,
      );
    });

    test('the form, then the file to the storage without the app client, '
        'then the review names the key', () async {
      final file = tempImage('chart.png', [1, 2, 3]);
      adapter.answers.addAll([
        (200, formJson()),
        (200, {...journalJson(), 'chartImageUrl': 'https://x/$key.png'}),
      ]);
      storage.answers.add((200, {'public_id': key}));
      final form = await api.chartImageForm('j1');
      final shares = <double>[];
      await api.uploadChartImage(form, file.path, onProgress: shares.add);
      await api.review('j1', chartImagePublicId: form.publicId);

      expect(adapter.requests[0].method, 'POST');
      expect(
        adapter.requests[0].path,
        'journal/j1/chart-image/upload-signature',
      );
      final upload = storage.requests.single;
      expect(upload.uri.toString(), formJson()['uploadUrl']);
      expect(upload.headers['Authorization'], isNull);
      final fields = {
        for (final f in (upload.data as FormData).fields) f.key: f.value,
      };
      expect(fields, {
        'api_key': '1234',
        'timestamp': '1763700000',
        'signature': 'abc',
        'public_id': key,
        'allowed_formats': 'jpg,jpeg,png,webp',
        'overwrite': 'false',
      });
      expect(shares.last, 1);
      expect(adapter.requests[1].data, containsPair('chartImagePublicId', key));
    });

    test('a refusal of the storage is ChartImageRefused', () async {
      final file = tempImage('chart.png', [1]);
      storage.answers.add((400, {'error': 'Invalid Signature'}));
      await expectLater(
        api.uploadChartImage(decodeChartImageForm(formJson()), file.path),
        throwsA(isA<ChartImageRefused>()),
      );
    });
  });
}
