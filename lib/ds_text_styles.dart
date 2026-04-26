import 'package:flutter/material.dart';

/// Semantic combinations of [TextTheme] + [ColorScheme] for Document Seeker.
///
/// Prefer these (or [Theme.of] text roles directly) instead of one-off [TextStyle]s.
extension DocumentSeekerText on BuildContext {
  TextTheme get _t => Theme.of(this).textTheme;
  ColorScheme get _c => Theme.of(this).colorScheme;

  /// Small caps–style line above the main welcome (e.g. “Welcome”).
  TextStyle dsWelcomeOverline() => _t.labelLarge!.copyWith(
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
        color: _c.primary,
        height: 1.2,
      );

  /// Primary welcome line (e.g. “Document Seeker”).
  TextStyle dsWelcomeHeadline() => _t.headlineMedium!.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
        height: 1.2,
        color: _c.onSurface,
      );

  /// Supporting line under the welcome headline.
  TextStyle dsWelcomeSupporting() => _t.bodyLarge!.copyWith(
        color: _c.onSurfaceVariant,
        height: 1.5,
        fontWeight: FontWeight.w400,
      );

  /// Section headers on scrollable screens (“In this app”, “Recovery tools”).
  TextStyle dsSectionHeading() => _t.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.12,
        height: 1.3,
        color: _c.onSurface,
      );

  /// Card / panel titles on [surface] (not primaryContainer).
  TextStyle dsPanelTitle() => _t.titleLarge!.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: _c.onSurface,
      );

  /// Emphasized title using brand primary (dashboard, tool cards).
  TextStyle dsEmphasisTitle() => _t.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: _c.primary,
      );

  /// Muted supporting paragraph.
  TextStyle dsBodyMuted() => _t.bodySmall!.copyWith(
        color: _c.onSurfaceVariant,
        height: 1.4,
      );

  /// List feature lines / bullets in dense cards.
  TextStyle dsFeatureBullet() => _t.labelSmall!.copyWith(
        color: _c.onSurfaceVariant,
        height: 1.35,
        fontWeight: FontWeight.w500,
      );

  /// Selectable document ID.
  TextStyle dsMonospaceId() => _t.titleSmall!.copyWith(
        fontWeight: FontWeight.w700,
        color: _c.primary,
        height: 1.2,
        letterSpacing: 0.15,
      );

  /// Compact primary button label inside small cards (inherits button theme; use if overriding).
  TextStyle dsCompactButtonLabel() => _t.labelLarge!.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      );

  /// Inline error / validation message on forms.
  TextStyle dsErrorMessage() => _t.bodyMedium!.copyWith(
        color: _c.error,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );

  /// Drawer / list destructive action label (e.g. Sign out).
  TextStyle dsDestructiveLabel() => _t.titleSmall!.copyWith(
        color: _c.error,
        fontWeight: FontWeight.w600,
      );

  /// Monospace ID in menus or dense rows (platform monospace).
  TextStyle dsIdMenuLiteral() => _t.labelMedium!.copyWith(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        color: _c.onSurface,
        fontSize: 12,
        height: 1.25,
      );
}
