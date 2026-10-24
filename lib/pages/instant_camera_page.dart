import "package:camera/camera.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/audience.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/audience_picker.dart";
import "../widgets/dialogs.dart";

/// "New instant": live camera, one tap sends the photo to your friends.
class InstantCameraPage extends ConsumerStatefulWidget {
  const InstantCameraPage({super.key});

  @override
  ConsumerState<InstantCameraPage> createState() => _InstantCameraPageState();
}

class _InstantCameraPageState extends ConsumerState<InstantCameraPage>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _flash = false;
  bool _sending = false;
  String? _error;
  Audience _audience = Audience.friends;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be released while the app is in the background.
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      controller.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _open(_cameraIndex);
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = "No camera found on this device.");
        return;
      }
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      await _open(back < 0 ? 0 : back);
    } catch (e) {
      if (mounted) setState(() => _error = _cameraError(e));
    }
  }

  String _cameraError(Object e) {
    if (e is CameraException &&
        (e.code.contains("Denied") || e.code.contains("denied"))) {
      return "Allow camera access in Settings to send instants.";
    }
    return "Couldn't open the camera.\n${errorText(e)}";
  }

  Future<void> _open(int index) async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(_flash ? FlashMode.always : FlashMode.off);
    } catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _error = _cameraError(e));
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameraIndex = index;
      _error = null;
    });
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _sending) return;
    await _open((_cameraIndex + 1) % _cameras.length);
  }

  Future<void> _toggleFlash() async {
    setState(() => _flash = !_flash);
    await _controller
        ?.setFlashMode(_flash ? FlashMode.always : FlashMode.off)
        .catchError((_) {});
  }

  Future<void> _pickAudience() async {
    final picked = await showAudiencePicker(
      context,
      current: _audience,
      title: "Who can see your instants?",
    );
    if (picked != null && mounted) setState(() => _audience = picked);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _sending) return;
    setState(() => _sending = true);
    try {
      final photo = await controller.takePicture();
      await ref.read(instantsProvider.notifier).send(photo, _audience);
      if (!mounted) return;
      showToast(context, "Instant sent to ${_audience.label}");
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showInfo(context, title: "Couldn't send instant", message: errorText(e));
    }
  }

  Widget _roundButton(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFF262626),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFFFFFFF), size: 26),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final controller = _controller;

    Widget viewfinder;
    if (_error != null) {
      viewfinder = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFA8A8A8)),
          ),
        ),
      );
    } else if (controller == null || !controller.value.isInitialized) {
      viewfinder = const Center(
        child: CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
      );
    } else {
      // Fill the rounded square, cropping the preview like Instagram.
      final size = controller.value.previewSize;
      viewfinder = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // The plugin reports the sensor size in landscape.
          width: size?.height ?? width,
          height: size?.width ?? width,
          child: CameraPreview(controller),
        ),
      );
    }

    return PlainPage(
      background: const Color(0xFF000000),
      child: Padding(
        padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Color(0xFFFFFFFF),
                      size: 28,
                      semanticLabel: "Close",
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "New instant",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                ],
              ),
            ),
            const Spacer(),
            // Squircle viewfinder.
            SizedBox(
              width: width - 24,
              height: (width - 24) * 0.95,
              child: ClipPath(
                clipper: const ShapeBorderClipper(
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(140)),
                  ),
                ),
                child: ColoredBox(
                  color: const Color(0xFF1C1C1E),
                  child: viewfinder,
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _roundButton(
                  _flash ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash,
                  _flash ? "Flash on" : "Flash off",
                  _toggleFlash,
                ),
                const SizedBox(width: 40),
                Semantics(
                  button: true,
                  label: "Take and send instant",
                  child: GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF5E5E66),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFFFFF),
                        ),
                        child: _sending
                            ? const CupertinoActivityIndicator(radius: 14)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                _roundButton(
                  CupertinoIcons.arrow_2_circlepath,
                  "Switch camera",
                  _flip,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Semantics(
              button: true,
              label: "Send to ${_audience.label}",
              child: GestureDetector(
                onTap: _pickAudience,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _audience == Audience.closeFriends
                              ? kCloseFriendsGreen
                              : const Color(0xFF5B51D8),
                        ),
                        child: Icon(
                          _audience.icon,
                          size: 16,
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _audience.label,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        CupertinoIcons.chevron_down,
                        size: 14,
                        color: Color(0xFFFFFFFF),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
