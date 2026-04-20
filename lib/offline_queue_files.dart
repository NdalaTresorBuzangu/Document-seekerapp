import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies user-picked files into app documents so queued uploads still exist after
/// OS temp/cache cleanup (same idea as durable offline queues in the reference template).
class OfflineQueueFiles {
  OfflineQueueFiles._();

  static const _uuid = Uuid();

  /// Returns a path under app storage, or [sourcePath] if copy is not needed or fails.
  static Future<String> persistForSyncQueue({
    required String sourcePath,
    required String namespace,
  }) async {
    if (kIsWeb) return sourcePath;
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return sourcePath;
      final root = await getApplicationDocumentsDirectory();
      final sub = Directory(p.join(root.path, 'document_seeker_queue', namespace));
      if (!await sub.exists()) {
        await sub.create(recursive: true);
      }
      final ext = p.extension(sourcePath);
      final name = '${_uuid.v4()}$ext';
      final destPath = p.join(sub.path, name);
      await src.copy(destPath);
      return destPath;
    } catch (_) {
      return sourcePath;
    }
  }
}
