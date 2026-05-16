import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_text.dart';

/// Full-screen in-app PDF viewer for the seeker's resume.
///
/// The previous flow handed the bytes off to the OS viewer via
/// `launchUrl(Uri.file(...))`, which silently failed on iOS (file://
/// sandboxing) and stock Android builds without a default PDF app. This
/// renders via pdfx + PDFium so it works on every device without
/// requiring an external app.
///
/// Caller writes the resume bytes to a Uint8List and passes them in —
/// no temp-file dance, no permission prompts.
class ResumePdfViewerScreen extends StatefulWidget {
  final Uint8List bytes;
  const ResumePdfViewerScreen({super.key, required this.bytes});

  @override
  State<ResumePdfViewerScreen> createState() => _ResumePdfViewerScreenState();
}

class _ResumePdfViewerScreenState extends State<ResumePdfViewerScreen> {
  late final PdfController _controller;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(
      document: PdfDocument.openData(widget.bytes),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: AppText.h4(
          'Your resume',
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: AppText.caption(
                  '$_currentPage / $_totalPages',
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: PdfView(
        controller: _controller,
        scrollDirection: Axis.vertical,
        onDocumentLoaded: (doc) =>
            setState(() => _totalPages = doc.pagesCount),
        onPageChanged: (page) => setState(() => _currentPage = page),
        onDocumentError: (err) {
          // The pdfx surface doesn't bubble its own error to a builder, so
          // we surface a snackbar + close on hard failures (corrupt PDF,
          // password-protected, etc).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open resume: $err'),
                backgroundColor: AppColors.urgent,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).maybePop();
          });
        },
      ),
    );
  }
}
