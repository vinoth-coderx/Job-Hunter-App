import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// In-app browser for the official Apply page. The caller treats the
/// CTA tap itself as the intent-to-apply signal and marks the job
/// applied automatically once this screen closes — so this widget no
/// longer asks the user "Did you apply?" on back.
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

  @override
  void initState() {
    super.initState();
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
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
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
