import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// In-app browser for the official Apply page. The user submits the
/// application on the company's site here; once they close the screen
/// the caller asks them whether they actually completed it, so we only
/// mark it Applied when they confirm.
class ApplyWebviewScreen extends StatefulWidget {
  final String url;
  final String company;

  const ApplyWebviewScreen({
    super.key,
    required this.url,
    required this.company,
  });

  @override
  State<ApplyWebviewScreen> createState() => _ApplyWebviewScreenState();
}

class _ApplyWebviewScreenState extends State<ApplyWebviewScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  String _currentHost = '';
  bool _hasError = false;

  /// When the user opened the page. We only prompt "Did you apply?" if
  /// they've spent a meaningful amount of time on it — short-tap exits
  /// just close silently so no nag-modal appears for accidental opens.
  late final DateTime _openedAt;
  static const Duration _confirmThreshold = Duration(minutes: 1);
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    final uri = Uri.tryParse(widget.url);
    _currentHost = uri?.host ?? widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageStarted: (url) {
            final host = Uri.tryParse(url)?.host;
            if (host != null && host.isNotEmpty) {
              setState(() {
                _currentHost = host;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) => setState(() => _progress = 1),
          onWebResourceError: (err) {
            // Only surface main-frame errors; subresource failures (ads, fonts)
            // are noisy on real job sites.
            if (err.isForMainFrame ?? false) {
              setState(() => _hasError = true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleBack() async {
    if (_confirmed) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (!mounted) return;

    final elapsed = DateTime.now().difference(_openedAt);
    if (elapsed < _confirmThreshold) {
      // Quick exits = "didn't apply". No modal — just close silently.
      Navigator.pop<bool>(context, false);
      return;
    }

    final result = await _showApplyConfirmSheet();
    if (!mounted) return;
    if (result == _ApplySheetResult.applied) {
      _confirmed = true;
      Navigator.pop<bool>(context, true);
    } else if (result == _ApplySheetResult.notYet) {
      Navigator.pop<bool>(context, false);
    }
    // result == continueBrowsing → stay on the webview.
  }

  Future<_ApplySheetResult?> _showApplyConfirmSheet() {
    return showModalBottomSheet<_ApplySheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyConfirmSheet(company: widget.company),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.scaffoldBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
            onPressed: _handleBack,
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.company,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 11, color: context.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _currentHost,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: context.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh_rounded, color: Colors.black),
              onPressed: () {
                setState(() => _hasError = false);
                _controller.reload();
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _progress > 0 && _progress < 1
                ? LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  )
                : const SizedBox(height: 2),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_hasError) _ErrorOverlay(onRetry: () {
                setState(() => _hasError = false);
                _controller.reload();
              }),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ApplySheetResult { applied, notYet, continueBrowsing }

/// Polished bottom-sheet shown when the user taps back after spending
/// 1+ min on the apply page. Three outcomes:
///   * applied            → caller marks the job as applied
///   * notYet             → caller closes without marking applied
///   * continueBrowsing   → caller stays on the webview
///
/// Uses one master controller to stagger the icon bounce, title/subtitle
/// slide-up, and button fade. Composite-only ops (Transform/Opacity) so
/// the GPU does the work and the slide-in stays smooth.
class _ApplyConfirmSheet extends StatefulWidget {
  final String company;
  const _ApplyConfirmSheet({required this.company});

  @override
  State<_ApplyConfirmSheet> createState() => _ApplyConfirmSheetState();
}

class _ApplyConfirmSheetState extends State<_ApplyConfirmSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _iconScale;
  late final Animation<double> _titleT;
  late final Animation<double> _subT;
  late final Animation<double> _btn1T;
  late final Animation<double> _btn2T;
  late final Animation<double> _btn3T;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      // Reverse plays alongside the bottom-sheet's slide-down so the
      // inner stagger un-staggers as the sheet exits — symmetric with
      // the slide-up + stagger entry.
      reverseDuration: const Duration(milliseconds: 260),
    );
    _iconScale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      reverseCurve: const Interval(0.0, 0.55, curve: Curves.easeInCubic),
    );
    _titleT = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.20, 0.60, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.20, 0.60, curve: Curves.easeInCubic),
    );
    _subT = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.30, 0.70, curve: Curves.easeInCubic),
    );
    _btn1T = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.40, 0.80, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.40, 0.80, curve: Curves.easeInCubic),
    );
    _btn2T = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.50, 0.90, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.50, 0.90, curve: Curves.easeInCubic),
    );
    _btn3T = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.60, 1.00, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.60, 1.00, curve: Curves.easeInCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Run the entry stagger in reverse, then close the sheet. Fire-and-
  /// forget — the bottom-sheet's slide-down (~250ms) plays in parallel
  /// so the two motions land at the same time.
  void _dismiss(_ApplySheetResult result) {
    _c.reverse();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: context.cardBorder,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            AnimatedBuilder(
              animation: _iconScale,
              builder: (_, child) => Transform.scale(
                scale: _iconScale.value,
                child: child,
              ),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SheetSlideFade(
              t: _titleT,
              child: Text(
                'Did you apply at ${widget.company}?',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SheetSlideFade(
              t: _subT,
              child: Text(
                "We'll save it to your tracked applications so you can follow up later.",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _SheetSlideFade(
              t: _btn1T,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _dismiss(_ApplySheetResult.applied),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    "Yes, I've applied",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _SheetSlideFade(
              t: _btn2T,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _dismiss(_ApplySheetResult.notYet),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: context.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Not yet',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _SheetSlideFade(
              t: _btn3T,
              child: TextButton(
                onPressed: () => _dismiss(_ApplySheetResult.continueBrowsing),
                style: TextButton.styleFrom(
                  foregroundColor: context.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Keep browsing',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSlideFade extends StatelessWidget {
  final Animation<double> t;
  final Widget child;
  const _SheetSlideFade({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (_, c) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - t.value) * 10),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorOverlay({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 56, color: context.textTertiary),
          const SizedBox(height: 16),
          Text("Couldn't load the page", style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            'Check your connection and try again.',
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
