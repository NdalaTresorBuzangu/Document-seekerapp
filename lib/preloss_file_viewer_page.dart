import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app view for a pre-loss file fetched via [ApiService.fetchPrelossFileBytes] (images + PDF in WebView).
class PrelossFileViewerPage extends StatefulWidget {
  const PrelossFileViewerPage({
    super.key,
    required this.title,
    required this.file,
  });

  final String title;
  final File file;

  @override
  State<PrelossFileViewerPage> createState() => _PrelossFileViewerPageState();
}

class _PrelossFileViewerPageState extends State<PrelossFileViewerPage> {
  WebViewController? _pdfController;
  var _pdfLoading = false;

  bool get _isPdf => widget.file.path.toLowerCase().endsWith('.pdf');

  bool get _isRasterImage {
    final path = widget.file.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _pdfLoading = true;
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white);
      _pdfController = c;
      final uri = Uri.file(widget.file.path, windows: Platform.isWindows);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await c.loadRequest(uri);
        if (mounted) setState(() => _pdfLoading = false);
      });
    }
  }

  Future<void> _openExternal() async {
    await OpenFilex.open(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.trim().isEmpty ? 'Pre-loss file' : widget.title.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open with another app',
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new_outlined),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isPdf && _pdfController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _pdfController!),
          if (_pdfLoading)
            const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    if (_isRasterImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.file(widget.file, fit: BoxFit.contain),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'Preview is not available for this file type. Open it with another app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Open file'),
            ),
          ],
        ),
      ),
    );
  }
}
