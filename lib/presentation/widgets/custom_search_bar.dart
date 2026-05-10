import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class CustomSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final VoidCallback? onFilterTap;
  final VoidCallback? onMicTap;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool showFilter;
  final bool showMic;
  final bool isListening;
  final VoidCallback? onTap;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Search jobs, companies, skills',
    this.onFilterTap,
    this.onMicTap,
    this.onClear,
    this.onChanged,
    this.onSubmitted,
    this.showFilter = true,
    this.showMic = true,
    this.isListening = false,
    this.onTap,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;
  bool _ownsFocusNode = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;
    _focusNode.addListener(_onChange);
    _controller.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onChange);
    _controller.removeListener(_onChange);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFocus = _focusNode.hasFocus;
    final hasText = _controller.text.isNotEmpty;
    final active = hasFocus || hasText || widget.isListening;

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 56,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: active ? AppColors.primary : context.cardBorder,
                width: active ? 1.5 : 1,
              ),
              boxShadow: [
                if (active)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  color: active ? AppColors.primary : context.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    onTap: widget.onTap,
                    readOnly: widget.onTap != null,
                    textInputAction: TextInputAction.search,
                    cursorColor: AppColors.primary,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: context.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                if (hasText)
                  _IconButton(
                    icon: Icons.close_rounded,
                    color: context.textTertiary,
                    onTap: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                      widget.onClear?.call();
                    },
                  ),
                if (widget.showMic)
                  _MicButton(
                    listening: widget.isListening,
                    onTap: widget.onMicTap,
                  ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
        if (widget.showFilter) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.chipSelectedBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  final bool listening;
  final VoidCallback? onTap;

  const _MicButton({required this.listening, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant _MicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: widget.onTap,
      radius: 22,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final scale = widget.listening ? 1 + 0.12 * _pulse.value : 1.0;
          return Padding(
            padding: const EdgeInsets.all(6),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.listening
                      ? AppColors.primary
                      : Colors.transparent,
                ),
                child: Icon(
                  widget.listening
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                  size: 20,
                  color: widget.listening
                      ? Colors.white
                      : context.textTertiary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
