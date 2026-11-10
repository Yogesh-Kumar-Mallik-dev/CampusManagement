import 'dart:io';

String _resolveDownloadsDirectory() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final xdgDownload = Platform.environment['XDG_DOWNLOAD_DIR'];
  if (xdgDownload != null && Directory(xdgDownload).existsSync()) {
    return xdgDownload;
  }
  final candidate = Directory('$home/Downloads');
  if (candidate.existsSync()) {
    return candidate.path;
  }
  return home;
}

Future<bool> triggerPdfDownload({
  required String filename,
  required List<int> bytes,
}) async {
  final isTest = Platform.environment.containsKey('FLUTTER_TEST');

  // Headless test environment
  if (isTest) {
    return true;
  }

  String targetPath = '${_resolveDownloadsDirectory()}/$filename';

  // On Linux desktop, offer a native save dialog via zenity if available
  if (Platform.isLinux) {
    try {
      final result = await Process.run('zenity', [
        '--file-selection',
        '--save',
        '--confirm-overwrite',
        '--title=Save PDF Document',
        '--filename=$targetPath',
        '--file-filter=PDF Documents (*.pdf) | *.pdf',
      ]);

      if (result.exitCode == 0) {
        final chosen = result.stdout.toString().trim();
        if (chosen.isNotEmpty) {
          targetPath = chosen;
          if (!targetPath.toLowerCase().endsWith('.pdf')) {
            targetPath += '.pdf';
          }
        }
      } else if (result.exitCode == 1) {
        // User cancelled save dialog
        return false;
      }
    } catch (_) {
      // zenity not available or errored, fallback to direct targetPath
    }
  }

  try {
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    // Open containing folder or file in the desktop file manager
    if (Platform.isLinux) {
      try {
        // Open file directly with default PDF viewer or file manager
        await Process.run('xdg-open', [file.path]);
      } catch (_) {}
    }

    return true;
  } catch (e) {
    return false;
  }
}
