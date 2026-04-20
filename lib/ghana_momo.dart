import 'package:phone_numbers_parser/phone_numbers_parser.dart';

enum GhanaMomoProvider { mtn, vodafone, airtelTigo, other }

class GhanaMomo {
  GhanaMomo._();

  static String label(GhanaMomoProvider p) {
    switch (p) {
      case GhanaMomoProvider.mtn:
        return 'MTN Mobile Money';
      case GhanaMomoProvider.vodafone:
        return 'Vodafone Cash';
      case GhanaMomoProvider.airtelTigo:
        return 'AirtelTigo Money';
      case GhanaMomoProvider.other:
        return 'Other';
    }
  }

  static List<GhanaMomoProvider> providersForContext({required bool inGhana}) {
    if (inGhana) {
      return GhanaMomoProvider.values.where((e) => e != GhanaMomoProvider.other).toList();
    }
    return GhanaMomoProvider.values.toList();
  }

  /// Validates [raw] as a Ghana mobile number when [inGhana]; otherwise lenient international check.
  static ({bool ok, String formatted, String? message}) validateMomoNumber({
    required String raw,
    required GhanaMomoProvider provider,
    required bool inGhana,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (ok: false, formatted: '', message: 'Enter a mobile money number.');
    }
    try {
      final phone = PhoneNumber.parse(
        trimmed,
        callerCountry: IsoCode.GH,
        destinationCountry: IsoCode.GH,
      );
      if (!phone.isValid()) {
        return (ok: false, formatted: trimmed, message: 'That number does not look valid for Ghana.');
      }
      final inferred = _providerFromNsn(phone.nsn);
      if (inGhana &&
          provider != GhanaMomoProvider.other &&
          inferred != null &&
          inferred != provider) {
        return (
          ok: false,
          formatted: phone.international,
          message: 'Number prefix does not match ${label(provider)}.',
        );
      }
      return (ok: true, formatted: phone.international, message: null);
    } catch (e) {
      return (ok: false, formatted: trimmed, message: 'Could not read that number.');
    }
  }

  static GhanaMomoProvider? _providerFromNsn(String nsn) {
    final d = nsn.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return null;
    // Ghana mobile prefixes (simplified; MoMo lines follow mobile numbering).
    if (d.startsWith('24') || d.startsWith('54') || d.startsWith('55') || d.startsWith('59')) {
      return GhanaMomoProvider.mtn;
    }
    if (d.startsWith('20') || d.startsWith('50')) {
      return GhanaMomoProvider.vodafone;
    }
    if (d.startsWith('26') || d.startsWith('56') || d.startsWith('27') || d.startsWith('57')) {
      return GhanaMomoProvider.airtelTigo;
    }
    return null;
  }
}
