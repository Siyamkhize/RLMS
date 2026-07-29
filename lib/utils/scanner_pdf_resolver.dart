import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _scannerPdfChannel =
    MethodChannel('com.example.rlmss/scanner_pdf');

/// Resolves [FlutterDocScanner] / ML Kit `pdfUri` to a local readable [File].
///
/// On Android, URIs are often `content://...`, which Dart [File] cannot open directly.
Future<File?> resolveFlutterDocScannerPdfFile(String? pdfUriString) async {
  if (pdfUriString == null || pdfUriString.isEmpty) return null;

  final String s = pdfUriString.trim();
  try {
    final Uri? uri = Uri.tryParse(s);
    if (uri != null && uri.scheme == 'file') {
      final path = uri.toFilePath(windows: Platform.isWindows);
      final f = File(path);
      return await f.exists() ? f : null;
    }

    if (uri != null && uri.scheme == 'content') {
      if (!Platform.isAndroid) return null;
      try {
        final path =
            await _scannerPdfChannel.invokeMethod<String>('copyPdfToCache', s);
        if (path == null || path.isEmpty) return null;
        final f = File(path);
        return await f.exists() ? f : null;
      } catch (e, st) {
        debugPrint('scanner_pdf_resolver copyPdfToCache failed: $e\n$st');
        return null;
      }
    }

    // Legacy `file:///` stripping or absolute filesystem path
    final stripped = s.replaceFirst(RegExp(r'^file://'), '');
    final tryFile = File(stripped);
    if (await tryFile.exists()) return tryFile;
  } catch (e, st) {
    debugPrint('resolveFlutterDocScannerPdfFile: $e\n$st');
  }
  return null;
}

/// True if file exists and starts with PDF magic bytes `%PDF`.
Future<bool> isReadablePdfFile(File file) async {
  if (!await file.exists()) return false;
  final RandomAccessFile raf = await file.open(mode: FileMode.read);
  try {
    final Uint8List head = await raf.read(4);
    if (head.length < 4) return false;
    return head[0] == 0x25 &&
        head[1] == 0x50 &&
        head[2] == 0x44 &&
        head[3] == 0x46;
  } finally {
    await raf.close();
  }
}
