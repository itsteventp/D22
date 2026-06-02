import 'dart:convert' show base64Decode;
import 'dart:html' as html;
import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../grid_state.dart';
import '../theme.dart';

class MorphingInputBar extends StatefulWidget {
  final Animation<double> loginAnim;
  final Animation<double> transAnim;
  final Animation<double> shakeAnim;
  final Size screenSize;
  final VoidCallback onLoginSuccess;
  final VoidCallback onShake;

  const MorphingInputBar({
    super.key,
    required this.loginAnim,
    required this.transAnim,
    required this.shakeAnim,
    required this.screenSize,
    required this.onLoginSuccess,
    required this.onShake,
  });

  @override
  State<MorphingInputBar> createState() => _MorphingInputBarState();
}

class _MorphingInputBarState extends State<MorphingInputBar> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _focused = false;
  bool _isUploading = false;
  bool _isPasswordMode = true;
  String? _attachedImagePath;
  String? _attachedImageName;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _textCtrl.addListener(_onTextChange);

    // If user is already logged in on cold start, bypass password mode immediately
    final state = Provider.of<GridState>(context, listen: false);
    if (state.isLoggedIn) {
      _isPasswordMode = false;
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _textCtrl.removeListener(_onTextChange);
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordSubmit(String password) async {
    if (password.isEmpty) return;
    final state = Provider.of<GridState>(context, listen: false);
    final success = await state.login(password);
    if (success) {
      setState(() {
        _isPasswordMode = false;
        _textCtrl.clear();
      });
      _focusNode.unfocus();
      widget.onLoginSuccess();
    } else {
      widget.onShake();
      _textCtrl.clear();
    }
  }

  void _handleCodeSubmit(String code) {
    if (code.isEmpty) return;
    if (_attachedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C24),
              borderRadius: BorderRadius.circular(12.0),
              border: const Border(
                left: BorderSide(color: AppColors.error, width: 3.0),
              ),
            ),
            child: const Text('Please attach an image first.', style: TextStyle(color: Color(0xFFEEEEF5))),
          ),
        ),
      );
      return;
    }
    final state = Provider.of<GridState>(context, listen: false);
    state.submitCodeWithImage(code, _attachedImagePath!, context);
    _textCtrl.clear();
    setState(() {
      _attachedImagePath = null;
      _attachedImageName = null;
    });
  }

  // ── Image attachment methods (extracted from old map_screen _InputBar) ──────
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
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _handleAttachImage() {
    if (_isUploading) return;
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
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    });
  }

  static Future<Uint8List> _generateRandomColorPng() async {
    final rand = Random();
    final hue = rand.nextDouble() * 360.0;
    final color = HSVColor.fromAHSV(1.0, hue, 0.72, 0.88).toColor();
    const int w = 120;
    const int h = 160;

    final canvas = html.CanvasElement(width: w, height: h);
    final ctx = canvas.context2D;
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    ctx
      ..fillStyle = 'rgb($r, $g, $b)'
      ..fillRect(0, 0, w, h);

    final grad = ctx.createLinearGradient(0, 0, 0, h.toDouble());
    grad
      ..addColorStop(0, 'rgba(255,255,255,0.22)')
      ..addColorStop(1, 'rgba(255,255,255,0)');
    ctx
      ..fillStyle = grad
      ..fillRect(0, 0, w, h);

    ctx
      ..beginPath()
      ..arc(w / 2, h / 2, 40, 0, 2 * pi)
      ..strokeStyle = 'rgba(255,255,255,0.40)'
      ..lineWidth = 2.5
      ..stroke();

    ctx
      ..beginPath()
      ..arc(w / 2, h / 2, 5, 0, 2 * pi)
      ..fillStyle = 'rgba(255,255,255,0.65)'
      ..fill();

    final dataUrl = canvas.toDataUrl('image/png');
    final base64Str = dataUrl.split(',')[1];
    return base64Decode(base64Str);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.screenSize;
    final t = widget.loginAnim.value;
    final trans = widget.transAnim.value;
    final shake = widget.shakeAnim.value;

    // Morph coordinates
    final startY = (s.height - 48.0) / 2;
    const endY = 8.0;
    final y = lerpDouble(startY, endY, t)!;

    final startX = (s.width - 320.0) / 2;
    const endX = 20.0;
    final x = lerpDouble(startX, endX, t)!;

    final width = lerpDouble(320.0, s.width - 40.0, t)!;
    final height = lerpDouble(48.0, 97.0, t)!;

    final hasCode = _textCtrl.text.trim().isNotEmpty;
    final hasImage = _attachedImagePath != null;
    final canSubmit = hasCode && hasImage && !_isUploading;

    return Positioned(
      top: y,
      left: x + shake,
      width: width,
      height: height,
      child: Opacity(
        opacity: (1.0 - trans).clamp(0.0, 1.0),
        child: IgnorePointer(
          ignoring: trans > 0.05,
          child: Container(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.transparent, AppColors.surface, t),
              borderRadius: BorderRadius.circular(lerpDouble(4.0, AppRadius.lg, t)!),
              border: Border.all(
                color: Color.lerp(Colors.transparent, AppColors.borderSubtle, t)!,
                width: t,
              ),
              boxShadow: (t > 0.5 && _focused)
                  ? [
                      BoxShadow(
                        color: AppColors.textMuted.withValues(alpha: 0.22),
                        blurRadius: 22,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(lerpDouble(4.0, AppRadius.lg, t)!),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ── Row 1: Input Field ───────────────────────────────────
                    SizedBox(
                      height: 48.0,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            _isPasswordMode
                                ? Icons.lock_outline_rounded
                                : Icons.terminal_rounded,
                            size: 16.0,
                            color: _focused
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _textCtrl,
                              focusNode: _focusNode,
                              obscureText: _isPasswordMode,
                              style: AppTextStyles.code(
                                color: AppColors.textPrimary,
                                size: 13.5,
                              ),
                              textCapitalization: _isPasswordMode
                                  ? TextCapitalization.none
                                  : TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: _isPasswordMode
                                    ? 'Enter master password...'
                                    : 'Enter code...',
                                hintStyle: AppTextStyles.code(
                                  color: AppColors.textMuted,
                                  size: 13.5,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (val) {
                                if (_isPasswordMode) {
                                  _handlePasswordSubmit(val);
                                } else {
                                  if (canSubmit) _handleCodeSubmit(val);
                                }
                              },
                            ),
                          ),
                          if (_isPasswordMode && _textCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16.0,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: () => _handlePasswordSubmit(_textCtrl.text),
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),

                    // ── Password Mode Bottom Line ────────────────────────────
                    if (t < 0.99)
                      Opacity(
                        opacity: (1.0 - t).clamp(0.0, 1.0),
                        child: Container(
                          height: 1.5,
                          width: double.infinity,
                          color: AppColors.textMuted,
                        ),
                      ),

                    // ── Row 2: Attachment Tools (Map Mode Only) ──────────────
                    if (t > 0.1) ...[
                      Opacity(
                        opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                        child: Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 14.0),
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      Opacity(
                        opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12.0, 7.0, 6.0, 7.0),
                          child: SizedBox(
                            height: 32.0,
                            child: Row(
                              children: [
                                _MicroButton(
                                  label: 'auto',
                                  icon: Icons.auto_awesome_rounded,
                                  onTap: _isUploading ? null : _handleAutoImage,
                                ),
                                const SizedBox(width: 6),
                                _MicroButton(
                                  label: 'attach',
                                  icon: Icons.attach_file_rounded,
                                  onTap: _isUploading ? null : _handleAttachImage,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ImageStatusIndicator(
                                    isUploading: _isUploading,
                                    imageName: _attachedImageName,
                                    hasImage: hasImage,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SubmitButton(
                                  onPressed: canSubmit ? () => _handleCodeSubmit(_textCtrl.text) : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── MicroButton (Copied from map_screen) ─────────────────────────────────────
class _MicroButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _MicroButton({required this.label, required this.icon, required this.onTap});

  @override
  State<_MicroButton> createState() => _MicroButtonState();
}

class _MicroButtonState extends State<_MicroButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (enabled) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHigh : AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 10,
                  color: _hovered ? AppColors.textSecondary : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: AppTextStyles.caption(
                    color: _hovered ? AppColors.textSecondary : AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ImageStatusIndicator (Copied from map_screen) ────────────────────────────
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
                const SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 7),
                Text('uploading...',
                    style: AppTextStyles.caption(color: AppColors.textMuted)),
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
                        style: AppTextStyles.caption(color: AppColors.textSecondary),
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
                        style: AppTextStyles.caption(color: AppColors.textMuted)),
                  ],
                ),
    );
  }
}

// ── SubmitButton (Copied from map_screen) ────────────────────────────────────
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
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (enabled) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      color: AppColors.textPrimary.withValues(alpha: 0.22),
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
