Future<bool> triggerPdfDownload({
  required String filename,
  required List<int> bytes,
}) async {
  // Fallback for native/unit testing environments
  return true;
}

Future<void> openInFileManager(String filePath) async {}
