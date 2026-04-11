import 'dart:typed_data';

import 'browser_image_picker_stub.dart'
    if (dart.library.html) 'browser_image_picker_web.dart';

class BrowserPickedImage {
  const BrowserPickedImage({
    required this.fileName,
    required this.bytes,
    this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? contentType;
}

const supportedMosqueImageExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
};

bool isSupportedMosqueImageFile(BrowserPickedImage image) {
  final contentType = image.contentType?.trim().toLowerCase() ?? '';
  if (contentType.startsWith('image/jpeg') ||
      contentType.startsWith('image/jpg') ||
      contentType.startsWith('image/png') ||
      contentType.startsWith('image/webp')) {
    return true;
  }

  final fileName = image.fileName.trim().toLowerCase();
  return supportedMosqueImageExtensions.any(fileName.endsWith);
}

abstract class BrowserImagePicker {
  Future<BrowserPickedImage?> pickImage();
}

BrowserImagePicker createBrowserImagePicker() => createBrowserImagePickerImpl();
