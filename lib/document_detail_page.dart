import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';
import 'api_service.dart';
import 'chat_page.dart';
import 'document_attachment_open.dart';
import 'track_progress_page.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _doc;

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
      final d = await ApiService.fetchDocumentDetail(widget.documentId);
      if (!mounted) return;
      setState(() {
        _doc = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete request?'),
        content: const Text(
          'This removes the document request from the database if your account is allowed to delete it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.deleteDocument(widget.documentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request detail'),
        actions: [
          if (!_loading)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          if (!_loading && _error == null && _doc != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ChatPage(documentId: widget.documentId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat with institution'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => TrackProgressPage(
                                  initialDocumentId: widget.documentId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.track_changes_outlined),
                          label: const Text('Track status'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final u = Uri.parse(ApiConfig.webDocumentViewUrl(widget.documentId));
                            if (await canLaunchUrl(u)) {
                              await launchUrl(u, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('View on web'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _tile('Document ID', _doc!['documentID']?.toString() ?? ''),
                    _tile('Type', _doc!['documentType']?.toString() ?? ''),
                    _tile('Status', _doc!['statusName']?.toString() ?? ''),
                    _tile('Issuer', _doc!['issuerName']?.toString() ?? ''),
                    _tile('Location', _doc!['location']?.toString() ?? ''),
                    _tile('Description', _doc!['description']?.toString() ?? ''),
                    _tile('Submitted', _doc!['submissionDate']?.toString() ?? ''),
                    if (_docShowsAttachment(_doc!)) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => openDocumentRequestAttachment(
                          context,
                          widget.documentId,
                          _doc!['description']?.toString() ?? '',
                        ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('View submitted attachment'),
                      ),
                      if ((_doc!['imagePath']?.toString() ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Stored as: ${_doc!['imagePath']}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }

  bool _docShowsAttachment(Map<String, dynamic> d) {
    final path = d['imagePath']?.toString().trim() ?? '';
    if (path.isNotEmpty) return true;
    final mime = d['imageMime']?.toString().trim() ?? '';
    return mime.isNotEmpty;
  }

  Widget _tile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
