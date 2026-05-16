import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/security_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Two-screen wizard:
///   1. Show secret + provisioning URI for the user to scan into Google
///      Authenticator / Authy. (We don't render a QR — Flutter would
///      need an extra dep; copying the URI / typing the secret is the
///      fallback path on every authenticator app.)
///   2. Ask for a 6-digit code; on success show one-time backup codes.
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

enum _Stage { loading, showSecret, verify, success, failed }

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _svc = SecurityService.instance;
  final _codeCtrl = TextEditingController();

  _Stage _stage = _Stage.loading;
  String? _secret;
  String? _uri;
  String? _error;
  List<String> _backupCodes = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final data = await _svc.start2faEnrollment();
      if (!mounted) return;
      setState(() {
        _secret = data['secret'] as String?;
        _uri = data['uri'] as String?;
        _stage = _Stage.showSecret;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final codes = await _svc.finish2faEnrollment(_codeCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _backupCodes = codes;
        _stage = _Stage.success;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Two-factor', style: AppTextStyles.h3)),
      body: SafeArea(child: _buildStage()),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.loading:
        return const Center(child: CircularProgressIndicator());
      case _Stage.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppText.body(
              _error ?? 'Could not start enrollment.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case _Stage.showSecret:
        return _SecretView(
          secret: _secret ?? '',
          uri: _uri ?? '',
          onContinue: () => setState(() => _stage = _Stage.verify),
        );
      case _Stage.verify:
        return _VerifyView(
          controller: _codeCtrl,
          busy: _busy,
          onVerify: _verify,
        );
      case _Stage.success:
        return _SuccessView(
          codes: _backupCodes,
          onDone: () => Navigator.of(context).pop(true),
        );
    }
  }
}

class _SecretView extends StatelessWidget {
  const _SecretView({
    required this.secret,
    required this.uri,
    required this.onContinue,
  });
  final String secret;
  final String uri;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText.h4('Add this account to your authenticator app'),
          const SizedBox(height: 12),
          AppText.body(
            'Open Google Authenticator, Authy, 1Password or any TOTP app. Choose "Set up account → Enter a setup key", give it the name Job Hunter, and paste the secret below.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    secret,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: secret));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Secret copied')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppText.caption(
            'Or paste this URI into your authenticator if it supports it:',
          ),
          const SizedBox(height: 6),
          SelectableText(
            uri,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          PrimaryButton(label: 'I added it', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _VerifyView extends StatelessWidget {
  const _VerifyView({
    required this.controller,
    required this.busy,
    required this.onVerify,
  });
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText.h4('Enter the 6-digit code'),
          const SizedBox(height: 8),
          AppText.body(
            'Your authenticator shows a fresh code every 30 seconds. Type the current one to finish setup.',
          ),
          const SizedBox(height: 24),
          CustomTextField(
            controller: controller,
            hint: '123 456',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Verify and enable',
            isLoading: busy,
            onPressed: busy ? null : onVerify,
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.codes, required this.onDone});
  final List<String> codes;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText.h4('Save these backup codes'),
          const SizedBox(height: 8),
          AppText.body(
            'If you lose your authenticator app, each code below can be used once to sign in. Keep them somewhere safe — they will not be shown again.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                codes.join('\n'),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy all'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codes.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup codes copied')),
              );
            },
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}
