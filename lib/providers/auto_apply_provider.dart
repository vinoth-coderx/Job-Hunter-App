import 'package:flutter/foundation.dart';

import '../data/models/auto_apply_settings_model.dart';
import '../data/services/auto_apply_service.dart';

class AutoApplyProvider extends ChangeNotifier {
  final AutoApplyService _service = AutoApplyService.instance;

  AutoApplySettings? _settings;
  bool _loading = false;
  String? _error;

  AutoApplySettings? get settings => _settings;
  bool get loading => _loading;
  String? get error => _error;
  bool get eligible => _settings?.eligible ?? false;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> load() async {
    _setLoading(true);
    _error = null;
    try {
      _settings = await _service.getSettings();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> save({
    bool? isEnabled,
    String? runTime,
    List<String>? runDays,
    int? dailyLimit,
    AutoApplyPreferences? preferences,
    AutoApplyMatchingRules? matchingRules,
    bool? reviewMode,
    AutoApplyAiCoverLetter? aiCoverLetter,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      _settings = await _service.updateSettings(
        isEnabled: isEnabled,
        runTime: runTime,
        runDays: runDays,
        dailyLimit: dailyLimit,
        preferences: preferences,
        matchingRules: matchingRules,
        reviewMode: reviewMode,
        aiCoverLetter: aiCoverLetter,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> pause({int? days, String? reason}) async {
    _error = null;
    try {
      _settings = await _service.pause(days: days, reason: reason);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resume() async {
    _error = null;
    try {
      _settings = await _service.resume();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
