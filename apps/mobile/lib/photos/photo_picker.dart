import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// A photo ready to upload: resized and JPEG-compressed on the device.
class PickedPhoto {
  const PickedPhoto(this.bytes, {this.contentType = 'image/jpeg'});

  final Uint8List bytes;
  final String contentType;
}

class PhotoException implements Exception {
  PhotoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Picks photos from the camera or gallery. Swapped for a fake in tests.
abstract class PhotoPicker {
  /// Returns null when the user cancels.
  Future<PickedPhoto?> pick(PhotoSource source);
}

/// Uploads are capped at 1 MB by the Storage bucket.
const maxPhotoBytes = 1024 * 1024;

class DevicePhotoPicker implements PhotoPicker {
  const DevicePhotoPicker();

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // The plugin resizes and re-encodes as JPEG on the device, which keeps
      // phone photos to a few hundred KB.
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxPhotoBytes) {
      throw PhotoException('That photo is too large. Try another one.');
    }
    return PickedPhoto(bytes);
  }
}

/// Used when no picker is wired up.
class NoPhotoPicker implements PhotoPicker {
  const NoPhotoPicker();

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async =>
      throw PhotoException('Photos are not available on this device.');
}
