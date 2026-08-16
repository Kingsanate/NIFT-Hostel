import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import '../chat/chat_palette.dart';
import '../../main.dart'; // To access global cameras list
import 'processing_page.dart';
import 'models/student_model.dart';

class ScannerPage extends StatefulWidget {
  final String selectedHostel;

  const ScannerPage({
    super.key,
    required this.selectedHostel,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepCtrl;
  late final Animation<double> _sweepAnim;
  CameraController? _cameraController;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _sweepAnim = CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeInOut);

    // Lazy-init cameras (doesn't block startup anymore)
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Camera live preview is not available on web (dart:io restriction).
    // Web users use the gallery/file-upload button instead.
    if (kIsWeb) return;
    try {
      await initCamerasIfNeeded();
      if (!mounted) return;
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        _cameraController?.initialize().then((_) {
          if (!mounted) return;
          setState(() {});
        }).catchError((e) {
          debugPrint('Camera Error: $e');
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _pickGallery() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Resize params are skipped on web — the web resizer is canvas-based
        // and can throw; ExtractionService optimizes the image before AI.
        imageQuality: kIsWeb ? null : 85, // Higher quality for better OCR accuracy
        maxWidth: kIsWeb ? null : 1400, // Wider image = more readable text for Gemini
      );
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final result = await Navigator.of(context).push<StudentModel>(
          _slideRoute(ProcessingPage(
            imagePath: file.path,
            imageBytes: bytes,
            selectedHostel: widget.selectedHostel,
          )),
        );
        if (result != null && mounted) Navigator.of(context).pop(result);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _takeLivePhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      if (kIsWeb) {
        final file = await ImagePicker().pickImage(
          source: ImageSource.camera,
        );
        if (file != null && mounted) {
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          final result = await Navigator.of(context).push<StudentModel>(
            _slideRoute(ProcessingPage(
              imagePath: file.path,
              imageBytes: bytes,
              selectedHostel: widget.selectedHostel,
            )),
          );
          if (result != null && mounted) Navigator.of(context).pop(result);
        }
        return;
      }
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final file = await _cameraController!.takePicture();
        if (mounted) {
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          final result = await Navigator.of(context).push<StudentModel>(
            _slideRoute(ProcessingPage(
              imagePath: file.path,
              imageBytes: bytes,
              selectedHostel: widget.selectedHostel,
            )),
          );
          if (result != null && mounted) Navigator.of(context).pop(result);
        }
      } else {
        // Native camera fallback via ImagePicker (handles camera permissions automatically)
        final file = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1400,
        );
        if (file != null && mounted) {
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          final result = await Navigator.of(context).push<StudentModel>(
            _slideRoute(ProcessingPage(
              imagePath: file.path,
              imageBytes: bytes,
              selectedHostel: widget.selectedHostel,
            )),
          );
          if (result != null && mounted) Navigator.of(context).pop(result);
        }
      }
    } catch (e) {
      debugPrint('Error taking live picture, trying system camera: $e');
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1400,
        );
        if (file != null && mounted) {
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          final result = await Navigator.of(context).push<StudentModel>(
            _slideRoute(ProcessingPage(
              imagePath: file.path,
              imageBytes: bytes,
              selectedHostel: widget.selectedHostel,
            )),
          );
          if (result != null && mounted) Navigator.of(context).pop(result);
        }
      } catch (fallbackErr) {
        debugPrint('System camera fallback failed: $fallbackErr');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: Stack(children: [
        _GridBackground(),
        SafeArea(
          child: Column(children: [
            _TopBar(),
            Expanded(child: _ScanArea(sweepAnim: _sweepAnim, cameraController: _cameraController)),
            _BottomControls(
              onCamera: _takeLivePhoto,
              onGallery: _pickGallery,
              picking: _picking,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Subtle grid background ───────────────────────────────────────────────────
class _GridBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _GridPainter())));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ChatPalette.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _CircleBtn(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scan Admission Form',
                style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('Align the form inside the frame',
                style: TextStyle(color: ChatPalette.muted, fontSize: 12)),
          ]),
        ),
        _CircleBtn(
            icon: Icons.help_outline_rounded,
            onTap: () => _showHelp(context)),
      ]),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.3, curve: Curves.easeOut);
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ChatPalette.canvas,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _HelpSheet(),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: ChatPalette.border),
          ),
          child: Icon(icon, color: ChatPalette.muted, size: 20),
        ),
      );
}

// ── Scan area with frame + sweep line ────────────────────────────────────────
class _ScanArea extends StatelessWidget {
  final Animation<double> sweepAnim;
  final CameraController? cameraController;
  const _ScanArea({required this.sweepAnim, this.cameraController});

  @override
  Widget build(BuildContext context) {
    final isCameraReady = cameraController != null && cameraController!.value.isInitialized;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AspectRatio(
          aspectRatio: 0.75,
          child: Stack(children: [
            // Live Camera Preview or fallback background
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: isCameraReady 
                    ? CameraPreview(cameraController!)
                    : Container(color: ChatPalette.accent.withValues(alpha: 0.04)),
              ),
            ),

            // Corner frame (Google Blue)
            Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _FramePainter()))),

            // Sweeping blue scan line
            AnimatedBuilder(
              animation: sweepAnim,
              builder: (context, _) {
                final h = MediaQuery.of(context).size.height * 0.46;
                return Positioned(
                  top: 24 + sweepAnim.value * (h - 52),
                  left: 24,
                  right: 24,
                  child: _ScanLine(),
                );
              },
            ),

            // "Ready" indicator
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: ChatPalette.background.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ChatPalette.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: ChatPalette.accent, shape: BoxShape.circle),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .fadeOut(duration: 700.ms)
                      .then()
                      .fadeIn(duration: 700.ms),
                  SizedBox(width: 7),
                  Text('Tap Camera Icon Below',
                      style: TextStyle(
                          color: ChatPalette.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 500.ms)
            .scale(
                begin: const Offset(0.94, 0.94), curve: Curves.easeOut),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 26.0;
    const r = 20.0;

    final paint = Paint()
      ..color = ChatPalette.accent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final bgPaint = Paint()
      ..color = const Color(0xFF1A73E8).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(r)),
      bgPaint,
    );

    final borderP = Paint()
      ..color = ChatPalette.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          const Radius.circular(r)),
      borderP,
    );

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(r + cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, r + cornerLen), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14, 3.14 / 2, false, paint);

    // Top-right
    final trx = size.width - r;
    canvas.drawLine(Offset(trx, 0), Offset(trx - cornerLen, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + cornerLen), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2), 4.71, 3.14 / 2, false, paint);

    // Bottom-left
    final bly = size.height - r;
    canvas.drawLine(Offset(0, bly), Offset(0, bly - cornerLen), paint);
    canvas.drawLine(Offset(r, size.height), Offset(r + cornerLen, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2), 1.57, 3.14 / 2, false, paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - r), Offset(size.width, size.height - r - cornerLen), paint);
    canvas.drawLine(Offset(size.width - r, size.height), Offset(size.width - r - cornerLen, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2), 0, 3.14 / 2, false, paint);
  }

  @override
  bool shouldRepaint(_FramePainter _) => false;
}

class _ScanLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            ChatPalette.accent,
            ChatPalette.accentBlue,
            ChatPalette.accent,
            Colors.transparent,
          ]),
          boxShadow: [
            BoxShadow(
              color: ChatPalette.accent.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      );
}

// ── Bottom controls ──────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool picking;
  const _BottomControls(
      {required this.onCamera, required this.onGallery, required this.picking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(children: [
        // Tip card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ChatPalette.border),
          ),
          child: Row(children: [
            Icon(Icons.lightbulb_outline,
                color: ChatPalette.accentAmber, size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ensure good lighting and keep the form flat.',
                style: TextStyle(color: ChatPalette.muted, fontSize: 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          // Gallery
          Expanded(
            child: _Btn(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              onTap: picking ? null : onGallery,
              primary: false,
            ),
          ),
          const SizedBox(width: 12),
          // Camera (main)
          Expanded(
            flex: 2,
            child: _Btn(
              icon: picking ? null : Icons.camera_alt_rounded,
              label: picking ? 'Opening…' : 'Capture Form',
              onTap: picking ? null : onCamera,
              primary: true,
              loading: picking,
            ),
          ),
        ]),
      ]),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 400.ms)
        .slideY(begin: 0.4, curve: Curves.easeOut);
  }
}

class _Btn extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;
  const _Btn(
      {this.icon,
      required this.label,
      required this.onTap,
      required this.primary,
      this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: primary ? ChatPalette.accentDeep : ChatPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: primary
                    ? ChatPalette.accentDeep
                    : ChatPalette.border),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: ChatPalette.accentDeep.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    )
                  ]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white)),
              )
            else if (icon != null)
              Icon(icon,
                  color: primary ? Colors.white : ChatPalette.muted, size: 19),
            SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: primary ? Colors.white : ChatPalette.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ]),
        ),
      );
}

// ── Help bottom sheet ─────────────────────────────────────────────────────────
class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    const tips = [
      (Icons.wb_sunny_outlined, 'Good Lighting', 'Use natural or bright indoor light.'),
      (Icons.crop_free, 'Flat Surface', 'Place the form on a flat, unwrinkled surface.'),
      (Icons.center_focus_strong_outlined, 'Full Frame', 'Fit the entire form inside the corners.'),
      (Icons.hdr_strong, 'High Contrast', 'Printed forms with dark ink work best.'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scanning Tips',
              style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 16),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ChatPalette.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ChatPalette.border),
                    ),
                    child: Icon(t.$1, color: ChatPalette.accent, size: 18),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.$2,
                              style: TextStyle(
                                  color: ChatPalette.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text(t.$3,
                              style: TextStyle(
                                  color: ChatPalette.muted, fontSize: 12)),
                        ]),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

Route<T> _slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, anim1, anim2) => page,
      transitionsBuilder: (context, anim, secAnim, child) => SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(1, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
