import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/mock_interview_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Run a live AI mock interview. Two modes of entry:
///   - Setup → start: user picks role + type, the screen creates the
///     session and displays the first interviewer question.
///   - Answer loop: user types their answer; we POST it to /answer,
///     show inline feedback for that answer, then display the next Q.
///   - Finish: when the backend says shouldFinish, we POST /finish and
///     show the final summary screen inline.
class MockInterviewScreen extends StatefulWidget {
  /// Pre-selects the interview type (e.g. when entering from the prep
  /// hub's System Design track) so the user doesn't have to set it again.
  final String? initialType;

  /// Optional pre-filled role hint shown above the type picker.
  final String? roleHint;

  const MockInterviewScreen({super.key, this.initialType, this.roleHint});

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  final MockInterviewService _service = MockInterviewService.instance;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Setup state
  final TextEditingController _role = TextEditingController();
  late String _type = widget.initialType ?? 'behavioural';

  // Voice input — same package the search sheet uses, so we share the
  // mic permission once granted. The recognizer streams partial results
  // into _input so the user can edit before sending.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _voiceBuffer = ''; // text in _input before listening began

  @override
  void initState() {
    super.initState();
    if (widget.roleHint != null && widget.roleHint!.isNotEmpty) {
      _role.text = widget.roleHint!;
    }
  }

  // Live session state
  MockInterviewSession? _session;
  final List<_TranscriptItem> _transcript = [];
  bool _busy = false;
  bool _completed = false;
  MockInterviewSummary? _summary;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _role.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_role.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the target role')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final s = await _service.start(
        role: _role.text.trim(),
        interviewType: _type,
      );
      if (!mounted) return;
      setState(() {
        _session = s;
        _transcript.add(_TranscriptItem.question(s.latestQuestion));
        _busy = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not start: $e')));
    }
  }

  Future<void> _send() async {
    final s = _session;
    if (s == null || _busy || _completed) return;
    if (_listening) await _stopVoice(); // mic off before submit
    final text = _input.text.trim();
    if (text.isEmpty) return;

    _input.clear();
    setState(() {
      _transcript.add(_TranscriptItem.answer(text));
      _busy = true;
    });
    _scrollToEnd();

    try {
      final res = await _service.answer(id: s.id, answer: text);
      if (!mounted) return;
      setState(() {
        if (res.latestFeedback != null) {
          _transcript.add(_TranscriptItem.feedback(res.latestFeedback!));
        }
        if (res.answerWasIrrelevant) {
          // Off-topic: don't push the question (it's the same one).
          // Surface a system warning so the user knows to retry, and
          // restore their text so they can edit instead of retyping.
          _transcript.add(_TranscriptItem.system(
            res.latestQuestion.isNotEmpty
                ? res.latestQuestion
                : 'Your answer didn\'t address the question. '
                    'Please answer it directly.',
          ));
          _input.text = text;
          _input.selection = TextSelection.collapsed(offset: text.length);
        } else {
          _transcript.add(_TranscriptItem.question(res.latestQuestion));
        }
        _busy = false;
      });
      _scrollToEnd();
      if (res.shouldFinish && !res.answerWasIrrelevant) {
        await _finish();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not send: $e')));
    }
  }

  /// Tap the mic to dictate the answer instead of typing. Partial
  /// results stream into _input so the user sees what we heard. Tapping
  /// again stops listening; the buffered text remains for review/edit
  /// before sending.
  Future<void> _toggleVoice() async {
    if (_busy) return;
    if (_listening) {
      await _stopVoice();
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() => _listening = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Mic error: ${e.errorMsg}'),
          ));
        },
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (!_speechReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Voice unavailable on this device'),
        ));
        return;
      }
    }
    _voiceBuffer = _input.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        final glue = _voiceBuffer.isEmpty ||
                _voiceBuffer.endsWith(' ') ||
                _voiceBuffer.endsWith('\n')
            ? ''
            : ' ';
        final next = '$_voiceBuffer$glue${r.recognizedWords}';
        setState(() {
          _input.text = next;
          _input.selection = TextSelection.collapsed(offset: next.length);
        });
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
  }

  Future<void> _stopVoice() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
  }

  void _insertSkill(String skill) {
    final cur = _input.text;
    final glue = cur.isEmpty || cur.endsWith(' ') || cur.endsWith('\n')
        ? ''
        : ' ';
    final next = '$cur$glue$skill ';
    _input.text = next;
    _input.selection = TextSelection.collapsed(offset: next.length);
  }

  Future<void> _finish() async {
    final s = _session;
    if (s == null) return;
    setState(() => _busy = true);
    try {
      final summary = await _service.finish(s.id);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _completed = true;
        _busy = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not finish: $e')));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('AI mock interview'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _session == null ? _setupView() : _liveView(),
    );
  }

  // ── Setup ────────────────────────────────────────────────────────
  Widget _setupView() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const AppText.h3('Practice for a real interview'),
          const SizedBox(height: 4),
          const AppText.caption(
            'AI plays the interviewer. We score each of your answers and give you a final summary.',
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _role,
            label: 'Target role',
            hint: 'e.g., Senior Backend Engineer',
          ),
          const SizedBox(height: 12),
          const AppText.caption('Interview type'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: const [
              ('behavioural', 'Behavioural'),
              ('hr', 'HR'),
              ('technical', 'Technical'),
              ('system_design', 'System design'),
            ].map((t) {
              return ChoiceChip(
                label: Text(t.$2),
                selected: _type == t.$1,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _type = t.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Start interview',
            icon: Icons.play_arrow,
            isLoading: _busy,
            onPressed: _busy ? null : _start,
          ),
        ],
      );

  // ── Live ──────────────────────────────────────────────────────────
  Widget _liveView() {
    final s = _session!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          color: context.surface,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.role} · ${s.interviewType}',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text('Q ${s.questionsAsked} of ${s.questionsTarget}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: context.textSecondary)),
                  ],
                ),
              ),
              if (!_completed)
                TextButton.icon(
                  onPressed: _busy ? null : _finish,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('End'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _transcript.length + (_summary != null ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _transcript.length && _summary != null) {
                return _summaryCard(_summary!);
              }
              return _transcriptBubble(_transcript[i]);
            },
          ),
        ),
        if (!_completed) _inputBar(),
      ],
    );
  }

  /// Bottom composer: profile-derived skill chips above the field, then
  /// text input + mic toggle + send. The chips give the user a 1-tap
  /// way to mention something they actually claim, which encourages
  /// answers grounded in their real experience.
  Widget _inputBar() {
    final user = context.watch<AuthProvider>().user;
    final skills = (user?.skills ?? const <String>[])
        .where((s) => s.trim().isNotEmpty)
        .take(12)
        .toList();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: context.surface,
          border: Border(top: BorderSide(color: context.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (skills.isNotEmpty) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: skills.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ActionChip(
                    label: Text(skills[i]),
                    labelStyle: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                    onPressed: _busy ? null : () => _insertSkill(skills[i]),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 6,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Listening… speak your answer'
                          : 'Type your answer or tap the mic…',
                      filled: true,
                      fillColor: context.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _composerButton(
                  onTap: _busy ? null : _toggleVoice,
                  bg: _listening
                      ? AppColors.urgent
                      : AppColors.primary.withValues(alpha: 0.10),
                  child: Icon(
                    _listening
                        ? Icons.stop_rounded
                        : Icons.mic_none_rounded,
                    color: _listening ? Colors.white : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 6),
                _composerButton(
                  onTap: _busy ? null : _send,
                  bg: AppColors.primary,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composerButton({
    required VoidCallback? onTap,
    required Color bg,
    required Widget child,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: child),
      ),
    );
  }

  Widget _transcriptBubble(_TranscriptItem item) {
    if (item.kind == _ItemKind.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.urgent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.urgent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.report_gmailerrorred,
                size: 18, color: AppColors.urgent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.text ?? '',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.urgent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (item.kind == _ItemKind.feedback) {
      final f = item.feedback!;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Text('Inline feedback',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            if (f.relevance != null ||
                f.depth != null ||
                f.communication != null)
              Wrap(
                spacing: 12,
                children: [
                  if (f.relevance != null) _scoreLabel('Relevance', f.relevance!),
                  if (f.depth != null) _scoreLabel('Depth', f.depth!),
                  if (f.communication != null)
                    _scoreLabel('Comms', f.communication!),
                ],
              ),
            if (f.suggestion != null && f.suggestion!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(f.suggestion!,
                  style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      );
    }
    final mine = item.kind == _ItemKind.answer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : context.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                border:
                    mine ? null : Border.all(color: context.cardBorder),
              ),
              child: Text(
                item.text!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: mine ? Colors.white : context.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreLabel(String label, int v) => Text(
        '$label $v',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _summaryCard(MockInterviewSummary s) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.primary.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Final score: ${s.finalScore}/100',
                    style: AppTextStyles.h3
                        .copyWith(color: context.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(s.finalSummary,
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
}

enum _ItemKind { question, answer, feedback, system }

class _TranscriptItem {
  final _ItemKind kind;
  final String? text;
  final MockTurnFeedback? feedback;
  const _TranscriptItem._(this.kind, {this.text, this.feedback});
  factory _TranscriptItem.question(String text) =>
      _TranscriptItem._(_ItemKind.question, text: text);
  factory _TranscriptItem.answer(String text) =>
      _TranscriptItem._(_ItemKind.answer, text: text);
  factory _TranscriptItem.feedback(MockTurnFeedback f) =>
      _TranscriptItem._(_ItemKind.feedback, feedback: f);
  /// Inline notice from the AI (e.g. "stay on topic"). Rendered as a
  /// neutral banner — neither question nor answer.
  factory _TranscriptItem.system(String text) =>
      _TranscriptItem._(_ItemKind.system, text: text);
}
