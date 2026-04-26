import 'dart:async';

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'ds_text_styles.dart';
import 'chat_page.dart';
import 'document_attachment_open.dart';
import 'offline_storage.dart';
import 'seeker_drawer.dart';

/// Same flow as web `SeekerController::progress` / `progress.php` (lookup by document ID).
class TrackProgressPage extends StatefulWidget {
  const TrackProgressPage({super.key, this.initialDocumentId});

  /// When set (e.g. after submit), the field is filled and status is loaded automatically.
  final String? initialDocumentId;

  @override
  State<TrackProgressPage> createState() => _TrackProgressPageState();
}

class _TrackProgressPageState extends State<TrackProgressPage> {
  final _idCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDocumentId?.trim();
    if (initial != null && initial.isNotEmpty) {
      _idCtrl.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_lookup());
      });
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final doc = await ApiService.trackDocument(id);
      if (!mounted) return;
      setState(() {
        _result = doc;
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

  Future<void> _onRefresh() async {
    if (_idCtrl.text.trim().isEmpty) return;
    await _lookup();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offlinePending = OfflineStorageService.pendingQueueTotalCount;

    return Scaffold(
      drawer: const SeekerDrawer(section: SeekerDrawerSection.track),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: SeekerMenuLeading.widthFor(context),
        leading: const SeekerMenuLeading(),
        title: const Text('Track progress'),
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
            tooltip: 'Refresh status',
            onPressed: _loading ? null : _onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_idCtrl.text.trim().isEmpty) return;
          await _lookup();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the document ID you received after submitting a request. '
                'You can also find it under “My Document IDs” on your home screen.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document ID',
                  hintText: 'Paste or type your ID',
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _lookup(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _lookup,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check status'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(_error!, style: context.dsErrorMessage()),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        final id = _result!['documentID']?.toString() ?? _idCtrl.text.trim();
                        if (id.isEmpty) return;
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatPage(documentId: id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with institution'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Same field order as web `progress.php` (ID → description → status → attachment).
                _row('Document ID', _result!['documentID']?.toString() ?? ''),
                _row('Description', _result!['description']?.toString() ?? ''),
                _row('Status', _result!['statusName']?.toString() ?? ''),
                _row('Location', _result!['location']?.toString() ?? ''),
                _row('Submitted', _result!['submissionDate']?.toString() ?? ''),
                if (_resultShowsAttachment(_result!)) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => openDocumentRequestAttachment(
                      context,
                      _result!['documentID']?.toString() ?? _idCtrl.text.trim(),
                      _result!['description']?.toString() ?? '',
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('View submitted attachment'),
                  ),
                  if ((_result!['imagePath']?.toString() ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Stored as: ${_result!['imagePath']}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _resultShowsAttachment(Map<String, dynamic> r) {
    final path = r['imagePath']?.toString().trim() ?? '';
    if (path.isNotEmpty) return true;
    final mime = r['imageMime']?.toString().trim() ?? '';
    return mime.isNotEmpty;
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          SelectableText(v.isEmpty ? '—' : v),
        ],
      ),
    );
  }
}
