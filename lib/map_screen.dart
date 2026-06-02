// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert' show base64Decode;
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grid_state.dart';
import 'map_physics.dart';
import 'theme.dart';
import 'widgets/blob_painter.dart';
import 'widgets/void_background_painter.dart';

// ---------------------------------------------------------------------------
// MapScreen — void canvas + floating blob physics + code input.
// The pentagram is no longer rendered here; it lives as a persistent overlay
// in MainNavigator and animates between the map-center and grid-header positions.
// ---------------------------------------------------------------------------
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // ── Input ──────────────────────────────────────────────────────────────────
  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  // ── Physics ────────────────────────────────────────────────────────────────
  late final Ticker _physicsTicker;
  final BlobPhysicsSimulator _physics = BlobPhysicsSimulator();
  final ValueNotifier<double> _physicsTime = ValueNotifier(0.0);
  double _elapsed = 0.0;
  DateTime _lastTick = DateTime.now();
  Size _canvasSize = const Size(800, 600);

  // ── Blob interaction ───────────────────────────────────────────────────────
  String? _hoveredBlobId;
  String? _draggedBlobId;
  SystemMouseCursor _cursor = SystemMouseCursors.basic;

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _physicsTicker = createTicker(_onPhysicsTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<GridState>(context, listen: false).fetchMasterConnections();
      }
    });
  }

  void _onPhysicsTick(Duration _) {
    if (!mounted) return;
    final now = DateTime.now();
    final dt =
        (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = now;
    _elapsed += dt;

    final state = Provider.of<GridState>(context, listen: false);
    _physics.sync(state.nodes, _canvasSize);
    _physics.step(_elapsed, _canvasSize);
    _physicsTime.value = _elapsed;
  }

  @override
  void dispose() {
    _physicsTicker.dispose();
    _physicsTime.dispose();
    _codeCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Hit-testing
  // ══════════════════════════════════════════════════════════════════════════
  String? _hitTestBlob(Offset pos, GridState state) {
    for (final node in state.nodes.reversed) {
      final phys = _physics.get(node.id);
      if (phys == null) continue;
      if ((pos - phys.position).distance <= phys.radius + 8) return node.id;
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Gestures (blob only)
  // ══════════════════════════════════════════════════════════════════════════
  void _handlePanStart(DragStartDetails details) {
    final state = Provider.of<GridState>(context, listen: false);
    final hit = _hitTestBlob(details.localPosition, state);
    if (hit != null) {
      _draggedBlobId = hit;
      _cursor = SystemMouseCursors.grabbing;
      _physics.pinNode(hit, details.localPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggedBlobId != null) {
      _physics.moveNode(_draggedBlobId!, details.localPosition);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedBlobId != null) {
      final vel = details.velocity.pixelsPerSecond / 60.0;
      _physics.releaseNode(_draggedBlobId!, vel);
      _draggedBlobId = null;
      _cursor = SystemMouseCursors.basic;
    }
  }

  void _handleHover(PointerHoverEvent event) {
    final state = Provider.of<GridState>(context, listen: false);
    final hit = _hitTestBlob(event.localPosition, state);
    final newCursor =
        hit != null ? SystemMouseCursors.grab : SystemMouseCursors.basic;
    if (hit != _hoveredBlobId || newCursor != _cursor) {
      setState(() {
        _hoveredBlobId = hit;
        _cursor = newCursor;
      });
    }
  }

  void _handleHoverExit(PointerExitEvent _) {
    if (_hoveredBlobId != null || _cursor != SystemMouseCursors.basic) {
      setState(() {
        _hoveredBlobId = null;
        _cursor = SystemMouseCursors.basic;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Column(
      children: [
        // ── Code input bar ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 10.0),
          child: _InputBar(
            controller: _codeCtrl,
            focusNode: _inputFocus,
            onSubmitWithImage: (code, imagePath) {
              state.submitCodeWithImage(code, imagePath, context);
            },
          ),
        ),

        // ── Canvas ──────────────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              _canvasSize =
                  Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                children: [
                  // Layer 1: Static void background
                  RepaintBoundary(
                    child: SizedBox.expand(
                      child: CustomPaint(
                          painter: const VoidBackgroundPainter()),
                    ),
                  ),

                  // Layer 2: Blob physics canvas (rerenders every tick)
                  ListenableBuilder(
                    listenable: _physicsTime,
                    builder: (ctx, _) {
                      final s =
                          Provider.of<GridState>(ctx, listen: false);
                      return RepaintBoundary(
                        child: SizedBox.expand(
                          child: CustomPaint(
                            painter: BlobCanvasPainter(
                              nodes: s.nodes,
                              connections: s.connections,
                              physics: _physics,
                              hoveredNodeId: _hoveredBlobId,
                              draggedNodeId: _draggedBlobId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Layer 3: Gesture + hover (transparent, on top)
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: _cursor,
                      onHover: _handleHover,
                      onExit: _handleHoverExit,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _handlePanStart,
                        onPanUpdate: _handlePanUpdate,
                        onPanEnd: _handlePanEnd,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _InputBar
//
// Two-row layout:
//   Row 1: terminal icon + code text field
//   Row 2: [auto] [attach] [status indicator] [Unlock]
//
// Unlock is disabled until BOTH a code AND an uploaded image path are present.
// ═══════════════════════════════════════════════════════════════════════════
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String code, String imagePath) onSubmitWithImage;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitWithImage,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  // ── Focus / text ─────────────────────────────────────────────────────────
  bool _focused = false;

  // ── Image attachment state ──────────────────────────────────────────────
  String? _attachedImagePath; // public URL from Storage
  String? _attachedImageName; // display name
  bool _isUploading = false;

  // ───────────────────────────────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  // Rebuild on text change so Unlock button reflects current state
  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────
  // Submit
  // ───────────────────────────────────────────────────────────────────
  void _handleSubmit() {
    final code = widget.controller.text;
    final imagePath = _attachedImagePath!;
    widget.controller.clear();
    setState(() {
      _attachedImagePath = null;
      _attachedImageName = null;
    });
    widget.onSubmitWithImage(code, imagePath);
  }

  // ───────────────────────────────────────────────────────────────────
  // Image upload helpers
  // ───────────────────────────────────────────────────────────────────

  /// Generates a random vibrant-color PNG (120×160 px, 3:4) and uploads it to
  /// the `unlocked_images` Storage bucket. Used by the dev [auto] button.
  Future<void> _handleAutoImage() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await _generateRandomColorPng();
      final name = 'auto_${DateTime.now().millisecondsSinceEpoch}.png';
      await Supabase.instance.client.storage
          .from('unlocked_images')
          .uploadBinary(
            name,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      final url = Supabase.instance.client.storage
          .from('unlocked_images')
          .getPublicUrl(name);
      if (mounted) {
        setState(() {
          _attachedImagePath = url;
          _attachedImageName = name;
        });
      }
    } catch (e) {
      debugPrint('Auto image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1C1C24),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Opens a web file picker, reads the selected image, uploads to Storage,
  /// and updates [_attachedImagePath].
  void _handleAttachImage() {
    if (_isUploading) return;
    // Must be appended to body before .click() — required by most browsers
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..style.display = 'none';
    html.document.body!.append(input);
    input.click();
    input.onChange.listen((_) async {
      final file = input.files?.first;
      input.remove();
      if (file == null || !mounted) return;
      setState(() => _isUploading = true);
      try {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;
        final result = reader.result;
        Uint8List bytes;
        if (result is ByteBuffer) {
          bytes = result.asUint8List();
        } else {
          bytes = Uint8List.fromList(result as List<int>);
        }
        final ext = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : 'jpg';
        final mime = file.type.isNotEmpty ? file.type : 'image/jpeg';
        final name = 'img_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await Supabase.instance.client.storage
            .from('unlocked_images')
            .uploadBinary(name, bytes,
                fileOptions: FileOptions(contentType: mime));
        final url = Supabase.instance.client.storage
            .from('unlocked_images')
            .getPublicUrl(name);
        if (mounted) {
          setState(() {
            _attachedImagePath = url;
            _attachedImageName = file.name;
          });
        }
      } catch (e) {
        debugPrint('Attach image error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1C1C24),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    });
  }

  /// Uses the browser's HTML5 Canvas API to paint a random-hue fill with
  /// gradient + decorative ring, then encodes via toDataUrl (reliable on web).
  /// dart:ui PictureRecorder.toByteData(png) is NOT supported on Flutter web.
  static Future<Uint8List> _generateRandomColorPng() async {
    final rand = Random();
    final hue = rand.nextDouble() * 360.0;
    final color = HSVColor.fromAHSV(1.0, hue, 0.72, 0.88).toColor();

    const int w = 120;
    const int h = 160; // 3:4

    final canvas = html.CanvasElement(width: w, height: h);
    final ctx = canvas.context2D;

    // Solid hue fill
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    ctx
      ..fillStyle = 'rgb($r, $g, $b)'
      ..fillRect(0, 0, w, h);

    // Soft top highlight gradient
    final grad = ctx.createLinearGradient(0, 0, 0, h.toDouble());
    grad
      ..addColorStop(0, 'rgba(255,255,255,0.22)')
      ..addColorStop(1, 'rgba(255,255,255,0)');
    ctx
      ..fillStyle = grad
      ..fillRect(0, 0, w, h);

    // Decorative ring
    ctx
      ..beginPath()
      ..arc(w / 2, h / 2, 40, 0, 2 * pi)
      ..strokeStyle = 'rgba(255,255,255,0.40)'
      ..lineWidth = 2.5
      ..stroke();

    // Center dot
    ctx
      ..beginPath()
      ..arc(w / 2, h / 2, 5, 0, 2 * pi)
      ..fillStyle = 'rgba(255,255,255,0.65)'
      ..fill();

    // Export via data URL → strip header → decode base64 bytes
    final dataUrl = canvas.toDataUrl('image/png');
    final base64Str = dataUrl.split(',')[1];
    return base64Decode(base64Str);
  }

  // ───────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool hasCode = widget.controller.text.trim().isNotEmpty;
    final bool hasImage = _attachedImagePath != null;
    final bool canSubmit = hasCode && hasImage && !_isUploading;

    return AnimatedContainer(
      duration: AppDurations.normal,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _focused
              ? AppColors.textMuted.withValues(alpha: 0.18)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.textMuted.withValues(alpha: 0.22),
                  blurRadius: 22,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Code input ────────────────────────────────────────────
          SizedBox(
            height: 48.0,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.terminal_rounded,
                  size: 16.0,
                  color: _focused
                      ? AppColors.textSecondary
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    style: AppTextStyles.code(
                        color: AppColors.textPrimary, size: 13.5),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter code...',
                      hintStyle: AppTextStyles.code(
                          color: AppColors.textMuted, size: 13.5),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) {
                      if (canSubmit) _handleSubmit();
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.borderSubtle,
          ),

          // ── Row 2: Image controls + Unlock ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
            child: Row(
              children: [
                // [auto] dev placeholder button
                _MicroButton(
                  label: 'auto',
                  icon: Icons.auto_awesome_rounded,
                  onTap: _isUploading ? null : _handleAutoImage,
                ),
                const SizedBox(width: 6),
                // [attach] real file picker
                _MicroButton(
                  label: 'attach',
                  icon: Icons.attach_file_rounded,
                  onTap: _isUploading ? null : _handleAttachImage,
                ),
                const SizedBox(width: 10),
                // Status indicator (expands to fill)
                Expanded(
                  child: _ImageStatusIndicator(
                    isUploading: _isUploading,
                    imageName: _attachedImageName,
                    hasImage: hasImage,
                  ),
                ),
                const SizedBox(width: 8),
                // Unlock button
                _SubmitButton(
                  onPressed: canSubmit ? _handleSubmit : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _MicroButton — compact ghost pill used for [auto] and [attach]
// ═══════════════════════════════════════════════════════════════════════════
class _MicroButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _MicroButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_MicroButton> createState() => _MicroButtonState();
}

class _MicroButtonState extends State<_MicroButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (enabled) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceHigh
                : AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 10,
                  color: _hovered
                      ? AppColors.textSecondary
                      : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: AppTextStyles.caption(
                    color: _hovered
                        ? AppColors.textSecondary
                        : AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ImageStatusIndicator — shows upload progress / image name / "no image"
// ═══════════════════════════════════════════════════════════════════════════
class _ImageStatusIndicator extends StatelessWidget {
  final bool isUploading;
  final String? imageName;
  final bool hasImage;

  const _ImageStatusIndicator({
    required this.isUploading,
    required this.imageName,
    required this.hasImage,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.fast,
      child: isUploading
          ? Row(
              key: const ValueKey('uploading'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 7),
                Text('uploading...',
                    style:
                        AppTextStyles.caption(color: AppColors.textMuted)),
              ],
            )
          : hasImage
              ? Row(
                  key: const ValueKey('ready'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        imageName ?? 'ready',
                        style: AppTextStyles.caption(
                            color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('needed'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('no image',
                        style: AppTextStyles.caption(
                            color: AppColors.textMuted)),
                  ],
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SubmitButton — primary unlock action. Accepts nullable onPressed:
//   null  → visually disabled (muted, no glow)
//   fn    → active (full color, hover glow)
// ═══════════════════════════════════════════════════════════════════════════
class _SubmitButton extends StatefulWidget {
  final VoidCallback? onPressed;
  const _SubmitButton({this.onPressed});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return MouseRegion(
      cursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (enabled) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: enabled
                ? (_hovered
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.88))
                : AppColors.textMuted.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: (enabled && _hovered)
                ? [
                    BoxShadow(
                      color:
                          AppColors.textPrimary.withValues(alpha: 0.22),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          ),
          child: Text(
            'Unlock',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? AppColors.background
                  : AppColors.textMuted.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
