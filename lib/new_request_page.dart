import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import 'ds_text_styles.dart';
import 'camera_capture_page.dart';
import 'ghana_momo.dart';
import 'notification_service.dart';
import 'offline_storage.dart';
import 'paystack_webview_page.dart';
import 'pending_sync.dart';
import 'session_store.dart';
import 'storyline_helpers.dart';
import 'seeker_drawer.dart';
import 'submit_draft_store.dart';
import 'track_progress_page.dart';

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key});

  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

int? _intOrNull(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

class _DocumentRowInput {
  _DocumentRowInput({this.typeId});
  final locationCtrl = TextEditingController();
  final yearsCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  int? typeId;
  List<String> filePaths = [];

  void dispose() {
    locationCtrl.dispose();
    yearsCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

class _NewRequestPageState extends State<NewRequestPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: SessionStore.userName ?? '');
  final _emailCtrl = TextEditingController(text: SessionStore.userEmail ?? '');
  final _paymentAmount = TextEditingController(text: '50.00');

  List<Map<String, dynamic>> _issuers = [];
  List<Map<String, dynamic>> _types = [];
  int? _issuerId;
  List<_DocumentRowInput> _rows = [];
  bool _loadingMeta = true;
  bool _submitting = false;
  bool _consent = false;
  bool _enablePayment = false;
  bool _paying = false;
  bool _paymentVerified = false;
  String? _paymentReference;
  String? _paymentStatus;
  String? _error;
  List<String> _submittedIds = [];
  List<Map<String, dynamic>> _savedIds = [];

  final _momoCtrl = TextEditingController();
  GhanaMomoProvider _momoProvider = GhanaMomoProvider.mtn;
  StorylineLocation? _locale;
  Timer? _draftTimer;
  bool _draftWired = false;
  late String _trackingRef;
  /// True after Paystack is opened until user verifies or dismisses return hint.
  bool _awaitingPaymentReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackingRef = const Uuid().v4();
    _rows = [_DocumentRowInput()];
    _savedIds = OfflineStorageService.getSavedDocumentIds();
    _loadMeta();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _momoCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _paymentAmount.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_awaitingPaymentReturn) return;
    if (!_enablePayment || _paymentReference == null || _paymentReference!.isEmpty) return;
    if (_paymentVerified) return;
    _awaitingPaymentReturn = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'You’re back on the form — tap “Verify payment” when Paystack shows success.',
          ),
        ),
      );
    });
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
    });
    try {
      final issuers = await ApiService.fetchIssuers();
      final types = await ApiService.fetchDocumentTypes();
      if (!mounted) return;
      setState(() {
        _issuers = issuers;
        _types = types;
        _loadingMeta = false;
        if (_issuerId == null && issuers.isNotEmpty) {
          _issuerId = _intOrNull(issuers.first['issuerUserId']);
        }
        if (_rows.first.typeId == null && types.isNotEmpty) {
          _rows.first.typeId = _intOrNull(types.first['id']);
        }
      });
      await OfflineStorageService.saveCachedMetaSnapshot(
        issuersJson: jsonEncode(issuers),
        typesJson: jsonEncode(types),
      );
      await _restoreDraft();
      if (!mounted) return;
      _ensureDraftWiring();
      unawaited(_refreshLocale());
    } catch (e) {
      final issuersRaw = OfflineStorageService.getCachedIssuersJson();
      final typesRaw = OfflineStorageService.getCachedTypesJson();
      List<Map<String, dynamic>>? cachedIssuers;
      List<Map<String, dynamic>>? cachedTypes;
      if (issuersRaw != null && typesRaw != null) {
        try {
          final di = jsonDecode(issuersRaw);
          final dt = jsonDecode(typesRaw);
          if (di is List && dt is List) {
            cachedIssuers = di
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            cachedTypes = dt
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        } catch (_) {}
      }
      if (!mounted) return;
      if (cachedIssuers != null &&
          cachedTypes != null &&
          cachedIssuers.isNotEmpty &&
          cachedTypes.isNotEmpty) {
        setState(() {
          _issuers = cachedIssuers!;
          _types = cachedTypes!;
          _loadingMeta = false;
          _error =
              'Using last saved institutions and document types (offline or connection issue). '
              '${e.toString().replaceFirst('Exception: ', '')}';
          if (_issuerId == null && _issuers.isNotEmpty) {
            _issuerId = _intOrNull(_issuers.first['issuerUserId']);
          }
          if (_rows.first.typeId == null && _types.isNotEmpty) {
            _rows.first.typeId = _intOrNull(_types.first['id']);
          }
        });
        await _restoreDraft();
        if (!mounted) return;
        _ensureDraftWiring();
        unawaited(_refreshLocale());
      } else {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loadingMeta = false;
        });
      }
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 650), _saveDraft);
  }

  void _ensureDraftWiring() {
    if (_draftWired) return;
    _draftWired = true;
    void bump() => _scheduleDraftSave();
    _nameCtrl.addListener(bump);
    _emailCtrl.addListener(bump);
    _paymentAmount.addListener(bump);
    _momoCtrl.addListener(bump);
    for (final row in _rows) {
      row.locationCtrl.addListener(bump);
      row.yearsCtrl.addListener(bump);
      row.descriptionCtrl.addListener(bump);
    }
  }

  void _rewireDraftListenersForRows() {
    if (!_draftWired) return;
    void bump() => _scheduleDraftSave();
    for (final row in _rows) {
      row.locationCtrl.addListener(bump);
      row.yearsCtrl.addListener(bump);
      row.descriptionCtrl.addListener(bump);
    }
  }

  Future<void> _saveDraft() async {
    try {
      final rows = <Map<String, dynamic>>[];
      for (final row in _rows) {
        rows.add({
          'typeId': row.typeId,
          'location': row.locationCtrl.text,
          'years': row.yearsCtrl.text,
          'description': row.descriptionCtrl.text,
          'files': row.filePaths,
        });
      }
      final map = {
        'trackingRef': _trackingRef,
        'name': _nameCtrl.text,
        'email': _emailCtrl.text,
        'issuerId': _issuerId,
        'enablePayment': _enablePayment,
        'paymentAmount': _paymentAmount.text,
        'momo': _momoCtrl.text,
        'momoProvider': _momoProvider.name,
        'consent': _consent,
        'rows': rows,
      };
      await SubmitDraftStore.saveJson(jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _restoreDraft() async {
    final map = await SubmitDraftStore.loadMap();
    if (map == null || !mounted) return;
    final tr = map['trackingRef']?.toString();
    final issuer = _intOrNull(map['issuerId']);
    final rowsRaw = map['rows'];
    if (tr != null && tr.isNotEmpty) _trackingRef = tr;

    final newRows = <_DocumentRowInput>[];
    if (rowsRaw is List && rowsRaw.isNotEmpty) {
      for (final e in rowsRaw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final r = _DocumentRowInput(typeId: _intOrNull(m['typeId']));
        r.locationCtrl.text = m['location']?.toString() ?? '';
        r.yearsCtrl.text = m['years']?.toString() ?? '';
        r.descriptionCtrl.text = m['description']?.toString() ?? '';
        final files = m['files'];
        if (files is List) {
          r.filePaths = files.map((x) => x.toString()).where((p) => p.isNotEmpty).toList();
        }
        newRows.add(r);
      }
    }

    if (!mounted) return;
    setState(() {
      _nameCtrl.text = map['name']?.toString() ?? _nameCtrl.text;
      _emailCtrl.text = map['email']?.toString() ?? _emailCtrl.text;
      _enablePayment = map['enablePayment'] == true;
      _paymentAmount.text = map['paymentAmount']?.toString() ?? _paymentAmount.text;
      _momoCtrl.text = map['momo']?.toString() ?? '';
      _consent = map['consent'] == true;
      final pName = map['momoProvider']?.toString();
      if (pName != null) {
        for (final v in GhanaMomoProvider.values) {
          if (v.name == pName) _momoProvider = v;
        }
      }
      if (issuer != null && _issuers.any((e) => _intOrNull(e['issuerUserId']) == issuer)) {
        _issuerId = issuer;
      }
      if (newRows.isNotEmpty) {
        for (final old in _rows) {
          old.dispose();
        }
        _rows = newRows;
        for (final r in _rows) {
          if (r.typeId != null && !_types.any((t) => _intOrNull(t['id']) == r.typeId)) {
            r.typeId = _types.isNotEmpty ? _intOrNull(_types.first['id']) : null;
          }
        }
        _rewireDraftListenersForRows();
      }
    });
  }

  Future<void> _refreshLocale() async {
    final loc = await StorylineHelpers.detectLocation();
    if (!mounted) return;
    setState(() => _locale = loc);
  }

  String _composeDescription(_DocumentRowInput row) {
    final y = row.yearsCtrl.text.trim();
    final d = row.descriptionCtrl.text.trim();
    if (y.isEmpty) return d;
    return 'Years in memory: $y\n\n$d';
  }

  Future<void> _applyCompressedPaths(int index, List<String> paths) async {
    final out = <String>[];
    for (final p in paths) {
      final c = await StorylineHelpers.compressImageIfNeeded(p);
      out.add(c);
    }
    if (!mounted) return;
    setState(() => _rows[index].filePaths = out);
    _scheduleDraftSave();
  }

  Future<void> _attachEvidence(int index) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Capture with camera (best for documents)'),
                subtitle: const Text('Full-screen camera with flash and steady capture'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openCameraCapture(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickGallery(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Pick files (PDF / images)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFiles(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCameraCapture(int index) async {
    if (kIsWeb) {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92);
      if (x == null) return;
      await _applyCompressedPaths(index, [x.path]);
      return;
    }
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );
    if (path == null || path.isEmpty) return;
    await _applyCompressedPaths(index, [path]);
  }

  Future<void> _pickGallery(int index) async {
    if (kIsWeb) {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (x == null) return;
      await _applyCompressedPaths(index, [x.path]);
      return;
    }
    final imgs = await ImagePicker().pickMultiImage(imageQuality: 92);
    if (imgs.isEmpty) return;
    await _applyCompressedPaths(index, imgs.map((e) => e.path).toList());
  }

  void _addRow() {
    setState(() {
      _rows.add(_DocumentRowInput(typeId: _types.isNotEmpty ? _intOrNull(_types.first['id']) : null));
    });
    _rewireDraftListenersForRows();
    _scheduleDraftSave();
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
    _scheduleDraftSave();
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
    for (final p in paths) {
      final lower = p.toLowerCase();
      if (lower.endsWith('.pdf')) {
        out.add(p);
      } else {
        out.add(await StorylineHelpers.compressImageIfNeeded(p));
      }
    }
    if (!mounted) return;
    setState(() => _rows[index].filePaths = out);
    _scheduleDraftSave();
  }

  Future<void> _beginPaymentFlow() async {
    final email = _emailCtrl.text.trim();
    final userId = SessionStore.userId ?? 0;
    final amount = double.tryParse(_paymentAmount.text.trim()) ?? 0;
    if (email.isEmpty || !email.contains('@')) {
      await StorylineHelpers.pulseWarning();
      setState(() => _error = 'Please enter a valid email first.');
      return;
    }
    if (userId <= 0) {
      await StorylineHelpers.pulseWarning();
      setState(() => _error = 'Missing user session. Please log in again.');
      return;
    }
    if (amount <= 0) {
      await StorylineHelpers.pulseWarning();
      setState(() => _error = 'Enter a valid payment amount.');
      return;
    }
    final inGhana = _locale?.inGhana ?? false;
    final momoCheck = GhanaMomo.validateMomoNumber(
      raw: _momoCtrl.text,
      provider: _momoProvider,
      inGhana: inGhana,
    );
    if (!momoCheck.ok) {
      await StorylineHelpers.pulseWarning();
      setState(() => _error = momoCheck.message);
      return;
    }
    if (!mounted) return;
    final docLine = _submittedIds.isEmpty
        ? 'Local request reference: $_trackingRef\n(Server document IDs appear after you submit.)'
        : 'Document request ID(s):\n${_submittedIds.join('\n')}';
    final locLine = _locale == null ? 'Location: not detected' : 'Detected location: ${_locale!.label}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Paystack payment'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: ${amount.toStringAsFixed(2)} GHS'),
                const SizedBox(height: 8),
                Text('Mobile money number:\n${momoCheck.formatted}'),
                const SizedBox(height: 8),
                Text('Provider: ${GhanaMomo.label(_momoProvider)}'),
                const SizedBox(height: 8),
                Text(locLine),
                const SizedBox(height: 8),
                Text(docLine),
                const SizedBox(height: 12),
                Text(
                  'Paystack opens in the app. When you finish paying, you return to this form automatically '
                  'and payment is confirmed — same idea as the website popup.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _payNow();
  }

  Future<void> _payNow() async {
    final email = _emailCtrl.text.trim();
    final userId = SessionStore.userId ?? 0;
    final amount = double.tryParse(_paymentAmount.text.trim()) ?? 0;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email first.');
      return;
    }
    if (userId <= 0) {
      setState(() => _error = 'Missing user session. Please log in again.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Enter a valid payment amount.');
      return;
    }
    setState(() {
      _paying = true;
      _paymentStatus = 'Initializing payment...';
      _error = null;
    });
    try {
      final init = await ApiService.initializeRetrievalPayment(
        amount: amount,
        email: email,
        userId: userId,
      );
      if (init['status']?.toString() != 'success') {
        throw Exception(init['message']?.toString() ?? 'Payment initialization failed.');
      }
      final reference = init['reference']?.toString() ?? '';
      final authorizationUrl = init['authorization_url']?.toString() ?? '';
      if (reference.isEmpty || authorizationUrl.isEmpty) {
        throw Exception('Missing payment reference or authorization URL.');
      }
      _paymentReference = reference;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (!mounted) return;
        final backRef = await Navigator.of(context).push<String>(
          MaterialPageRoute<String>(
            fullscreenDialog: true,
            builder: (_) => PaystackWebViewPage(
              authorizationUrl: authorizationUrl,
              expectedReference: reference,
            ),
          ),
        );
        if (!mounted) return;
        if (backRef != null && backRef.trim().isNotEmpty) {
          setState(() {
            _paymentReference = backRef.trim();
            _awaitingPaymentReturn = false;
          });
          await _verifyPayment();
        } else {
          setState(() {
            _awaitingPaymentReturn = false;
            _paymentStatus =
                'Payment was not completed in the window. Tap Pay again, or “Verify payment” if you already paid.';
          });
        }
      } else {
        final uri = Uri.parse(authorizationUrl);
        var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
        if (!ok) throw Exception('Could not open Paystack payment page.');
        if (!mounted) return;
        setState(() {
          _awaitingPaymentReturn = true;
          _paymentStatus =
              'Complete payment in your browser, then return here and tap “Verify payment”.';
        });
        await StorylineHelpers.pulseSuccess();
      }
    } catch (e) {
      await StorylineHelpers.pulseWarning();
      if (!mounted) return;
      setState(() => _paymentStatus = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _verifyPayment() async {
    final ref = _paymentReference;
    if (ref == null || ref.isEmpty) return;
    setState(() {
      _paying = true;
      _paymentStatus = 'Verifying payment...';
    });
    try {
      final data = await ApiService.verifyRetrievalPayment(ref);
      if (data['status']?.toString() != 'success') {
        throw Exception(data['message']?.toString() ?? 'Payment verification failed.');
      }
      if (!mounted) return;
      setState(() {
        _paymentVerified = true;
        _awaitingPaymentReturn = false;
        _paymentStatus = 'Payment verified successfully.';
      });
      if (!kIsWeb) {
        await NotificationService.instance.showLocalAlert(
          title: 'Payment verified',
          body: 'Your retrieval fee was received and linked to your session.',
        );
      } else {
        await StorylineHelpers.pulseSuccess();
      }
    } catch (e) {
      await StorylineHelpers.pulseWarning();
      if (!mounted) return;
      setState(() {
        _paymentVerified = false;
        _paymentStatus = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_issuerId == null) {
      setState(() => _error = 'Select an issuing institution.');
      return;
    }
    if (!_consent) {
      setState(() => _error = 'You must accept Terms and Privacy to submit.');
      return;
    }
    for (final row in _rows) {
      if (row.typeId == null ||
          row.locationCtrl.text.trim().isEmpty ||
          (row.descriptionCtrl.text.trim().isEmpty && row.yearsCtrl.text.trim().isEmpty)) {
        setState(() => _error = 'Fill all document rows (type, school, years and/or description).');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
      _submittedIds = [];
    });

    final submitted = <String>[];
    try {
      for (final row in _rows) {
        final files = row.filePaths.isEmpty ? <String?>[null] : row.filePaths.map((e) => e as String?).toList();
        for (final p in files) {
          final docId = await ApiService.submitDocument(
            issuerUserId: _issuerId!,
            typeId: row.typeId!,
            description: _composeDescription(row),
            location: row.locationCtrl.text.trim(),
            attachment: p == null ? null : File(p),
            paymentReference: _paymentReference,
          );
          if (docId.isNotEmpty) {
            submitted.add(docId);
            await OfflineStorageService.addSavedDocumentId(
              documentId: docId,
              description: _composeDescription(row),
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _submittedIds = submitted;
        _savedIds = OfflineStorageService.getSavedDocumentIds();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submitted.length > 1
                ? '${submitted.length} documents submitted successfully.'
                : 'Document submitted successfully.',
          ),
        ),
      );
      if (!kIsWeb) {
        await NotificationService.instance.notifyDocumentRequestSubmitted(documentIds: submitted);
      } else {
        await StorylineHelpers.pulseSuccess();
      }
      await SubmitDraftStore.clear();
    } catch (e) {
      if (!kIsWeb && PendingSync.isLikelyNetworkFailure(e)) {
        for (final row in _rows) {
          final paths = row.filePaths.isEmpty
              ? <String?>[null]
              : row.filePaths.map((e) => e as String?).toList();
          for (final p in paths) {
            await PendingSync.enqueueDocumentSubmission(
              issuerUserId: _issuerId!,
              typeId: row.typeId!,
              description: _composeDescription(row),
              location: row.locationCtrl.text.trim(),
              localAttachmentPath: p,
              paymentReference: _paymentReference,
            );
          }
        }
        if (!mounted) return;
        setState(() {
          _error = 'Could not reach server. Requests queued and will sync when online.';
        });
        await NotificationService.instance.notifyDocumentRequestQueued();
        await SubmitDraftStore.clear();
      } else {
        if (!mounted) return;
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copyId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Document ID copied: $id')),
    );
  }

  Future<void> _copyAllSubmittedIds() async {
    if (_submittedIds.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _submittedIds.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_submittedIds.length} ID(s).')),
    );
  }

  Future<void> _clearSavedIds() async {
    await OfflineStorageService.clearSavedDocumentIds();
    if (!mounted) return;
    setState(() => _savedIds = []);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offlinePending = OfflineStorageService.pendingQueueTotalCount;
    return Scaffold(
      drawer: const SeekerDrawer(section: SeekerDrawerSection.submitRequest),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: SeekerMenuLeading.widthFor(context),
        leading: const SeekerMenuLeading(),
        title: const Text('Submit document request'),
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
            tooltip: 'Refresh form options',
            onPressed: _loadingMeta || _submitting ? null : _loadMeta,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMeta,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Your Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Your Email'),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Valid email required' : null,
                    ),
                    if (_locale != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.place_outlined, size: 18),
                              label: Text('Detected: ${_locale!.label}'),
                            ),
                            if (_locale!.inGhana)
                              const Chip(
                                avatar: Icon(Icons.payments_outlined, size: 18),
                                label: Text('Ghana context — GHS & local MoMo'),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _issuerId,
                      decoration: const InputDecoration(
                        labelText: 'Select your issueing Institution or content creator',
                      ),
                      items: _issuers
                          .map((e) {
                            final uid = _intOrNull(e['issuerUserId']);
                            if (uid == null || uid == 0) return null;
                            return DropdownMenuItem<int>(
                              value: uid,
                              child: Text(e['documentIssuerName']?.toString() ?? 'Issuer'),
                            );
                          })
                          .whereType<DropdownMenuItem<int>>()
                          .toList(),
                      onChanged: (v) {
                        setState(() => _issuerId = v);
                        _scheduleDraftSave();
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Documents to request',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        OutlinedButton(
                          onPressed: _addRow,
                          child: const Text('+ Add another document'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(_rows.length, (i) {
                      final row = _rows[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              DropdownButtonFormField<int>(
                                initialValue: row.typeId,
                                decoration:
                                    const InputDecoration(labelText: 'Select document type'),
                                items: _types
                                    .map((e) {
                                      final tid = _intOrNull(e['id']);
                                      if (tid == null) return null;
                                      return DropdownMenuItem<int>(
                                        value: tid,
                                        child: Text(e['name']?.toString() ?? 'Type'),
                                      );
                                    })
                                    .whereType<DropdownMenuItem<int>>()
                                    .toList(),
                                onChanged: (v) {
                                  setState(() => row.typeId = v);
                                  _scheduleDraftSave();
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: row.locationCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'School (where this record belongs)',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: row.yearsCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Years you remember (optional if you describe below)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: row.descriptionCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Additional details about the document',
                                ),
                                validator: (v) {
                                  final d = (v ?? '').trim();
                                  final y = row.yearsCtrl.text.trim();
                                  if (d.isEmpty && y.isEmpty) {
                                    return 'Enter years and/or details';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!kIsWeb)
                                    FilledButton.icon(
                                      onPressed: () => _openCameraCapture(i),
                                      icon: const Icon(Icons.photo_camera_outlined),
                                      label: const Text('Take photo'),
                                    ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _attachEvidence(i),
                                    icon: const Icon(Icons.add_photo_alternate_outlined),
                                    label: const Text('Add photos or files'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _pickFiles(i),
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Files only'),
                                  ),
                                  if (_rows.length > 1)
                                    TextButton(
                                      onPressed: () => _removeRow(i),
                                      child: const Text('Remove row'),
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
                    if (_savedIds.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Your saved document IDs',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ..._savedIds.take(8).map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${e['id']}  (${e['description'] ?? ''})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _copyId(e['id']?.toString() ?? ''),
                                        child: const Text('Copy'),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          final id = e['id']?.toString() ?? '';
                                          Navigator.of(context).push<void>(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  TrackProgressPage(initialDocumentId: id),
                                            ),
                                          );
                                        },
                                        child: const Text('Track'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _clearSavedIds,
                                  child: const Text('Clear all'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _enablePayment,
                              onChanged: (v) {
                                setState(() => _enablePayment = v);
                                _scheduleDraftSave();
                              },
                              title: const Text('Pay Retrieval Fee (Optional)'),
                            ),
                            if (_enablePayment) ...[
                              TextFormField(
                                controller: _paymentAmount,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Retrieval Fee Amount (GHS)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<GhanaMomoProvider>(
                                initialValue: _momoProvider,
                                decoration: const InputDecoration(
                                  labelText: 'Mobile money provider',
                                ),
                                items: GhanaMomo.providersForContext(inGhana: _locale?.inGhana ?? false)
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(GhanaMomo.label(p)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _momoProvider = v);
                                  _scheduleDraftSave();
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _momoCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Mobile money number',
                                  hintText: 'e.g. 024XXXXXXX',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: _paying || _paymentVerified ? null : _beginPaymentFlow,
                                    child: Text(_paymentVerified ? 'Payment completed' : 'Pay now'),
                                  ),
                                  OutlinedButton(
                                    onPressed: (_paying || _paymentReference == null) ? null : _verifyPayment,
                                    child: const Text('Verify payment'),
                                  ),
                                ],
                              ),
                              if (_paymentReference != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: SelectableText('Reference: $_paymentReference'),
                                ),
                              if (_paymentStatus != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_paymentStatus!),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _consent,
                      onChanged: (v) {
                        setState(() => _consent = v ?? false);
                        _scheduleDraftSave();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I have read and accept the Terms of Service and Privacy Policy.',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: context.dsErrorMessage()),
                    ],
                    if (_submittedIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.green.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _submittedIds.length > 1
                                    ? '✓ ${_submittedIds.length} documents submitted successfully'
                                    : '✓ Document submitted successfully',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Track status anytime from here — no need to go back to the menu.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final mono = Theme.of(context).textTheme.labelMedium?.copyWith(
                                        fontFamily: 'monospace',
                                        letterSpacing: -0.2,
                                        height: 1.15,
                                      );
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (var i = 0; i < _submittedIds.length; i++) ...[
                                            if (i > 0)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text(
                                                  '·',
                                                  style: mono?.copyWith(
                                                    color: scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            SelectableText(
                                              _submittedIds[i],
                                              style: mono,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) => TrackProgressPage(
                                            initialDocumentId: _submittedIds.first,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.track_changes_outlined, size: 18),
                                    label: Text(
                                      _submittedIds.length == 1
                                          ? 'Track'
                                          : 'Track first',
                                    ),
                                  ),
                                  if (_submittedIds.length > 1)
                                    MenuAnchor(
                                      builder: (context, controller, child) {
                                        return OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          onPressed: () {
                                            if (controller.isOpen) {
                                              controller.close();
                                            } else {
                                              controller.open();
                                            }
                                          },
                                          icon: const Icon(Icons.more_horiz, size: 18),
                                          label: const Text('Track…'),
                                        );
                                      },
                                      menuChildren: [
                                        for (final id in _submittedIds)
                                          MenuItemButton(
                                            onPressed: () {
                                              Navigator.of(context).push<void>(
                                                MaterialPageRoute<void>(
                                                  builder: (_) => TrackProgressPage(initialDocumentId: id),
                                                ),
                                              );
                                            },
                                            child: Text(id, style: context.dsIdMenuLiteral()),
                                          ),
                                      ],
                                    ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onPressed: _copyAllSubmittedIds,
                                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                                    label: Text(_submittedIds.length == 1 ? 'Copy ID' : 'Copy all'),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => setState(() => _submittedIds = []),
                                  child: const Text('Dismiss'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: (_submitting || _issuers.isEmpty) ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit Document'),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
