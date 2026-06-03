// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert' show base64Decode;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../grid_state.dart';
import '../theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ImageGalleryDialog
// Opens as a Dialog from the Grid screen. Fetches all public image URLs from
// the `unlocked_images` Storage bucket, displays them tiled in 3:4 crop, and
// composites a downloadable PNG using dart:ui Canvas + drawImageRect.
// ═══════════════════════════════════════════════════════════════════════════
class ImageGalleryDialog extends StatefulWidget {
  const ImageGalleryDialog({super.key});

  @override
  State<ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<ImageGalleryDialog> {
  List<String> _imageUrls = [];
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  // Tile dimensions enforce 3:4 aspect ratio for the display and the export
  static const double _tileW = 168.0;
  static const double _tileH = 224.0; // 3:4
  static const double _tilePad = 10.0;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final urls =
          await Provider.of<GridState>(context, listen: false).fetchAllImagePaths();
      if (mounted) setState(() { _imageUrls = urls; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Download logic ────────────────────────────────────────────────────────
  // Uses html.CanvasElement for compositing — dart:ui toByteData(png) is NOT
  // supported in Flutter web (returns null). The browser canvas API is native
  // and always available.
  Future<void> _downloadGallery() async {
    if (_imageUrls.isEmpty || _downloading) return;
    setState(() => _downloading = true);

    try {
      // Load all images as html.ImageElement (browser-native, CORS-safe)
      final List<html.ImageElement> imgs = [];
      for (final url in _imageUrls) {
        final img = await _loadHtmlImage(url);
        if (img != null) imgs.add(img);
      }

      if (imgs.isEmpty) {
        if (mounted) setState(() => _downloading = false);
        return;
      }

      const double pad = _tilePad;
      const int cols = 8;
      final int rows = (imgs.length / cols).ceil();

      final double totalW = cols * (_tileW + pad) + pad;
      final double totalH = rows * (_tileH + pad) + pad;

      final canvas = html.CanvasElement(
        width: totalW.ceil(),
        height: totalH.ceil(),
      );
      final ctx = canvas.context2D;

      // Dark background
      ctx
        ..fillStyle = '#13131A'
        ..fillRect(0, 0, totalW, totalH);

      for (int i = 0; i < imgs.length; i++) {
        final img = imgs[i];
        final int col = i % cols;
        final int row = i ~/ cols;
        final double dstX = pad + col * (_tileW + pad);
        final double dstY = pad + row * (_tileH + pad);

        // Compute 3:4 center-crop source rect
        final double iw = img.naturalWidth.toDouble();
        final double ih = img.naturalHeight.toDouble();
        const double targetAspect = _tileW / _tileH; // 0.75
        final double imgAspect = iw / ih;

        double sx, sy, sw, sh;
        if (imgAspect > targetAspect) {
          // Wider — crop sides
          sw = ih * targetAspect;
          sh = ih;
          sx = (iw - sw) / 2;
          sy = 0;
        } else {
          // Taller — crop top/bottom
          sw = iw;
          sh = iw / targetAspect;
          sx = 0;
          sy = (ih - sh) / 2;
        }

        // Clip to rounded rect (approximate with rect save/restore)
        ctx
          ..save()
          ..beginPath()
          ..rect(dstX, dstY, _tileW, _tileH)
          ..clip()
          ..drawImageScaledFromSource(
              img, sx, sy, sw, sh, dstX, dstY, _tileW, _tileH)
          ..restore();
      }

      // Export via data URL → decode base64 → browser download
      final dataUrl = canvas.toDataUrl('image/png');
      final base64Str = dataUrl.split(',')[1];
      final bytes = base64Decode(base64Str);
      final blob = html.Blob([bytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: blobUrl)
        ..setAttribute(
            'download', 'gallery_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
    } catch (e) {
      debugPrint('Gallery download error: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// Loads a URL as an html.ImageElement. Sets crossOrigin so the canvas
  /// compositing doesn't taint the canvas (required for toDataUrl).
  Future<html.ImageElement?> _loadHtmlImage(String url) async {
    try {
      final img = html.ImageElement()
        ..crossOrigin = 'anonymous'
        ..src = url;
      await img.onLoad.first.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Image load timed out: $url'),
      );
      return img;
    } catch (e) {
      debugPrint('Failed to load image $url: $e');
      return null;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840, maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Container(height: 1, color: AppColors.borderSubtle,
                margin: const EdgeInsets.symmetric(horizontal: 20)),
            Flexible(child: _buildBody()),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
      child: Row(
        children: [
          Icon(Icons.photo_library_rounded,
              size: 16, color: AppColors.textMuted),
          const Spacer(),
          if (!_loading && _imageUrls.isNotEmpty)
            _DownloadButton(
                isLoading: _downloading, onTap: _downloadGallery),
          const SizedBox(width: 6),
          _CloseButton(onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
        ),
      );
    }

    if (_imageUrls.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, size: 36, color: AppColors.textMuted),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding:
          const EdgeInsets.symmetric(horizontal: _tilePad, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _imageUrls.map(_buildTile).toList(),
      ),
    );
  }

  Widget _buildTile(String url) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: _tilePad / 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: _tileW,
          height: _tileH,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: _tileW,
            height: _tileH,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppColors.surfaceHigh,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    strokeWidth: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.surfaceHigh,
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 28, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _DownloadButton
// ═══════════════════════════════════════════════════════════════════════════
class _DownloadButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _DownloadButton({required this.isLoading, required this.onTap});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isLoading ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) { if (!widget.isLoading) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHigh : AppColors.borderSubtle,
            shape: BoxShape.circle,
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textMuted,
                  ),
                )
              : Icon(
                  Icons.download_rounded,
                  size: 13,
                  color: _hovered ? AppColors.textSecondary : AppColors.textMuted,
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CloseButton
// ═══════════════════════════════════════════════════════════════════════════
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.close_rounded,
              size: 17,
              color: _hovered ? AppColors.textSecondary : AppColors.textMuted),
        ),
      ),
    );
  }
}
