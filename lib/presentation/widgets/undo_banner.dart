import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class UndoBanner {
  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext context,
    required String message,
    required VoidCallback onUndo,
    IconData icon = Icons.history_rounded,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    if (_currentEntry?.mounted ?? false) {
      _currentEntry!.remove();
    }
    _currentEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _UndoBannerOverlay(
        message: message,
        icon: icon,
        onUndo: onUndo,
        duration: duration,
        onDismissed: () {
          if (_currentEntry == entry) _currentEntry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );

    _currentEntry = entry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (entry == _currentEntry && !entry.mounted) {
        overlay.insert(entry);
      }
    });
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _UndoBannerOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final VoidCallback onUndo;
  final Duration duration;
  final VoidCallback onDismissed;

  const _UndoBannerOverlay({
    required this.message,
    required this.icon,
    required this.onUndo,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_UndoBannerOverlay> createState() => _UndoBannerOverlayState();
}

class _UndoBannerOverlayState extends State<_UndoBannerOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final AnimationController _progress;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween(begin: const Offset(0, -1.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);

    _progress = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();

    _ac.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _ac.reverse();
    if (mounted) widget.onDismissed();
  }

  Future<void> _handleUndo() async {
    if (_closing) return;
    widget.onUndo();
    await _close();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ac.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Row(
                          children: [
                            Icon(widget.icon,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _handleUndo,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                minimumSize: const Size(0, 36),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Undo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _close,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (_, __) => LinearProgressIndicator(
                            value: 1 - _progress.value,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
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
