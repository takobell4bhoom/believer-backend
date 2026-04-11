import 'browser_image_picker.dart';

class _UnsupportedBrowserImagePicker implements BrowserImagePicker {
  @override
  Future<BrowserPickedImage?> pickImage() async => null;
}

BrowserImagePicker createBrowserImagePickerImpl() =>
    _UnsupportedBrowserImagePicker();
