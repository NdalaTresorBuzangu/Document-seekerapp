import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'preloss_file_viewer_page.dart';

String _extensionForBytes(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
    return '.jpg';
  }
  if (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
    return '.pdf';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return '.png';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return '.gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46) {
    return '.webp';
  }
  return '.bin';
}

/// Opens the submitted attachment for a document request (in-app viewer).
Future<void> openDocumentRequestAttachment(
  BuildContext context,
  String documentId,
  String title,
) async {
  if (!context.mounted) return;
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachment preview is available in the Android or iOS app.')),
    );
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading attachment…', style: Theme.of(ctx).textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  try {
    final bytes = await ApiService.fetchDocumentAttachmentBytesReliable(documentId);
    final ext = _extensionForBytes(bytes);
    final dir = await getTemporaryDirectory();
    final safeId = documentId.replaceAll(RegExp(r'[^\w.-]'), '_');
    final f = File(p.join(dir.path, 'doc_attach_$safeId$ext'));
    await f.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrelossFileViewerPage(
          title: title.trim().isEmpty ? 'Submitted attachment' : title.trim(),
          file: f,
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No attachment found for this request, or it could not be loaded. '
            'If you just submitted, wait a moment and try again.',
          ),
        ),
      );
    }
  }
}
