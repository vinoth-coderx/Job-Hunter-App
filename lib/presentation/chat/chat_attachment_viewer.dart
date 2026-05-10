import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/conversation_model.dart';

/// WhatsApp-style in-app preview for a chat attachment.
///
/// - Images render full-screen with pinch-zoom + swipe-down-to-dismiss and
///   a Hero transition from the bubble thumbnail.
/// - PDFs render inline using the same FFI renderer ([pdfx]) we use for
///   resumes — bytes are streamed over HTTPS, no PlatformView.
/// - Anything else falls back to a small info screen with an "Open in
///   another app" CTA, since Flutter has no portable in-process renderer
///   for Word / spreadsheets / etc.
Future<void> openChatAttachment(
  BuildContext context,
  ChatFileAttachment file,
) async {
  if (file.url.isEmpty) return;
  if (file.isImage) {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _ChatImageViewer(file: file),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    return;
  }
  if (file.type == 'application/pdf') {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => _ChatPdfViewer(file: file),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ChatDocViewer(file: file),
    ),
  );
}

String chatAttachmentHeroTag(ChatFileAttachment file) =>
    'chat-attachment-${file.url}';

Future<void> _openExternally(
  BuildContext context,
  ChatFileAttachment file,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(file.url);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('No app installed that can open ${file.filename}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ---------------------------------------------------------------------------
// Image viewer
// ---------------------------------------------------------------------------

class _ChatImageViewer extends StatefulWidget {
  final ChatFileAttachment file;
  const _ChatImageViewer({required this.file});

  @override
  State<_ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<_ChatImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _zoom = TransformationController();
  // Drag-to-dismiss state. We translate the image down with the user's
  // finger and fade the black backdrop in proportion to drag distance —
  // matches WhatsApp's "swipe down to close" affordance.
  double _dragOffset = 0;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      // Disable swipe-to-dismiss while zoomed in, otherwise pan gestures
      // collide with the dismiss gesture and the user gets stuck.
      final scale = _zoom.value.getMaxScaleOnAxis();
      final next = scale > 1.05;
      if (next != _zoomed) setState(() => _zoomed = next);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_zoomed) return;
    setState(() => _dragOffset += d.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_zoomed) return;
    if (_dragOffset.abs() > 120) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dragRatio = (_dragOffset.abs() / size.height).clamp(0.0, 1.0);
    final backdropOpacity = (1 - dragRatio).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: backdropOpacity),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
          elevation: 0,
          foregroundColor: Colors.white,
          title: Text(
            widget.file.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => _openExternally(context, widget.file),
            ),
          ],
        ),
        body: GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          // Tap-to-dismiss when not zoomed, like the iOS Photos app.
          onTap: () {
            if (!_zoomed) Navigator.of(context).maybePop();
          },
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Hero(
                tag: chatAttachmentHeroTag(widget.file),
                child: InteractiveViewer(
                  transformationController: _zoom,
                  minScale: 1,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.file.url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PDF viewer
// ---------------------------------------------------------------------------

class _ChatPdfViewer extends StatefulWidget {
  final ChatFileAttachment file;
  const _ChatPdfViewer({required this.file});

  @override
  State<_ChatPdfViewer> createState() => _ChatPdfViewerState();
}

class _ChatPdfViewerState extends State<_ChatPdfViewer> {
  PdfControllerPinch? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _ready = false;
  String? _error;
  Timer? _loadTimeout;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final res = await http.get(Uri.parse(widget.file.url));
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() =>
            _error = 'Could not download PDF (HTTP ${res.statusCode}).');
        return;
      }
      final bytes = Uint8List.fromList(res.bodyBytes);
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
      _loadTimeout = Timer(const Duration(seconds: 15), () {
        if (!mounted || _ready || _error != null) return;
        setState(() => _error =
            'This PDF is taking unusually long to render. It may be corrupted or password-protected.');
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not download PDF: $e');
    }
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _pdfController?.dispose();
    super.dispose();
  }

  void _onLoaded(PdfDocument doc) {
    if (!mounted) return;
    _loadTimeout?.cancel();
    setState(() {
      _totalPages = doc.pagesCount;
      _ready = true;
    });
  }

  void _onError(Object err) {
    if (!mounted) return;
    _loadTimeout?.cancel();
    setState(() => _error = err.toString());
  }

  Future<void> _goToPage(int pageOneBased) async {
    final ctrl = _pdfController;
    if (ctrl == null) return;
    final clamped = pageOneBased.clamp(1, _totalPages.clamp(1, 99999));
    await ctrl.animateToPage(
      pageNumber: clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _pdfController;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _PdfHeader(
                fileName: widget.file.filename,
                currentPage: _currentPage,
                totalPages: _totalPages,
                ready: _ready,
                onClose: () => Navigator.of(context).maybePop(),
                onShare: () => _openExternally(context, widget.file),
              ),
              Expanded(
                child: _error != null
                    ? _PdfErrorState(
                        message: _error!,
                        onClose: () => Navigator.of(context).maybePop(),
                        onOpenExternally: () =>
                            _openExternally(context, widget.file),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (ctrl != null)
                            PdfViewPinch(
                              controller: ctrl,
                              scrollDirection: Axis.vertical,
                              backgroundDecoration: const BoxDecoration(
                                color: Color(0xFF1A1A1A),
                              ),
                              onDocumentLoaded: _onLoaded,
                              onDocumentError: _onError,
                              onPageChanged: (page) {
                                if (!mounted) return;
                                setState(() => _currentPage = page);
                              },
                            ),
                          if (!_ready) const _PdfLoadingOverlay(),
                        ],
                      ),
              ),
              if (_ready && _totalPages > 1 && _error == null)
                _PdfPageControls(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  onPrev: () => _goToPage(_currentPage - 1),
                  onNext: () => _goToPage(_currentPage + 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfHeader extends StatelessWidget {
  final String fileName;
  final int currentPage;
  final int totalPages;
  final bool ready;
  final VoidCallback onClose;
  final VoidCallback onShare;
  const _PdfHeader({
    required this.fileName,
    required this.currentPage,
    required this.totalPages,
    required this.ready,
    required this.onClose,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ready && totalPages > 0)
                  Text(
                    'Page $currentPage of $totalPages',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open in another app',
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _PdfPageControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PdfPageControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final atFirst = currentPage <= 1;
    final atLast = currentPage >= totalPages;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
              onPressed: atFirst ? null : onPrev,
            ),
            const SizedBox(width: 8),
            Text(
              '$currentPage / $totalPages',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon:
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
              onPressed: atLast ? null : onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfLoadingOverlay extends StatelessWidget {
  const _PdfLoadingOverlay();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _PdfErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  final VoidCallback onOpenExternally;
  const _PdfErrorState({
    required this.message,
    required this.onClose,
    required this.onOpenExternally,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onClose,
                child: const Text('Close',
                    style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onOpenExternally,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open externally'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic doc viewer (Word, Excel, etc.)
// ---------------------------------------------------------------------------

class _ChatDocViewer extends StatelessWidget {
  final ChatFileAttachment file;
  const _ChatDocViewer({required this.file});

  IconData _iconForType(String type) {
    if (type.contains('word')) return Icons.description_rounded;
    if (type.contains('sheet') || type.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (type == 'text/plain') return Icons.notes_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          file.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconForType(file.type),
                    size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                file.filename,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _humanSize(file.sizeBytes),
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 24),
              Text(
                'This file type can\'t be previewed inside the app. '
                'Open it in another app to view its contents.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _openExternally(context, file),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open in another app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
