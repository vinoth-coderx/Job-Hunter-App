import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Shows a voice-search bottom sheet and resolves with the recognized text
/// (or null if cancelled / unavailable).
Future<String?> showVoiceSearchSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => const _VoiceSearchSheet(),
  );
}

class _VoiceSearchSheet extends StatefulWidget {
  const _VoiceSearchSheet();

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late final AnimationController _pulse;

  String _text = '';
  double _level = 0;
  bool _ready = false;
  bool _listening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await _speech.initialize(
        onError: (e) =>
            setState(() => _error = e.errorMsg.isEmpty ? 'Mic error' : e.errorMsg),
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (!mounted) return;
      setState(() => _ready = ok);
      if (ok) _start();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Voice not available on this device');
    }
  }

  Future<void> _start() async {
    if (!_ready) return;
    setState(() {
      _text = '';
      _listening = true;
      _error = null;
    });
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _text = r.recognizedWords);
      },
      onSoundLevelChange: (l) {
        if (!mounted) return;
        setState(() => _level = l);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _stop({bool submit = true}) async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
    if (submit) {
      Navigator.pop(context, _text.trim().isEmpty ? null : _text.trim());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _listening
                  ? 'Listening…'
                  : _error != null
                      ? 'Voice unavailable'
                      : _ready
                          ? 'Tap to speak'
                          : 'Preparing…',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 4),
            Text(
              _listening
                  ? 'Say a job title, skill, or company'
                  : _error ?? 'Searching jobs by voice',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _MicOrb(
              listening: _listening,
              level: _level,
              pulse: _pulse,
              onTap: _listening ? () => _stop(submit: false) : _start,
            ),
            const SizedBox(height: 32),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _text.isEmpty ? '…' : '“$_text”',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: _text.isEmpty
                        ? context.textTertiary
                        : context.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        side: BorderSide(color: context.cardBorder),
                      ),
                      onPressed: () {
                        _speech.cancel();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.button
                            .copyWith(color: context.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      onPressed: _text.trim().isEmpty
                          ? null
                          : () => _stop(submit: true),
                      child: const Text('Search'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicOrb extends StatelessWidget {
  final bool listening;
  final double level;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _MicOrb({
    required this.listening,
    required this.level,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final t = pulse.value;
          final amp = listening ? (0.5 + level.clamp(0, 10) / 20) : 0.0;
          return SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (listening) ...[
                  _ring(160 + 30 * t * amp, 0.18 * (1 - t)),
                  _ring(130 + 20 * t * amp, 0.28 * (1 - t)),
                ],
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: listening ? AppColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: listening
                          ? AppColors.primary
                          : context.cardBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (listening)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Icon(
                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: listening ? Colors.white : context.textPrimary,
                    size: 36,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ring(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: opacity.clamp(0, 1)),
      ),
    );
  }
}
