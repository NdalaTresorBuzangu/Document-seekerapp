import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosted Paystack checkout inside the app. When Paystack redirects to our
/// `payment_paystack_return.php` callback, we **intercept** that navigation,
/// close this route, and return the reference — so the user never sees the
/// intermediate HTML page (same outcome as the web popup flow).
class PaystackWebViewPage extends StatefulWidget {
  const PaystackWebViewPage({
    super.key,
    required this.authorizationUrl,
    required this.expectedReference,
  });

  final String authorizationUrl;
  final String expectedReference;

  @override
  State<PaystackWebViewPage> createState() => _PaystackWebViewPageState();
}

class _PaystackWebViewPageState extends State<PaystackWebViewPage> {
  late final WebViewController _controller;
  var _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (!request.isMainFrame) {
              return NavigationDecision.navigate;
            }
            if (_isServerReturnUrl(request.url)) {
              _popWithReferenceFrom(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (_isServerReturnUrl(url)) {
              _popWithReferenceFrom(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  bool _isServerReturnUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('payment_paystack_return.php') ||
        lower.contains('verify_payment.php');
  }

  String? _referenceFromUrl(String url) {
    try {
      final u = Uri.parse(url);
      final r = u.queryParameters['reference']?.trim();
      if (r != null && r.isNotEmpty) return r;
      final t = u.queryParameters['trxref']?.trim();
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    return null;
  }

  void _popWithReferenceFrom(String url) {
    if (_popped || !mounted) return;
    _popped = true;
    final ref = _referenceFromUrl(url) ?? widget.expectedReference;
    Navigator.of(context).pop(ref);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay with Paystack'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () {
            if (_popped) return;
            _popped = true;
            Navigator.of(context).pop();
          },
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
