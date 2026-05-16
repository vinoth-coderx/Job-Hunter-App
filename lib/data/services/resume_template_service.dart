import 'dart:typed_data';

import '../models/resume_template_model.dart';
import 'api_client.dart';

class TemplateDownloadQuota {
  TemplateDownloadQuota({
    required this.tier,
    required this.limit,
    required this.used,
    required this.remaining,
    required this.unlimited,
    required this.resetsAt,
  });

  final String tier;
  final int limit;
  final int used;
  /// `null` when [unlimited] is true.
  final int? remaining;
  final bool unlimited;
  final DateTime resetsAt;

  bool get blocked => limit == 0;
  bool get exhausted => !unlimited && (remaining ?? 0) <= 0;

  factory TemplateDownloadQuota.fromJson(Map<String, dynamic> json) {
    return TemplateDownloadQuota(
      tier: (json['tier'] as String?) ?? 'free',
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt(),
      unlimited: (json['unlimited'] as bool?) ?? false,
      resetsAt: DateTime.tryParse(json['resetsAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ResumeTemplateService {
  ResumeTemplateService._();
  static final ResumeTemplateService instance = ResumeTemplateService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<ResumeTemplateSummary>> list() async {
    final res = await _api.get('/resume-templates');
    final raw = (res['templates'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => ResumeTemplateSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ResumeTemplateDetail> get(String slug) async {
    final res = await _api.get('/resume-templates/$slug');
    final raw = Map<String, dynamic>.from(res['template'] as Map);
    return ResumeTemplateDetail.fromJson(raw);
  }

  Future<TemplateDownloadQuota> quota() async {
    final res = await _api.get('/resume-templates/quota');
    return TemplateDownloadQuota.fromJson(Map<String, dynamic>.from(res));
  }

  /// Calls the download endpoint and returns the PDF bytes. The server
  /// decrements the user's monthly quota atomically before rendering;
  /// a 403 surfaces here as an `ApiException(403, ...)`.
  Future<Uint8List> download(String slug) async {
    final res = await _api.postRaw('/resume-templates/$slug/download');
    return res.bodyBytes;
  }

  /// Sample-data PDF for the preview screen. Renders the template with
  /// placeholder values so the seeker can see a finished resume before
  /// inserting their own data. No quota — safe to call on every screen
  /// open.
  Future<Uint8List> previewSample(String slug) async {
    final res = await _api.getRaw('/resume-templates/$slug/preview-sample.pdf');
    return res.bodyBytes;
  }
}
