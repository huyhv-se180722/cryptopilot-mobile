import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A file the Trader picked: post media or a journal chart image.
@immutable
class PickedFile {
  const PickedFile({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;

  /// In bytes.
  final int size;
}

/// Picks files from the phone (D-160, ADR-024): post media (T-135) and
/// journal chart images (T-091); null or empty when the Trader cancels.
abstract interface class MediaPicker {
  /// Up to [limit] images at once.
  Future<List<PickedFile>> images({required int limit});

  Future<PickedFile?> video();
}

/// `image_picker`: the system photo picker on Android 13 and later, so no
/// storage permission.
class ImageMediaPicker implements MediaPicker {
  ImageMediaPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static Future<PickedFile> _of(XFile file) async =>
      PickedFile(path: file.path, name: file.name, size: await file.length());

  @override
  Future<List<PickedFile>> images({required int limit}) async {
    if (limit <= 0) return const [];
    final files = limit == 1
        ? [?await _picker.pickImage(source: ImageSource.gallery)]
        : await _picker.pickMultiImage(limit: limit);
    return [for (final f in files.take(limit)) await _of(f)];
  }

  @override
  Future<PickedFile?> video() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    return file == null ? null : _of(file);
  }
}

final mediaPickerProvider = Provider<MediaPicker>((_) => ImageMediaPicker());
