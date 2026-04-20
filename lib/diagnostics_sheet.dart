import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_config.dart';
import 'api_service.dart';

/// Advanced troubleshooting (not shown on primary sign-in / sign-up flows).
/// Material pattern: optional “Help” content for support staff or power users.
void showConnectionDiagnosticsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Connection diagnostics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Technical details for troubleshooting. If something fails to load, share this screen with support.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Text('Service URL', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(ApiConfig.baseUrl),
              const SizedBox(height: 12),
              Text('Health check', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                ApiConfig.rootIndexUrl,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                future: ApiService.fetchApiRoot(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    );
                  }
                  if (snapshot.hasData) {
                    return SelectableText(
                      const JsonEncoder.withIndent('  ').convert(snapshot.data),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.35,
                          ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
