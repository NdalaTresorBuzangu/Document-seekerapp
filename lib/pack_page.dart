import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'ds_text_styles.dart';
import 'chat_page.dart';
import 'pending_sync.dart';
import 'document_detail_page.dart';
import 'track_progress_page.dart';
import 'login_page.dart';
import 'new_request_page.dart';
import 'offline_storage.dart';
import 'seeker_drawer.dart';
import 'session_store.dart';

/// Tshijuka Pack — same list as web `SeekerController::pack` / `tshijuka_pack.php`.
class PackPage extends StatefulWidget {
  const PackPage({super.key});

  @override
  State<PackPage> createState() => _PackPageState();
}

class _PackPageState extends State<PackPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _docs = [];

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
      final list = await ApiService.fetchMyDocuments();
      await PendingSync.cacheDocumentsList(list);
      if (!mounted) return;
      setState(() {
        _docs = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      final cached = PendingSync.readCachedDocumentsList();
      if (!mounted) return;
      setState(() {
        if (cached != null && cached.isNotEmpty) {
          _docs = cached;
          _error =
              'Offline or server error — showing last saved list. ${e.toString().replaceFirst('Exception: ', '')}';
        } else {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = SessionStore.userName ?? 'Seeker';
    final scheme = Theme.of(context).colorScheme;
    final offlinePending = OfflineStorageService.pendingQueueTotalCount;

    return Scaffold(
      drawer: const SeekerDrawer(section: SeekerDrawerSection.pack),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: SeekerMenuLeading.widthFor(context),
        leading: const SeekerMenuLeading(),
        title: const Text('Tshijuka Pack'),
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
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NewRequestPage()),
          );
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, style: context.dsErrorMessage()),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          if (SessionStore.token == null) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                            );
                          } else {
                            _load();
                          }
                        },
                        child: Text(
                          SessionStore.token == null ? 'Log in' : 'Retry',
                        ),
                      ),
                    ],
                  )
                : _docs.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            'Welcome, $name',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No document requests yet. Use “New request” to submit one — same database as the website.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: _docs.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (c, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Welcome, $name — your submitted requests',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            );
                          }
                          final d = _docs[i - 1];
                          final id = d['documentID']?.toString() ?? '';
                          final type = d['documentType']?.toString() ?? '';
                          final inst = d['documentIssuerName']?.toString() ??
                              d['issuerName']?.toString() ??
                              '';
                          final status = d['statusName']?.toString() ?? '';
                          final dateRaw = d['submissionDate']?.toString();
                          String dateLabel = '';
                          if (dateRaw != null && dateRaw.isNotEmpty) {
                            try {
                              dateLabel = DateFormat.yMMMd().add_jm().format(
                                    DateTime.parse(dateRaw),
                                  );
                            } catch (_) {
                              dateLabel = dateRaw;
                            }
                          }
                          final sub = [
                            if (inst.isNotEmpty) inst,
                            status,
                            dateLabel,
                          ].where((e) => e.isNotEmpty).join(' · ');
                          return Card(
                            child: ListTile(
                              title: Text(type.isEmpty ? 'Document' : type),
                              subtitle: Text(sub),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (id.isNotEmpty) ...[
                                    IconButton(
                                      tooltip: 'Chat with institution',
                                      icon: const Icon(Icons.chat_bubble_outline),
                                      onPressed: () {
                                        Navigator.of(context).push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ChatPage(documentId: id),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Track status',
                                      icon: const Icon(Icons.track_changes_outlined),
                                      onPressed: () {
                                        Navigator.of(context).push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                TrackProgressPage(initialDocumentId: id),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => DocumentDetailPage(documentId: id),
                                  ),
                                );
                                _load();
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
