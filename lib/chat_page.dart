import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'pending_sync.dart';

/// Seeker ↔ issuer chat for one document — same data as web `ChatController` + `chat_action.php`.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.documentId});

  final String documentId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _issuerName = '';
  List<Map<String, dynamic>> _messages = [];
  Timer? _poll;
  int _silentFailStreak = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scroll.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(max);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final thread = await ApiService.fetchChatThread(widget.documentId);
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _issuerName = thread.issuerName.trim();
        if (!silent) _loading = false;
        _silentFailStreak = 0;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (silent) {
        _silentFailStreak++;
        if (_silentFailStreak >= 3 && msg.toLowerCase().contains('auth')) {
          setState(() => _error = msg);
        }
      } else {
        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > 2000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is too long (max 2000 characters).')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService.sendChatMessage(widget.documentId, text);
      if (!mounted) return;
      _msgCtrl.clear();
      await _load(silent: true);
    } catch (e) {
      if (PendingSync.isLikelyNetworkFailure(e)) {
        await PendingSync.enqueueChatSend(
          documentId: widget.documentId,
          message: text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline: message queued and will send when online.'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      return DateFormat.yMMMd().add_jm().format(DateTime.parse(ts));
    } catch (_) {
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleInst = _issuerName.isNotEmpty ? _issuerName : 'Institution';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chat · $titleInst'),
            Text(
              widget.documentId,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.75),
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: _loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 120),
                      children: const [
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                            Center(child: Text(_error!)),
                          ],
                        )
                      : _messages.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              children: [
                                SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                                Center(
                                  child: Text(
                                    'No messages yet. Say hello!',
                                    style: TextStyle(color: scheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: _messages.length,
                              itemBuilder: (c, i) {
                                final m = _messages[i];
                                final rawMe = m['isMe'];
                                final me = rawMe == true || rawMe == 1 || rawMe == '1';
                                return Align(
                                  alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                                    ),
                                    decoration: BoxDecoration(
                                      color: me ? scheme.primary : scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['userName']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: me ? scheme.onPrimary : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m['message']?.toString() ?? '',
                                          style: TextStyle(
                                            color: me ? scheme.onPrimary : scheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _time(m['timestamp']?.toString()),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: me
                                                ? scheme.onPrimary.withValues(alpha: 0.85)
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
          Material(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                        counterText: '',
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
