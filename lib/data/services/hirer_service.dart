import 'dart:io' show File;

import '../models/hirer_profile_model.dart';
import 'api_client.dart';

class HirerService {
  HirerService._();
  static final HirerService instance = HirerService._();

  final ApiClient _api = ApiClient.instance;

  /// Returns null when the current user has no hirer profile yet.
  Future<HirerProfile?> getMyProfile() async {
    final raw = await _api.get('hirer/profile');
    final data = ApiClient.unwrap<dynamic>(raw);
    if (data == null) return null;
    return HirerProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<HirerProfile> create({
    required String companyName,
    String? industry,
    String? companySize,
    int? foundedYear,
    String? website,
    String? description,
    String? cultureValues,
    CompanyHeadquarters? headquarters,
    List<CompanyOtherLocation>? otherLocations,
    CompanySocialLinks? socialLinks,
  }) async {
    final body = <String, dynamic>{
      'companyName': companyName,
      if (industry != null && industry.isNotEmpty) 'industry': industry,
      if (companySize != null) 'companySize': companySize,
      if (foundedYear != null) 'foundedYear': foundedYear,
      if (website != null && website.isNotEmpty) 'website': website,
      if (description != null && description.isNotEmpty) 'description': description,
      if (cultureValues != null && cultureValues.isNotEmpty)
        'cultureValues': cultureValues,
      if (headquarters != null) 'headquarters': headquarters.toJson(),
      if (otherLocations != null)
        'otherLocations': otherLocations.map((l) => l.toJson()).toList(),
      if (socialLinks != null) 'socialLinks': socialLinks.toJson(),
    };
    final raw = await _api.post('hirer/profile', body: body);
    return HirerProfile.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<HirerProfile> update({
    String? companyName,
    String? industry,
    String? companySize,
    int? foundedYear,
    String? website,
    String? description,
    String? cultureValues,
    CompanyHeadquarters? headquarters,
    List<CompanyOtherLocation>? otherLocations,
    CompanySocialLinks? socialLinks,
  }) async {
    final body = <String, dynamic>{
      if (companyName != null) 'companyName': companyName,
      if (industry != null) 'industry': industry,
      if (companySize != null) 'companySize': companySize,
      if (foundedYear != null) 'foundedYear': foundedYear,
      if (website != null) 'website': website,
      if (description != null) 'description': description,
      if (cultureValues != null) 'cultureValues': cultureValues,
      if (headquarters != null) 'headquarters': headquarters.toJson(),
      if (otherLocations != null)
        'otherLocations': otherLocations.map((l) => l.toJson()).toList(),
      if (socialLinks != null) 'socialLinks': socialLinks.toJson(),
    };
    final raw = await _api.put('hirer/profile', body: body);
    return HirerProfile.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<String> uploadLogo(File logo) async {
    final raw = await _api.uploadFromFile(
      'hirer/profile/logo',
      field: 'logo',
      file: logo,
      contentType: _imageMime(logo.path),
    );
    final data = ApiClient.unwrapMap(raw);
    return data['logoUrl'] as String;
  }

  Future<List<String>> uploadOfficePhotos(List<File> photos) async {
    if (photos.isEmpty) return const [];
    // Backend accepts multi-file under field `photos` — we send sequentially
    // because the api_client multipart helper currently handles one file at
    // a time. Sequential keeps it simple and avoids race conditions on the
    // 10-photo cap.
    List<String> last = const [];
    for (final p in photos) {
      final raw = await _api.uploadFromFile(
        'hirer/profile/photos',
        field: 'photos',
        file: p,
        contentType: _imageMime(p.path),
      );
      final data = ApiClient.unwrapMap(raw);
      last = (data['officePhotos'] as List?)?.map((e) => e.toString()).toList() ??
          const [];
    }
    return last;
  }

  /// Map the picked file's extension to the right image MIME. Without this
  /// MultipartRequest defaults to `application/octet-stream` and the
  /// backend's image-only multer filter rejects with "Only JPG, PNG, or
  /// WEBP image files are allowed".
  static String _imageMime(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  Future<List<String>> deleteOfficePhoto(String filename) async {
    final raw = await _api.delete('hirer/profile/photos/$filename');
    final data = ApiClient.unwrapMap(raw);
    return (data['officePhotos'] as List?)?.map((e) => e.toString()).toList() ??
        const [];
  }

  Future<HirerStats> getStats() async {
    final raw = await _api.get('hirer/stats');
    return HirerStats.fromJson(ApiClient.unwrapMap(raw));
  }

  /// "Needs attention" snapshot — pure data aggregation, no AI cost.
  /// Returns the four pipeline blockers (appeals, flagged jobs,
  /// unreviewed top matches, stale jobs) so the hirer can act on the
  /// most-time-sensitive items the moment they land on the dashboard.
  /// Returns the loose dynamic Map so the screen can read counts +
  /// topItem without a dedicated model class.
  Future<Map<String, dynamic>> getAttention() async {
    final raw = await _api.get('hirer/attention');
    return ApiClient.unwrapMap(raw);
  }

  /// AI weekly digest for the hirer dashboard. Returns the headline +
  /// bullets directly from the backend; failures bubble as exceptions
  /// so the dashboard widget can render an empty state. Same-day cache
  /// on the server side means visits within 24h are quota-free.
  Future<({String headline, List<String> bullets, bool cached, bool usedAi})>
      getDigest() async {
    final raw = await _api.get('hirer/digest');
    final data = ApiClient.unwrapMap(raw);
    return (
      headline: (data['headline'] ?? '').toString(),
      bullets: (data['bullets'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[],
      cached: data['cached'] as bool? ?? false,
      usedAi: data['usedAi'] as bool? ?? false,
    );
  }

  Future<HirerProfile> getPublicCompany(String id) async {
    final raw = await _api.get('hirer/profile/public/$id', auth: false);
    return HirerProfile.fromJson(ApiClient.unwrapMap(raw));
  }

  /// AI-draft the "About" section for the company profile. Used by the
  /// hirer setup screen as a one-tap kickstart so first-time hirers
  /// don't sit staring at an empty 5000-char text box.
  Future<({String description, bool usedAi, bool cached})>
      generateCompanyDescription({
    String? companyName,
    String? industry,
    String? sizeBand,
    String? hqLocation,
    String? whatYouDo,
    String? toneHint,
  }) async {
    final body = <String, dynamic>{
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
      if (industry != null && industry.trim().isNotEmpty)
        'industry': industry.trim(),
      if (sizeBand != null && sizeBand.trim().isNotEmpty)
        'sizeBand': sizeBand.trim(),
      if (hqLocation != null && hqLocation.trim().isNotEmpty)
        'hqLocation': hqLocation.trim(),
      if (whatYouDo != null && whatYouDo.trim().isNotEmpty)
        'whatYouDo': whatYouDo.trim(),
      if (toneHint != null) 'toneHint': toneHint,
    };
    final raw =
        await _api.post('hirer/profile/generate-description', body: body);
    final data = ApiClient.unwrapMap(raw);
    return (
      description: (data['description'] ?? '').toString(),
      usedAi: data['usedAi'] as bool? ?? false,
      cached: data['cached'] as bool? ?? false,
    );
  }
}
