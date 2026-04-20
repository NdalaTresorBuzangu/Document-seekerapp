import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen document capture — portrait lock, higher resolution, flash control.
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  bool _busy = false;
  String? _error;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    _init();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      setState(() => _error = 'Camera capture is not available on web in this build.');
      return;
    }
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      await ctrl.lockCaptureOrientation(DeviceOrientation.portraitUp);
      try {
        await ctrl.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await ctrl.setFlashMode(FlashMode.auto);
        if (mounted) setState(() => _flashMode = FlashMode.auto);
      } catch (_) {
        if (mounted) setState(() => _flashMode = FlashMode.off);
      }
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _controller = ctrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  static const List<FlashMode> _flashCycle = [
    FlashMode.off,
    FlashMode.auto,
    FlashMode.torch,
  ];

  Future<void> _cycleFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    final start = _flashCycle.indexOf(_flashMode);
    final i0 = start < 0 ? 0 : start;
    for (var step = 1; step <= _flashCycle.length; step++) {
      final mode = _flashCycle[(i0 + step) % _flashCycle.length];
      try {
        await c.setFlashMode(mode);
        if (mounted) setState(() => _flashMode = mode);
        return;
      } catch (_) {}
    }
  }

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.torch:
        return Icons.flashlight_on;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
    }
  }

  Future<void> _snap() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await c.takePicture();
      if (!mounted) return;
      if (!File(shot.path).existsSync()) {
        setState(() => _error = 'Capture failed — file missing.');
        return;
      }
      Navigator.of(context).pop<String>(shot.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: const Text('Capture evidence'),
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white)),
              ),
            )
          : c == null || !c.value.isInitialized
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Material(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: scheme.primaryContainer, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Hold steady. Fill the frame with the document; use the flash button if text is hard to read.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    height: 1.35,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: c.value.aspectRatio,
                            child: CameraPreview(c),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: _busy ? null : () => Navigator.of(context).pop(),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                            ),
                            IconButton(
                              tooltip: 'Flash: off / auto / torch',
                              onPressed: _busy ? null : _cycleFlash,
                              icon: Icon(_flashIcon(), color: Colors.white),
                            ),
                            const Spacer(),
                            Material(
                              color: scheme.primary,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: _busy ? null : _snap,
                                customBorder: const CircleBorder(),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: _busy
                                      ? const Padding(
                                          padding: EdgeInsets.all(20),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                                ),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
