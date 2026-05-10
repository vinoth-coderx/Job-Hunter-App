import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/hirer_profile_model.dart';
import '../data/services/hirer_service.dart';

class HirerProvider extends ChangeNotifier {
  final HirerService _service = HirerService.instance;

  HirerProfile? _profile;
  HirerStats? _stats;
  bool _loading = false;
  String? _error;

  HirerProfile? get profile => _profile;
  HirerStats? get stats => _stats;
  bool get loading => _loading;
  bool get hasProfile => _profile != null;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      final p = await _service.getMyProfile();
      _profile = p;
      _stats = await _service.getStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> create({
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
    _setLoading(true);
    _error = null;
    try {
      _profile = await _service.create(
        companyName: companyName,
        industry: industry,
        companySize: companySize,
        foundedYear: foundedYear,
        website: website,
        description: description,
        cultureValues: cultureValues,
        headquarters: headquarters,
        otherLocations: otherLocations,
        socialLinks: socialLinks,
      );
      _stats = await _service.getStats();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> update({
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
    _setLoading(true);
    _error = null;
    try {
      _profile = await _service.update(
        companyName: companyName,
        industry: industry,
        companySize: companySize,
        foundedYear: foundedYear,
        website: website,
        description: description,
        cultureValues: cultureValues,
        headquarters: headquarters,
        otherLocations: otherLocations,
        socialLinks: socialLinks,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> uploadLogo(File logo) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.uploadLogo(logo);
      // Refresh full profile to pick up the new logoUrl.
      _profile = await _service.getMyProfile();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> uploadPhotos(List<File> photos) async {
    if (photos.isEmpty) return true;
    _setLoading(true);
    _error = null;
    try {
      await _service.uploadOfficePhotos(photos);
      _profile = await _service.getMyProfile();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deletePhoto(String filename) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.deleteOfficePhoto(filename);
      _profile = await _service.getMyProfile();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshStats() async {
    try {
      _stats = await _service.getStats();
      notifyListeners();
    } catch (_) {
      // Don't surface — stats are auxiliary.
    }
  }

  void clear() {
    _profile = null;
    _stats = null;
    _error = null;
    notifyListeners();
  }
}
