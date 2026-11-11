import 'dart:io';

String _resolveUploadsDirectory() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final dir = Directory('$home/.campus_management/uploads');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir.path;
}

Future<void> persistUploadedPdf(String fileId, String filename, List<int> bytes) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return;
  }
  try {
    final baseDir = _resolveUploadsDirectory();
    final namedFile = File('$baseDir/${fileId}_$filename');
    await namedFile.writeAsBytes(bytes, flush: true);

    final idFile = File('$baseDir/$fileId.pdf');
    await idFile.writeAsBytes(bytes, flush: true);
  } catch (_) {}
}

Future<List<int>?> readUploadedPdf(String fileId) async {
  try {
    final baseDir = _resolveUploadsDirectory();
    final idFile = File('$baseDir/$fileId.pdf');
    if (await idFile.exists()) {
      return await idFile.readAsBytes();
    }

    final dir = Directory(baseDir);
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains(fileId)) {
          return await entity.readAsBytes();
        }
      }
    }
  } catch (_) {}
  return null;
}

Future<String?> getUploadedPdfDiskPath(String fileId) async {
  try {
    final baseDir = _resolveUploadsDirectory();
    final idFile = File('$baseDir/$fileId.pdf');
    if (await idFile.exists()) {
      return idFile.path;
    }
    final dir = Directory(baseDir);
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains(fileId)) {
          return entity.path;
        }
      }
    }
  } catch (_) {}
  return null;
}
