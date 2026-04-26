import 'package:flutter/material.dart';

import 'legal_policies.dart';

enum LegalDocumentKind { terms, privacy }

/// Full-screen legal reader with Back (same idea as web terms/privacy pages).
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = kind == LegalDocumentKind.terms
        ? 'Terms of Service'
        : 'Privacy Policy';
    final intro =
        kind == LegalDocumentKind.terms ? LegalPolicies.termsIntro : LegalPolicies.privacyIntro;
    final body =
        kind == LegalDocumentKind.terms ? LegalPolicies.termsBody : LegalPolicies.privacyBody;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SelectableText.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                        color: scheme.onSurface,
                      ),
                  children: [
                    TextSpan(
                      text: intro,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                    ),
                    const TextSpan(text: '\n\n'),
                    TextSpan(text: body.trim()),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
