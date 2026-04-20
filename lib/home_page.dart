import 'package:flutter/material.dart';

import 'login_page.dart';
import 'register_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(28, top + 16, 28, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        Align(
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.description_rounded,
                              size: 52,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Tshijuka RDP',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Document Seeker',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Request and track official documents from issuing institutions — the same account as the web portal.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            height: 1.55,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 100),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                            );
                          },
                          child: const Text('Sign in'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                            );
                          },
                          child: const Text('Create an account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: top + 4,
              right: 4,
              child: Material(
                color: scheme.surface.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Refresh',
                  onPressed: _onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
