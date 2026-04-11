// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'browser_image_picker.dart';

class _WebBrowserImagePicker implements BrowserImagePicker {
  @override
  Future<BrowserPickedImage?> pickImage() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    final completer = Completer<BrowserPickedImage?>();

    input.onChange.first.then((_) async {
      final file = input.files?.first;
      if (file == null) {
        completer.complete(null);
        return;
      }

      try {
        final bytes = await _readFileBytes(file);
        completer.complete(
          BrowserPickedImage(
            fileName: file.name,
            bytes: bytes,
            contentType: file.type,
          ),
        );
      } catch (_) {
        completer.complete(null);
      }
    });

    input.click();
    return completer.future;
  }

  Future<Uint8List> _readFileBytes(html.File file) {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
        return;
      }

      if (result is Uint8List) {
        completer.complete(result);
        return;
      }

      completer.completeError(StateError('Unable to read image bytes'));
    });

    reader.onError.first.then((_) {
      completer.completeError(StateError('Unable to read image bytes'));
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
  }
}

BrowserImagePicker createBrowserImagePickerImpl() => _WebBrowserImagePicker();
