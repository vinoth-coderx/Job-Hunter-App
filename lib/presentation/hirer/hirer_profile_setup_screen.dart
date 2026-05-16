import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/hirer_profile_model.dart';
import '../../data/services/hirer_service.dart';
import '../../providers/hirer_provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Hirer profile setup / edit. First-time visitors see "Create company".
/// Returning visitors see "Update company" with existing values prefilled.
class HirerProfileSetupScreen extends StatefulWidget {
  const HirerProfileSetupScreen({super.key});

  @override
  State<HirerProfileSetupScreen> createState() =>
      _HirerProfileSetupScreenState();
}

class _HirerProfileSetupScreenState extends State<HirerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _industry = TextEditingController();
  final _website = TextEditingController();
  final _description = TextEditingController();
  final _hqCity = TextEditingController();
  final _hqState = TextEditingController();
  final _linkedin = TextEditingController();
  final _twitter = TextEditingController();
  final _foundedYearCtrl = TextEditingController();

  String? _companySize;
  int? _foundedYear;
  File? _pendingLogo;
  bool _prefilled = false;
  bool _generatingDescription = false;

  static const _sizes = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500-1000',
    '1000+',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<HirerProvider>();
      if (prov.profile == null && !prov.loading) prov.load();
    });
  }

  void _prefillFrom(HirerProfile p) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = p.companyName;
    _industry.text = p.industry ?? '';
    _website.text = p.website ?? '';
    _description.text = p.description ?? '';
    _hqCity.text = p.headquarters?.city ?? '';
    _hqState.text = p.headquarters?.state ?? '';
    _linkedin.text = p.socialLinks?.linkedin ?? '';
    _twitter.text = p.socialLinks?.twitter ?? '';
    _companySize = p.companySize;
    _foundedYear = p.foundedYear;
    _foundedYearCtrl.text = p.foundedYear?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _industry.dispose();
    _website.dispose();
    _description.dispose();
    _hqCity.dispose();
    _hqState.dispose();
    _linkedin.dispose();
    _twitter.dispose();
    _foundedYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateDescription() async {
    if (_generatingDescription) return;
    if (_name.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add the company name first'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _generatingDescription = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await HirerService.instance.generateCompanyDescription(
        companyName: _name.text.trim(),
        industry: _industry.text.trim(),
        sizeBand: _companySize,
        hqLocation: [_hqCity.text.trim(), _hqState.text.trim()]
            .where((s) => s.isNotEmpty)
            .join(', '),
        whatYouDo: _description.text.trim(),
        toneHint: 'professional',
      );
      if (!mounted) return;
      if (result.description.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('AI is unavailable right now — try again in a bit'),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        setState(() => _description.text = result.description);
        messenger.showSnackBar(SnackBar(
          content: Text(result.cached
              ? 'Drafted from cache — edit before saving'
              : 'AI draft ready — edit before saving'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Could not generate: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _generatingDescription = false);
    }
  }

  Future<void> _pickLogo() async {
    // Restrict client-side to the same MIMEs the backend accepts, so the
    // user can't pick a HEIC / GIF and then hit "Only JPG, PNG, or WEBP
    // image files are allowed" after the fact.
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null) return;
    setState(() => _pendingLogo = File(path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<HirerProvider>();
    final isEdit = prov.profile != null;

    final headquarters = (_hqCity.text.trim().isEmpty &&
            _hqState.text.trim().isEmpty)
        ? null
        : CompanyHeadquarters(
            city: _hqCity.text.trim().isEmpty ? null : _hqCity.text.trim(),
            state: _hqState.text.trim().isEmpty ? null : _hqState.text.trim(),
            country: 'India',
          );

    final social = (_linkedin.text.trim().isEmpty &&
            _twitter.text.trim().isEmpty)
        ? null
        : CompanySocialLinks(
            linkedin:
                _linkedin.text.trim().isEmpty ? null : _linkedin.text.trim(),
            twitter:
                _twitter.text.trim().isEmpty ? null : _twitter.text.trim(),
          );

    final ok = isEdit
        ? await prov.update(
            companyName: _name.text.trim(),
            industry:
                _industry.text.trim().isEmpty ? null : _industry.text.trim(),
            companySize: _companySize,
            foundedYear: _foundedYear,
            website:
                _website.text.trim().isEmpty ? null : _website.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            headquarters: headquarters,
            socialLinks: social,
          )
        : await prov.create(
            companyName: _name.text.trim(),
            industry:
                _industry.text.trim().isEmpty ? null : _industry.text.trim(),
            companySize: _companySize,
            foundedYear: _foundedYear,
            website:
                _website.text.trim().isEmpty ? null : _website.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            headquarters: headquarters,
            socialLinks: social,
          );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.error ?? 'Could not save profile')),
      );
      return;
    }

    if (_pendingLogo != null) {
      final logoOk = await prov.uploadLogo(_pendingLogo!);
      if (!mounted) return;
      if (!logoOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(prov.error ?? 'Profile saved, logo upload failed')),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Company profile updated' : 'Company profile created'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HirerProvider>(
      builder: (context, prov, _) {
        if (prov.profile != null) _prefillFrom(prov.profile!);
        final isEdit = prov.profile != null;
        return Scaffold(
          backgroundColor: context.scaffoldBg,
          appBar: AppBar(
            title: Text(isEdit ? 'Edit company' : 'Set up company'),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: prov.loading && prov.profile == null
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _logoPicker(prov),
                      const SizedBox(height: 24),
                      _sectionLabel('Basics'),
                      _textField(
                        controller: _name,
                        label: 'Company name *',
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Required (min 2 chars)'
                            : null,
                      ),
                      _textField(
                        controller: _industry,
                        label: 'Industry (e.g., IT, Finance)',
                      ),
                      _sizeDropdown(),
                      _yearField(),
                      _textField(
                        controller: _website,
                        label: 'Website (https://...)',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _sectionLabel('About the company')),
                          TextButton.icon(
                            onPressed: _generatingDescription
                                ? null
                                : _generateDescription,
                            icon: _generatingDescription
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 16),
                            label: Text(
                              _description.text.trim().isEmpty
                                  ? 'Draft with AI'
                                  : 'Re-draft with AI',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      _textField(
                        controller: _description,
                        label: 'Short description',
                        maxLines: 5,
                        maxLength: 5000,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('Headquarters'),
                      Row(
                        children: [
                          Expanded(
                            child:
                                _textField(controller: _hqCity, label: 'City'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                                _textField(controller: _hqState, label: 'State'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('Social'),
                      _textField(
                        controller: _linkedin,
                        label: 'LinkedIn URL',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),
                      _textField(
                        controller: _twitter,
                        label: 'Twitter / X URL',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),
                      const SizedBox(height: 32),
                      PrimaryButton(
                        label: isEdit ? 'Save changes' : 'Create profile',
                        isLoading: prov.loading,
                        onPressed: prov.loading ? null : _save,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _logoPicker(HirerProvider prov) {
    final remoteUrl = prov.profile?.companyLogoUrl;
    Widget? preview;
    if (_pendingLogo != null) {
      preview = ClipOval(
        child: Image.file(_pendingLogo!, fit: BoxFit.cover, width: 96, height: 96),
      );
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      final resolved = AppAvatar.resolveBackendUrl(remoteUrl);
      preview = ClipOval(
        child: Image.network(
          resolved ?? remoteUrl,
          fit: BoxFit.cover,
          width: 96,
          height: 96,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.business, size: 36, color: Colors.white70),
        ),
      );
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: preview ??
                  const Icon(Icons.add_a_photo_outlined,
                      size: 32, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          AppText.caption(
            _pendingLogo != null ? 'New logo selected' : 'Tap to add company logo',
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: AppText.body(label, fontWeight: FontWeight.w700),
      );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomTextField(
        controller: controller,
        hint: label,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType ?? TextInputType.text,
        validator: validator,
      ),
    );
  }

  Widget _sizeDropdown() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: _companySize,
          decoration: InputDecoration(
            labelText: 'Company size',
            filled: true,
            fillColor: context.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          items: _sizes
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _companySize = v),
        ),
      );

  Widget _yearField() {
    final now = DateTime.now().year;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomTextField(
        controller: _foundedYearCtrl,
        hint: 'Founded year',
        keyboardType: TextInputType.number,
        onChanged: (v) {
          final n = int.tryParse(v);
          _foundedYear = (n != null && n >= 1800 && n <= now) ? n : null;
        },
        validator: (v) {
          if (v == null || v.isEmpty) return null;
          final n = int.tryParse(v);
          if (n == null) return 'Enter a year';
          if (n < 1800 || n > now) return 'Year out of range';
          return null;
        },
      ),
    );
  }

  String? _optionalUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final uri = Uri.tryParse(v.trim());
    if (uri == null || !uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Must be an http(s) URL';
    }
    return null;
  }
}
