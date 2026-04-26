import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'diagnostics_sheet.dart';
import 'ds_text_styles.dart';
import 'home_page.dart';
import 'new_request_page.dart';
import 'offline_storage.dart';
import 'pack_page.dart';
import 'pending_sync.dart';
import 'preloss_page.dart';
import 'seeker_drawer.dart';
import 'session_store.dart';
import 'track_progress_page.dart';

/// Recovery tools grid — mirrors web `student_dashboard.php` (SeekerController::dashboard).
class SeekerDashboardPage extends StatefulWidget {
  const SeekerDashboardPage({super.key});

  @override
  State<SeekerDashboardPage> createState() => _SeekerDashboardPageState();
}

class _SeekerDashboardPageState extends State<SeekerDashboardPage> {
  List<Map<String, dynamic>> _savedIds = const [];

  @override
  void initState() {
    super.initState();
    _loadSavedDocumentIds();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPendingSync());
  }

  void _loadSavedDocumentIds() {
    _savedIds = OfflineStorageService.getSavedDocumentIds();
  }

  Future<void> _runPendingSync() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final n = await PendingSync.flushAll();
    if (!context.mounted || n <= 0) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Sent $n queued offline item(s).')),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await SessionStore.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
      (r) => false,
    );
  }

  int get _pendingTotal {
    return OfflineStorageService.pendingQueueTotalCount;
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (!mounted) return;
    setState(_loadSavedDocumentIds);
  }

  Future<void> _refreshDashboard() async {
    _loadSavedDocumentIds();
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    final n = await PendingSync.flushAll();
    if (!mounted) return;
    if (n > 0) {
      messenger.showSnackBar(SnackBar(content: Text('Synced $n queued item(s).')));
    }
  }

  String _formatDate(dynamic raw) {
    final txt = raw?.toString() ?? '';
    final dt = DateTime.tryParse(txt);
    if (dt == null) return '';
    return DateFormat('MMM d, y • HH:mm').format(dt.toLocal());
  }

  Future<void> _copyDocId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Document ID copied: $id')),
    );
  }

  Future<void> _clearAllDocIds() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear all IDs?', style: Theme.of(ctx).textTheme.titleLarge),
        content: Text(
          'This only clears the local list on your device, not server documents.',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await OfflineStorageService.clearSavedDocumentIds();
    if (!mounted) return;
    setState(_loadSavedDocumentIds);
  }

  @override
  Widget build(BuildContext context) {
    final name = SessionStore.userName ?? 'Seeker';
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pending = _pendingTotal;

    return Scaffold(
      drawer: const SeekerDrawer(section: SeekerDrawerSection.dashboard),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: SeekerMenuLeading.widthFor(context),
        leading: const SeekerMenuLeading(),
        title: const Text('Document Seeker'),
        actions: [
          if (pending > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('$pending offline', style: textTheme.labelMedium),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              await _refreshDashboard();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sync offline queue',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final n = await PendingSync.flushAll();
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(n > 0 ? 'Sent $n item(s).' : 'Nothing to sync or still offline.'),
                ),
              );
              setState(() {});
            },
            icon: const Icon(Icons.cloud_sync),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'diag') {
                showConnectionDiagnosticsSheet(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'diag',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('Connection diagnostics'),
                  subtitle: Text('For support / troubleshooting'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    'Welcome, $name',
                    style: context.dsEmphasisTitle(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submit requests, track progress, and keep your document IDs handy.',
                    textAlign: TextAlign.center,
                    style: context.dsBodyMuted(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_savedIds.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'My document IDs',
                      style: context.dsEmphasisTitle(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted IDs saved on this device for quick copy and tracking.',
                      textAlign: TextAlign.center,
                      style: context.dsBodyMuted(),
                    ),
                    const SizedBox(height: 10),
                    ..._savedIds.map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                item['id']?.toString() ?? '',
                                style: context.dsMonospaceId(),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatDate(item['date'])}  ${item['description']?.toString() ?? ''}',
                                style: context.dsBodyMuted(),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _copyDocId(item['id']?.toString() ?? ''),
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => _openPage(
                                      TrackProgressPage(
                                        initialDocumentId: item['id']?.toString(),
                                      ),
                                    ),
                                    icon: const Icon(Icons.track_changes, size: 16),
                                    label: const Text('Track'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _clearAllDocIds,
                        child: const Text('Clear all'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Recovery tools',
            textAlign: TextAlign.center,
            style: context.dsPanelTitle(),
          ),
          const SizedBox(height: 6),
          Text(
            'Submit requests, open your pack, track progress, or upload copies to protect.',
            textAlign: TextAlign.center,
            style: context.dsBodyMuted(),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              _ToolCard(
                icon: Icons.send,
                title: 'Submit request',
                description: 'Request documents from issuers.',
                features: const [
                  'Submit new document requests',
                  'Track status of requests',
                  'Receive issuer updates',
                ],
                buttonText: 'Submit new request',
                onTap: () => _openPage(const NewRequestPage()),
              ),
              _ToolCard(
                icon: Icons.folder_copy,
                title: 'Tshijuka Pack',
                description: 'Your collected documents in one place.',
                features: const [
                  'View all your documents',
                  'Download when needed',
                  'Share with consent',
                ],
                buttonText: 'View documents',
                onTap: () => _openPage(const PackPage()),
              ),
              _ToolCard(
                icon: Icons.track_changes,
                title: 'Track progress',
                description: 'Check status of your document requests.',
                features: const [
                  'Enter your document ID',
                  'See current status',
                  'View issuer updates',
                ],
                buttonText: 'Check status',
                onTap: () => _openPage(const TrackProgressPage()),
              ),
              _ToolCard(
                icon: Icons.cloud_upload,
                title: 'Upload & protect',
                description: 'Store copies before any loss or damage.',
                features: const [
                  'Upload IDs, diplomas and more',
                  'Keep secure backup copies',
                  'Download when needed',
                ],
                buttonText: 'Upload & protect',
                onTap: () => _openPage(const PrelossPage()),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.buttonText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final String buttonText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 30, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.dsEmphasisTitle().copyWith(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.dsBodyMuted().copyWith(fontSize: 12),
              ),
              const SizedBox(height: 6),
              ...features.take(3).map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $f',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsFeatureBullet(),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  textStyle: context.dsCompactButtonLabel().copyWith(fontSize: 12),
                ),
                child: Text(buttonText, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
