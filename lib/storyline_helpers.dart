import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';

class StorylineLocation {
  const StorylineLocation({
    required this.isoCountryCode,
    required this.label,
  });

  final String? isoCountryCode;
  final String label;

  bool get inGhana => (isoCountryCode ?? '').toUpperCase() == 'GH';
}

class StorylineHelpers {
  StorylineHelpers._();

  static Future<String> compressImageIfNeeded(String path) async {
    if (kIsWeb) return path;
    final lower = path.toLowerCase();
    if (!lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.png') &&
        !lower.endsWith('.webp')) {
      return path;
    }
    try {
      final dir = await getTemporaryDirectory();
      final base = p.basenameWithoutExtension(path);
      final target = p.join(dir.path, '${base}_compressed.jpg');
      final out = await FlutterImageCompress.compressAndGetFile(
        path,
        target,
        quality: 72,
        format: CompressFormat.jpeg,
      );
      return out?.path ?? path;
    } catch (_) {
      return path;
    }
  }

  /// Best-effort GPS + reverse geocode; never throws to callers.
  static Future<StorylineLocation> detectLocation() async {
    if (kIsWeb) {
      return const StorylineLocation(isoCountryCode: null, label: 'Web');
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const StorylineLocation(isoCountryCode: null, label: 'Location off');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final m = marks.isNotEmpty ? marks.first : null;
      final country = m?.isoCountryCode ?? m?.country;
      final locality = m?.locality ?? m?.subAdministrativeArea ?? m?.administrativeArea;
      final label = [locality, m?.country].whereType<String>().where((e) => e.isNotEmpty).join(', ');
      return StorylineLocation(
        isoCountryCode: country,
        label: label.isEmpty ? 'Detected' : label,
      );
    } catch (_) {
      return const StorylineLocation(isoCountryCode: null, label: 'Unknown');
    }
  }

  static Future<void> pulseSuccess() async {
    if (kIsWeb) return;
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 40);
      }
    } catch (_) {}
  }

  static Future<void> pulseWarning() async {
    if (kIsWeb) return;
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 35, 80, 35]);
      }
    } catch (_) {}
  }
}
