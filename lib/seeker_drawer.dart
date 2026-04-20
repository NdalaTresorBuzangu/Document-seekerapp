import 'package:flutter/material.dart';

import 'diagnostics_sheet.dart';
import 'home_page.dart';
import 'offline_storage.dart';
import 'pending_sync.dart';
import 'session_store.dart';

/// Which area is active (highlights the matching drawer row).
enum SeekerDrawerSection {
  dashboard,
  submitRequest,
  pack,
  track,
  preloss,
}

/// Hamburger to open the [Scaffold] drawer, plus a back control when this route was pushed.
class SeekerMenuLeading extends StatelessWidget {
  const SeekerMenuLeading({super.key});

  static double widthFor(BuildContext context) {
    return Navigator.of(context).canPop() ? 104 : 56;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPop)
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        IconButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ],
    );
  }
}

/// Standard “hamburger” drawer: account, navigation, offline queue + sync (same pattern as the
/// reference Flutter template), diagnostics and sign-out.
///
/// Named routes must be registered on [MaterialApp] (see `main.dart`): `/seeker/dashboard`,
/// `/seeker/new-request`, `/seeker/pack`, `/seeker/track`, `/seeker/preloss`.
class SeekerDrawer extends StatelessWidget {
  const SeekerDrawer({
    super.key,
    this.section = SeekerDrawerSection.submitRequest,
  });

  final SeekerDrawerSection section;

  static int _pendingTotal() {
    return OfflineStorageService.pendingQueueTotalCount;
  }

  static Future<void> _syncNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final n = await PendingSync.flushAll();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n > 0 ? 'Sent $n queued offline item(s).' : 'Nothing to sync or still offline.',
        ),
      ),
    );
  }

  static Future<void> _signOut(BuildContext context) async {
    await SessionStore.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
      (r) => false,
    );
  }

  void _closeDrawerThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) action();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = SessionStore.userName ?? 'Seeker';
    final email = SessionStore.userEmail ?? '';
    final pending = _pendingTotal();
    final docQ = OfflineStorageService.pendingDocumentSubmissionCount;
    final chatQ = OfflineStorageService.getPendingChatSends().length;
    final preQ = OfflineStorageService.getPendingPrelossUploads().length;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.35)),
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Document Seeker',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  const SizedBox(height: 8),
                  if (pending > 0)
                    Chip(
                      avatar: const Icon(Icons.cloud_queue, size: 18),
                      label: Text('$pending offline'),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Text(
                      'All changes synced',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (pending > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Queued: $docQ document request(s), $chatQ chat message(s), $preQ pre-loss file(s).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: FilledButton.tonalIcon(
                  onPressed: () => _closeDrawerThen(context, () => _syncNow(context)),
                  icon: const Icon(Icons.cloud_sync),
                  label: const Text('Sync offline queue now'),
                ),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Home / Dashboard'),
              selected: section == SeekerDrawerSection.dashboard,
              onTap: () => _closeDrawerThen(context, () {
                if (section != SeekerDrawerSection.dashboard) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/seeker/dashboard',
                    (route) => false,
                  );
                }
              }),
            ),
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('Submit document request'),
              selected: section == SeekerDrawerSection.submitRequest,
              onTap: () => _closeDrawerThen(context, () {
                if (section != SeekerDrawerSection.submitRequest) {
                  Navigator.of(context).pushNamed('/seeker/new-request');
                }
              }),
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Tshijuka Pack'),
              selected: section == SeekerDrawerSection.pack,
              onTap: () => _closeDrawerThen(context, () {
                if (section != SeekerDrawerSection.pack) {
                  Navigator.of(context).pushNamed('/seeker/pack');
                }
              }),
            ),
            ListTile(
              leading: const Icon(Icons.track_changes_outlined),
              title: const Text('Track progress'),
              selected: section == SeekerDrawerSection.track,
              onTap: () => _closeDrawerThen(context, () {
                if (section != SeekerDrawerSection.track) {
                  Navigator.of(context).pushNamed('/seeker/track');
                }
              }),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Upload & protect'),
              selected: section == SeekerDrawerSection.preloss,
              onTap: () => _closeDrawerThen(context, () {
                if (section != SeekerDrawerSection.preloss) {
                  Navigator.of(context).pushNamed('/seeker/preloss');
                }
              }),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Connection diagnostics'),
              subtitle: const Text('For support / troubleshooting'),
              onTap: () => _closeDrawerThen(context, () {
                showConnectionDiagnosticsSheet(context);
              }),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text('Sign out', style: TextStyle(color: scheme.error)),
              onTap: () => _closeDrawerThen(context, () => _signOut(context)),
            ),
          ],
        ),
      ),
    );
  }
}
