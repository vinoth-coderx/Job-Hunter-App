import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/resume_template_model.dart';
import '../../data/services/api_client.dart';
import '../../data/services/resume_template_service.dart';
import '../widgets/app_text.dart';

/// Lists published resume templates and lets the seeker preview them
/// pre-filled with their own profile data.
///
/// Why pre-fill happens client-side: the backend only stores the template
/// HTML with Mustache-style placeholders, and the user's profile is
/// already in the in-memory AuthProvider. Rendering it locally avoids an
/// extra round-trip and keeps the user's resume text from leaving the
/// device when they're just browsing.
class ResumeTemplatePickerScreen extends StatefulWidget {
  const ResumeTemplatePickerScreen({super.key});

  @override
  State<ResumeTemplatePickerScreen> createState() =>
      _ResumeTemplatePickerScreenState();
}

class _ResumeTemplatePickerScreenState
    extends State<ResumeTemplatePickerScreen> {
  late Future<List<ResumeTemplateSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = ResumeTemplateService.instance.list();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ResumeTemplateService.instance.list();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const AppText.h4(
          'Resume templates',
          fontWeight: FontWeight.w700,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ResumeTemplateSummary>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(
                message: '${snap.error}',
                onRetry: _refresh,
              );
            }
            final items = snap.data ?? const <ResumeTemplateSummary>[];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: AppText.body(
                      'No templates available yet. Check back soon.',
                    ),
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  _TemplateCard(template: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final ResumeTemplateSummary template;
  const _TemplateCard({required this.template});

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ResumeTemplatePreviewScreen(slug: template.slug),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.smRadius,
                  child: Container(
                    color: context.surfaceVariant,
                    alignment: Alignment.center,
                    child: template.previewImageUrl != null
                        ? Image.network(
                            template.previewImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.description_outlined,
                              size: 48,
                            ),
                          )
                        : const Icon(
                            Icons.description_outlined,
                            size: 48,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppText.label(
                template.name,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _scoreColor(template.atsScore).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: AppRadius.pillRadius,
                    ),
                    child: AppText.caption(
                      'ATS ${template.atsScore}',
                      color: _scoreColor(template.atsScore),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (template.isPremium) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: const AppText.caption(
                        'PRO',
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              AppText.body('Couldn\'t load templates'),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AppText.caption(
                  message,
                  textAlign: TextAlign.center,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two-stage template preview:
///
///   Stage 1 — **Sample**: on open, fetch the PDF rendered with stable
///   placeholder values so the seeker can see what a finished resume in
///   this template looks like. Bottom action bar offers
///   "Download sample" + "Insert my data".
///
///   Stage 2 — **My data**: when the seeker taps "Insert my data", we
///   call the quota-gated `/download` endpoint which fills the template
///   with the seeker's profile + resume essentials and re-renders. The
///   PDF view replaces in place; the action bar collapses to "Download".
///
/// Why PDF-only (was WebView+PDF): WebView rendering forced two render
/// pipelines (client-side string substitution → device font fallback)
/// and consistently produced different output from the downloaded PDF
/// (server Puppeteer + bundled Inter font). One pipeline = one output,
/// no surprises after download.
class ResumeTemplatePreviewScreen extends StatefulWidget {
  final String slug;
  const ResumeTemplatePreviewScreen({super.key, required this.slug});

  @override
  State<ResumeTemplatePreviewScreen> createState() =>
      _ResumeTemplatePreviewScreenState();
}

enum _PreviewMode { sample, mine }

class _ResumeTemplatePreviewScreenState
    extends State<ResumeTemplatePreviewScreen> {
  late Future<ResumeTemplateDetail> _detailFuture;
  TemplateDownloadQuota? _quota;

  /// Bytes for whichever PDF is currently on-screen. Kept in state so
  /// the "Download" CTA can save the exact buffer the seeker is looking
  /// at without re-fetching (important for `mine` since it consumes a
  /// quota credit on every server hit).
  Uint8List? _pdfBytes;
  PdfController? _pdfController;

  _PreviewMode _mode = _PreviewMode.sample;
  bool _loadingPdf = false;
  bool _filling = false;
  bool _saving = false;
  int _currentPage = 1;
  int _totalPages = 0;
  /// Monotonic counter used as a `ValueKey` on `PdfView`. Bumping it on
  /// every `_swapPdf` forces a widget remount so the new document is
  /// actually rendered (pdfx caches the first-attached document
  /// otherwise).
  int _pdfKey = 0;

  @override
  void initState() {
    super.initState();
    _detailFuture = ResumeTemplateService.instance.get(widget.slug);
    _loadQuota();
    _loadSamplePdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadQuota() async {
    try {
      final q = await ResumeTemplateService.instance.quota();
      if (mounted) setState(() => _quota = q);
    } catch (_) {
      // Non-fatal — the download endpoint enforces the same cap.
    }
  }

  Future<void> _loadSamplePdf() async {
    if (_loadingPdf) return;
    setState(() => _loadingPdf = true);
    try {
      final bytes =
          await ResumeTemplateService.instance.previewSample(widget.slug);
      if (!mounted) return;
      _swapPdf(bytes, _PreviewMode.sample);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Couldn\'t load preview: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Couldn\'t load preview: $e');
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  /// Replaces the on-screen PDF. Disposes the previous controller so the
  /// underlying PDFium document doesn't linger in memory after a swap.
  ///
  /// `_pdfKey` is bumped on every swap so the `PdfView` widget itself
  /// gets a fresh state — without that, pdfx keeps rendering the
  /// originally-attached document even though the controller pointer
  /// changed (the widget reuses internal _PageController state on
  /// element identity). That's what produced the blank "Your resume"
  /// page right after tapping "Insert my data".
  void _swapPdf(Uint8List bytes, _PreviewMode mode) {
    _pdfController?.dispose();
    setState(() {
      _pdfBytes = bytes;
      _mode = mode;
      _currentPage = 1;
      _totalPages = 0;
      _pdfKey += 1;
      _pdfController = PdfController(document: PdfDocument.openData(bytes));
    });
  }

  Future<void> _onInsertMyData() async {
    if (_filling) return;
    setState(() => _filling = true);
    try {
      final bytes = await ResumeTemplateService.instance.download(widget.slug);
      if (!mounted) return;
      _swapPdf(bytes, _PreviewMode.mine);
      // Server decremented the quota — refresh the banner.
      await _loadQuota();
      if (!mounted) return;
      AppSnackbar.success(context, 'Your details inserted');
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        e.statusCode == 403 ? e.message : 'Couldn\'t fill in: ${e.message}',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Couldn\'t fill in: $e');
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  /// Opens the system share/save sheet for the currently-shown PDF.
  ///
  /// Why a share sheet instead of `writeAsBytes` to the app's document
  /// dir: that directory is **invisible to the File Manager on
  /// Android** (it's the private app sandbox under `/data/user/0/...`),
  /// so the seeker would see a "Saved" toast and then have no way to
  /// actually find the file. Routing through `Share.shareXFiles` hands
  /// the bytes to whatever target the user picks — "Save to Files",
  /// Downloads, Drive, WhatsApp, email — all of which write to a
  /// location the OS file picker can reach. iOS behaves the same way
  /// via the UIDocumentInteractionController.
  Future<void> _onDownload() async {
    final bytes = _pdfBytes;
    if (bytes == null || _saving) return;
    setState(() => _saving = true);
    try {
      // Stage the bytes in the temp dir under a meaningful filename so
      // the receiving app (Drive, Files, etc.) shows the right name.
      final dir = await getTemporaryDirectory();
      final suffix = _mode == _PreviewMode.sample ? 'sample' : 'mine';
      final file = File('${dir.path}/resume_${widget.slug}_$suffix.pdf');
      await file.writeAsBytes(bytes, flush: true);

      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Resume — ${widget.slug}',
          text: _mode == _PreviewMode.sample
              ? 'Sample resume from Job Hunter'
              : 'My resume from Job Hunter',
        );
      } on MissingPluginException {
        // share_plus' native plugin wasn't registered into this build —
        // either the app needs a full rebuild after the dependency was
        // added (`flutter clean && flutter run`), or this is a desktop
        // host without the platform implementation. Fall back to a
        // plain save in the app documents directory so the seeker
        // *something*. Tell them how to recover.
        await _saveToDocuments(bytes, suffix);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Last-resort save path used when `share_plus` isn't available. The
  /// app's documents directory is private on Android, so the only way
  /// to surface the file is to spell out the full path in the toast and
  /// let the seeker reach it via their preferred file manager.
  Future<void> _saveToDocuments(Uint8List bytes, String suffix) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/resume_${widget.slug}_${suffix}_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    AppSnackbar.info(
      context,
      'Share unavailable — rebuild the app to enable the system share '
      'sheet. Saved a copy to ${file.path}',
    );
  }

  String _quotaSubtitle(TemplateDownloadQuota q) {
    if (q.blocked) return 'Upgrade your plan to unlock downloads';
    if (q.unlimited) return 'Unlimited downloads this month';
    final left = q.remaining ?? 0;
    return '$left of ${q.limit} downloads left this month';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppText.h4(
          _mode == _PreviewMode.sample ? 'Sample preview' : 'Your resume',
          fontWeight: FontWeight.w700,
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: AppText.caption(
                  '$_currentPage / $_totalPages',
                  color: context.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<ResumeTemplateDetail>(
        future: _detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText.body(
                  'Couldn\'t load template: ${snap.error ?? "unknown error"}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final detail = snap.data!;
          return Column(
            children: [
              _headerBar(detail),
              Expanded(child: _pdfBody()),
              _actionBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _headerBar(ResumeTemplateDetail detail) {
    final q = _quota;
    return Container(
      color: context.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.h4(detail.name, fontWeight: FontWeight.w700),
          const SizedBox(height: 2),
          AppText.caption(
            'ATS ${detail.atsScore}/100 · ${detail.category}',
            color: context.textSecondary,
          ),
          if (_mode == _PreviewMode.sample) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: AppText.caption(
                'Sample data — tap "Insert my data" to use yours',
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (q != null) ...[
            const SizedBox(height: 4),
            AppText.caption(
              _quotaSubtitle(q),
              color: q.blocked || q.exhausted
                  ? AppColors.warning
                  : context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ],
        ],
      ),
    );
  }

  Widget _pdfBody() {
    final ctrl = _pdfController;
    if (_loadingPdf || ctrl == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: Colors.white,
      child: PdfView(
        key: ValueKey<int>(_pdfKey),
        controller: ctrl,
        scrollDirection: Axis.vertical,
        onDocumentLoaded: (doc) =>
            setState(() => _totalPages = doc.pagesCount),
        onPageChanged: (page) => setState(() => _currentPage = page),
        onDocumentError: (err) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            AppSnackbar.error(context, 'Could not render PDF: $err');
          });
        },
      ),
    );
  }

  Widget _actionBar() {
    final q = _quota;
    final isSample = _mode == _PreviewMode.sample;

    // Free tier (or any tier the admin set to limit=0) → both download
    // and "Insert my data" are paid features. Swap the entire action
    // row for a single "Subscribe" CTA so the gate is unambiguous —
    // disabled buttons read as "broken", a subscribe CTA reads as
    // "unlock this".
    if (q != null && q.blocked) {
      return SafeArea(
        top: false,
        child: Container(
          color: context.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving
                ? null
                : () => Navigator.of(context).pushNamed(AppRoutes.subscription),
            icon: const Icon(Icons.workspace_premium_rounded, size: 18),
            label: const Text('Subscribe to download'),
          ),
        ),
      );
    }

    final fillDisabled =
        _filling || _loadingPdf || (q != null && q.exhausted);
    final downloadDisabled = _pdfBytes == null || _saving || _loadingPdf;

    return SafeArea(
      top: false,
      child: Container(
        color: context.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: downloadDisabled ? null : _onDownload,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  isSample ? 'Download sample' : 'Download',
                ),
              ),
            ),
            if (isSample) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: fillDisabled ? null : _onInsertMyData,
                  icon: _filling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_rounded, size: 18),
                  label: Text(_filling ? 'Filling…' : 'Insert my data'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
