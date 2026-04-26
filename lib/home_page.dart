import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';
import 'app_theme.dart';
import 'ds_text_styles.dart';
import 'legal_document_page.dart';
import 'login_page.dart';
import 'register_page.dart';

/// Pre-auth entry: Material 3 mobile layout, seeker-focused copy, brand accents.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() {});
  }

  Future<void> _openAbout() async {
    final uri = Uri.parse('${ApiConfig.webSiteBase}/index.php?controller=Page&action=about');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the about page.')),
      );
    }
  }

  void _goLogin() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
  }

  void _goRegister() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Document Seeker'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TshijukaBranding.navRedLight, TshijukaBranding.navRedDark],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'about':
                  _openAbout();
                case 'login':
                  _goLogin();
                case 'signup':
                  _goRegister();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('About')),
              PopupMenuItem(value: 'login', child: Text('Log in')),
              PopupMenuItem(value: 'signup', child: Text('Create account')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome', style: context.dsWelcomeOverline()),
              const SizedBox(height: 4),
              Text('Document Seeker', style: context.dsWelcomeHeadline()),
              const SizedBox(height: 8),
              Text(
                'Request official copies from issuers, upload what they need, and follow your case in one place.',
                style: context.dsWelcomeSupporting(),
              ),
              const SizedBox(height: 20),
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get started',
                        style: textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the same email and password as the Tshijuka RDP website.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.92),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _goLogin,
                        child: const Text('Log in'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _goRegister,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onPrimaryContainer,
                          side: BorderSide(color: scheme.onPrimaryContainer.withValues(alpha: 0.5)),
                        ),
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('In this app', style: context.dsSectionHeading()),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: const Icon(Icons.upload_file_outlined),
                      ),
                      title: const Text('Submit requests'),
                      subtitle: const Text(
                        'Start a request and attach files your issuer needs.',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: const Icon(Icons.timeline_outlined),
                      ),
                      title: const Text('Track status'),
                      subtitle: const Text(
                        'See updates as your issuer works on your documents.',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      ),
                      title: const Text('Chat with your issuer'),
                      subtitle: const Text(
                        'Message the organisation handling your request when they allow it.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tshijuka RDP',
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Same account as on the website.',
                textAlign: TextAlign.center,
                style: context.dsBodyMuted(),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 0,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const LegalDocumentPage(kind: LegalDocumentKind.terms),
                        ),
                      );
                    },
                    child: const Text('Terms of Service'),
                  ),
                  Text('·', style: textTheme.bodySmall?.copyWith(color: scheme.outline)),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const LegalDocumentPage(kind: LegalDocumentKind.privacy),
                        ),
                      );
                    },
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
