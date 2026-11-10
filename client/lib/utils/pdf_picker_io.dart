import 'dart:convert';
import 'dart:io';

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

  // In automated test runner, use deterministic sample without opening GUI dialog
  final isTest = Platform.environment.containsKey('FLUTTER_TEST');
  if (isTest) {
    final sampleBytes = utf8.encode('%PDF-1.4\n1 0 obj\n<< /Title (Institutional Textbook) >>\nendobj\ntrailer\n<<>>\n%%EOF');
    return PickedPdfFile(
      name: 'bbdit_curriculum_textbook.pdf',
      size: sampleBytes.length,
      bytes: sampleBytes,
    );
  }

  // Real native Linux file chooser dialog
  if (Platform.isLinux) {
    try {
      final result = await Process.run('zenity', [
        '--file-selection',
        '--title=Select PDF E-Book Document',
        '--file-filter=PDF Documents (*.pdf) | *.pdf',
      ]);

      if (result.exitCode == 0) {
        final filePath = result.stdout.toString().trim();
        if (filePath.isNotEmpty) {
          final file = File(filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final segments = file.uri.pathSegments.where((s) => s.isNotEmpty).toList();
            final name = segments.isNotEmpty ? segments.last : 'document.pdf';
            return PickedPdfFile(
              name: name,
              size: bytes.length,
              bytes: bytes,
            );
          }
        }
      } else if (result.exitCode == 1) {
        // User cancelled file selection dialog
        return null;
      }
    } catch (_) {
      // zenity not available or errored
    }
  }

  return null;
}
