import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Opens the user's stored resume.
///
/// PDFs render via the [pdfx] package, which uses PDFium through FFI.
/// We picked this over `flutter_pdfview` because PlatformView-based PDF
/// viewers hang on first render inside modal routes on some Android
/// devices — the FFI renderer side-steps that entire class of bugs.
///
/// Other formats (doc/docx/rtf) hand off to the system app picker via
/// `url_launcher` — Flutter has no portable in-process renderer for Word.
Future<void> showResumeViewer(
  BuildContext context, {
  required String filePath,
  required String fileName,
}) async {
  final file = File(filePath);
  if (filePath.isEmpty || !file.existsSync()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume file not found on this device'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  if (file.lengthSync() == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume file is empty — please re-upload it'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';

  if (ext != 'pdf') {
    await _openExternally(context, filePath, fileName);
    return;
  }

  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) =>
          _ResumePdfScreen(filePath: filePath, fileName: fileName),
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    ),
  );
}

Future<void> _openExternally(
  BuildContext context,
  String filePath,
  String fileName,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final uri = Uri.file(filePath);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No app installed that can open $fileName. Try uploading a PDF instead.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open this file. Try uploading a PDF instead.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ResumePdfScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  const _ResumePdfScreen({required this.filePath, required this.fileName});

  @override
  State<_ResumePdfScreen> createState() => _ResumePdfScreenState();
}

class _ResumePdfScreenState extends State<_ResumePdfScreen> {
  late final PdfControllerPinch _pdfController;
  int _currentPage = 1; // pdfx is 1-indexed
  int _totalPages = 0;
  bool _ready = false;
  String? _error;
  Timer? _loadTimeout;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );

    // Safety net — if the FFI renderer never resolves (extremely rare,
    // but seen with malformed/encrypted PDFs), surface an actionable
    // error instead of leaving the user staring at the spinner.
    _loadTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted || _ready || _error != null) return;
      setState(() {
        _error =
            'This PDF is taking unusually long to render. It may be corrupted or password-protected.';
      });
    });
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _pdfController.dispose();
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
    debugPrint('[ResumeViewer] PDF error: $err');
    setState(() => _error = err.toString());
  }

  Future<void> _shareExternally() async {
    final navigator = Navigator.of(context);
    await _openExternally(context, widget.filePath, widget.fileName);
    if (mounted) navigator.maybePop();
  }

  void _close() => Navigator.of(context).maybePop();

  Future<void> _goToPage(int pageOneBased) async {
    final clamped = pageOneBased.clamp(1, _totalPages.clamp(1, 99999));
    await _pdfController.animateToPage(
      pageNumber: clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                fileName: widget.fileName,
                currentPage: _currentPage,
                totalPages: _totalPages,
                ready: _ready,
                onClose: _close,
                onShare: _shareExternally,
              ),
              Expanded(
                child: _error != null
                    ? _ErrorState(
                        message: _error!,
                        onClose: _close,
                        onOpenExternally: _shareExternally,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          PdfViewPinch(
                            controller: _pdfController,
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
                          if (!_ready) const _LoadingOverlay(),
                        ],
                      ),
              ),
              if (_ready && _totalPages > 1 && _error == null)
                _PageControls(
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

class _Header extends StatelessWidget {
  final String fileName;
  final int currentPage;
  final int totalPages;
  final bool ready;
  final VoidCallback onClose;
  final VoidCallback onShare;
  const _Header({
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.urgent.withValues(alpha: 0.9),
                  AppColors.urgent.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.urgent.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ready && totalPages > 0
                      ? 'Page $currentPage of $totalPages'
                      : 'Loading…',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open in another app',
            onPressed: onShare,
            icon: const Icon(
              Icons.open_in_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  final int currentPage; // 1-indexed
  final int totalPages;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PageControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final canPrev = currentPage > 1;
    final canNext = currentPage < totalPages;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PageButton(
              icon: Icons.chevron_left_rounded,
              label: 'Previous',
              enabled: canPrev,
              onTap: onPrev,
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '$currentPage / $totalPages',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _PageButton(
              icon: Icons.chevron_right_rounded,
              label: 'Next',
              enabled: canNext,
              onTap: onNext,
              trailing: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool trailing;
  const _PageButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.trailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: trailing
              ? [
                  Text(label,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: color, fontWeight: FontWeight.w600)),
                  Icon(icon, color: color, size: 22),
                ]
              : [
                  Icon(icon, color: color, size: 22),
                  Text(label,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: color, fontWeight: FontWeight.w600)),
                ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Loading PDF…',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  final VoidCallback onOpenExternally;
  const _ErrorState({
    required this.message,
    required this.onClose,
    required this.onOpenExternally,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.urgent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.urgent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Couldn\'t preview this PDF',
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onOpenExternally,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open externally'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    elevation: 0,
                  ),
                ),
                OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
