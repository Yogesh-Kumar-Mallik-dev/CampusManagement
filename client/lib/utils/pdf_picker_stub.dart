import 'dart:convert';

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
  final sampleBytes = utf8.encode('%PDF-1.4\n1 0 obj\n<< /Title (Institutional Textbook) >>\nendobj\ntrailer\n<<>>\n%%EOF');
  return PickedPdfFile(
    name: 'bbdit_curriculum_textbook.pdf',
    size: sampleBytes.length,
    bytes: sampleBytes,
  );
}
