import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'ds_text_styles.dart';
import 'camera_capture_page.dart';
import 'offline_storage.dart';
import 'pending_sync.dart';
import 'preloss_file_viewer_page.dart';
import 'seeker_drawer.dart';
import 'storyline_helpers.dart';

/// Pre-loss storage — same table/actions idea as web `SeekerController::preloss` + `preloss_upload_action.php`.
class PrelossPage extends StatefulWidget {
  const PrelossPage({super.key});

  @override
  State<PrelossPage> createState() => _PrelossPageState();
}

class _PrelossPageState extends State<PrelossPage> {
  final List<_PrelossRowInput> _rows = [_PrelossRowInput()];
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.fetchPrelossList();
      await PendingSync.cachePrelossList(list);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      final cached = PendingSync.readCachedPrelossList();
      if (!mounted) return;
      setState(() {
        if (cached != null && cached.isNotEmpty) {
          _items = cached;
          _error =
              'Offline or server error — showing last saved list. ${e.toString().replaceFirst('Exception: ', '')}';
        } else {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
        _loading = false;
      });
    }
  }

  void _addRow() {
    setState(() => _rows.add(_PrelossRowInput()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _pickFiles(int index) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    if (result == null) return;
    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) return;
    final out = <String>[];
    for (final path in paths) {
      final lower = path.toLowerCase();
      if (lower.endsWith('.pdf')) {
        out.add(path);
      } else {
        out.add(await StorylineHelpers.compressImageIfNeeded(path));
      }
    }
    if (!mounted) return;
    setState(() => _rows[index].filePaths = out);
  }

  Future<void> _captureImage(int index) async {
    if (kIsWeb) {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92);
      if (x == null || !mounted) return;
      final c = await StorylineHelpers.compressImageIfNeeded(x.path);
      if (!mounted) return;
      setState(() => _rows[index].filePaths = [c]);
      return;
    }
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );
    if (path == null || path.isEmpty || !mounted) return;
    final c = await StorylineHelpers.compressImageIfNeeded(path);
    if (!mounted) return;
    setState(() => _rows[index].filePaths = [c]);
  }

  Future<void> _uploadRows() async {
    for (final row in _rows) {
      if (row.titleCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each row needs a title (same as the website).')),
        );
        return;
      }
      if (row.filePaths.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose file(s) or take a picture for each row — same as the website.'),
          ),
        );
        return;
      }
    }

    setState(() => _uploading = true);
    var sent = 0;
    var queued = 0;
    try {
      for (final row in _rows) {
        final title = row.titleCtrl.text.trim();
        for (final path in row.filePaths) {
          final file = File(path);
          if (!await file.exists()) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File missing on device: ${file.path}')),
            );
            return;
          }
          try {
            final newId = await ApiService.uploadPreloss(title: title, file: file);
            sent++;
            if (newId != null && !kIsWeb) {
              try {
                final b = await file.readAsBytes();
                await OfflineStorageService.cachePrelossLocalBytes(newId, b);
              } catch (_) {}
            }
          } catch (e) {
            if (!kIsWeb && PendingSync.isLikelyNetworkFailure(e)) {
              await PendingSync.enqueuePrelossUpload(
                title: title,
                localFilePath: file.path,
              );
              queued++;
            } else {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
              );
              return;
            }
          }
        }
      }
      if (!mounted) return;
      if (queued > 0 && sent == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Offline: $queued file(s) queued. They will upload when you are back online.',
            ),
          ),
        );
      } else if (queued > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $sent file(s). $queued queued for when online.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sent == 1 ? 'Document saved successfully.' : '$sent documents saved.')),
        );
      }
      for (final row in _rows) {
        row.dispose();
      }
      _rows
        ..clear()
        ..add(_PrelossRowInput());
      await _load();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _prelossBasename(dynamic path) {
    final raw = path?.toString() ?? '';
    if (raw.isEmpty) return '';
    final norm = raw.replaceAll('\\', '/');
    final i = norm.lastIndexOf('/');
    return i >= 0 ? norm.substring(i + 1) : norm;
  }

  String _mimeTypeForFilename(String name) {
    final e = p.extension(name).toLowerCase();
    switch (e) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  int? _prelossId(Map<String, dynamic> row) {
    final id = row['prelossID'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  void _showBlockingLoader() {
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
                  Text('Loading…', style: Theme.of(ctx).textTheme.titleSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideBlockingLoader() {
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  Future<void> _openPrelossView(Map<String, dynamic> row) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open this screen in the Android or iOS app to view files.')),
      );
      return;
    }
    final pid = _prelossId(row);
    final base = _prelossBasename(row['filePath']);
    if (pid == null || pid <= 0 || base.isEmpty) return;
    _showBlockingLoader();
    try {
      final local = OfflineStorageService.getPrelossLocalBytes(pid);
      final Uint8List bytes = (local != null && local.isNotEmpty)
          ? local
          : await ApiService.fetchPrelossFileBytesReliable(pid, download: false);
      final dir = await getTemporaryDirectory();
      final safeName = base.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final f = File(p.join(dir.path, 'preloss_view_${pid}_$safeName'));
      await f.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _hideBlockingLoader();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PrelossFileViewerPage(
            title: row['title']?.toString() ?? '',
            file: f,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _hideBlockingLoader();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to show this file. Check your connection, swipe down to refresh the list, '
              'or upload it again from this phone so a local copy is kept.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadPrelossToDevice(Map<String, dynamic> row) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download from this list is available in the Android or iOS app.')),
      );
      return;
    }
    final pid = _prelossId(row);
    final base = _prelossBasename(row['filePath']);
    if (pid == null || pid <= 0 || base.isEmpty) return;
    _showBlockingLoader();
    try {
      final local = OfflineStorageService.getPrelossLocalBytes(pid);
      final Uint8List bytes = (local != null && local.isNotEmpty)
          ? local
          : await ApiService.fetchPrelossFileBytesReliable(pid, download: true);
      final root = await getApplicationDocumentsDirectory();
      final sub = Directory(p.join(root.path, 'preloss_downloads'));
      await sub.create(recursive: true);
      final safeName = base.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final f = File(p.join(sub.path, safeName));
      await f.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _hideBlockingLoader();
      final mime = _mimeTypeForFilename(safeName);
      await Share.shareXFiles(
        [XFile(f.path, name: safeName, mimeType: mime)],
        subject: row['title']?.toString().trim().isNotEmpty == true
            ? row['title']!.toString().trim()
            : 'Pre-loss backup',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use your phone’s share sheet — choose Save to Files, Drive, or Downloads to keep a copy.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _hideBlockingLoader();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to save this file. Check your connection, swipe down to refresh, '
              'or upload again from this phone.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = row['prelossID'];
    final pid = id is int ? id : int.tryParse(id.toString()) ?? 0;
    if (pid <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove this backup?'),
        content: Text('Delete “${row['title']}”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.deletePreloss(pid);
      await OfflineStorageService.removePrelossLocalBytes(pid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offlinePending = OfflineStorageService.pendingQueueTotalCount;
    return Scaffold(
      drawer: const SeekerDrawer(section: SeekerDrawerSection.preloss),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: SeekerMenuLeading.widthFor(context),
        leading: const SeekerMenuLeading(),
        title: const Text('Upload & protect (pre-loss)'),
        actions: [
          if (offlinePending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Chip(
                  label: Text('$offlinePending offline'),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh list',
            onPressed: (_loading || _uploading) ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_uploading || _loading) ? null : _uploadRows,
        icon: Icon(_uploading ? Icons.hourglass_top : Icons.cloud_upload_outlined),
        label: Text(_uploading ? 'Uploading…' : 'Upload all'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add one or more documents per row. You can attach several files or take a picture — same flow as the website.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Documents to upload',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      OutlinedButton(
                        onPressed: _addRow,
                        child: const Text('+ Add another document'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_rows.length, (i) {
                    final row = _rows[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              controller: row.titleCtrl,
                              decoration: const InputDecoration(labelText: 'Title'),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _pickFiles(i),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Choose file(s)'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _captureImage(i),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Take picture'),
                                ),
                                if (_rows.length > 1)
                                  TextButton(
                                    onPressed: () => _removeRow(i),
                                    child: const Text('Remove'),
                                  ),
                              ],
                            ),
                            if (row.filePaths.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${row.filePaths.length} file(s) selected',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: context.dsErrorMessage()),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No stored copies yet.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else
            ..._items.map(
              (row) => Card(
                child: ListTile(
                  title: Text(row['title']?.toString() ?? ''),
                  subtitle: Text(row['uploadedOn']?.toString() ?? ''),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'View',
                        onPressed: () => _openPrelossView(row),
                        icon: const Icon(Icons.remove_red_eye_outlined),
                      ),
                      IconButton(
                        tooltip: 'Save or share file',
                        onPressed: () => _downloadPrelossToDevice(row),
                        icon: const Icon(Icons.download_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _delete(row),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _PrelossRowInput {
  final titleCtrl = TextEditingController();
  List<String> filePaths = [];

  void dispose() {
    titleCtrl.dispose();
  }
}
