// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedPdfFile {
  final String name;
  final int size;
  final List<int> bytes;

  const PickedPdfFile({
    required this.name,
    required this.size,
    required this.bytes,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

PickedPdfFile? _mockPickedFile;
void setMockPickedPdfFile(PickedPdfFile? mock) {
  _mockPickedFile = mock;
}

Future<PickedPdfFile?> pickPdfFile() async {
  if (_mockPickedFile != null) {
    return _mockPickedFile;
  }

  final completer = Completer<PickedPdfFile?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'application/pdf,.pdf';
  uploadInput.multiple = false;

  uploadInput.onChange.listen((e) async {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final file = files[0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    final result = reader.result;
    if (result is Uint8List) {
      completer.complete(PickedPdfFile(
        name: file.name,
        size: file.size,
        bytes: result.toList(),
      ));
    } else if (result is ByteBuffer) {
      completer.complete(PickedPdfFile(
        name: file.name,
        size: file.size,
        bytes: result.asUint8List().toList(),
      ));
    } else {
      completer.complete(null);
    }
  });

  uploadInput.click();
  return completer.future;
}
