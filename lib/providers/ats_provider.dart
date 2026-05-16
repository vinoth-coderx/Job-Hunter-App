import 'package:flutter/foundation.dart';

import '../data/models/ai_quota_model.dart';
import '../data/models/ats_analysis_model.dart';
import '../data/services/ai_service.dart';

/// Holds the latest ATS analysis result + the user's history list.
/// Caches the in-memory result so re-opening the screen doesn't re-fetch
/// (the backend caches by content hash anyway, but skipping the round-trip
/// is faster for the user).
///
/// `error` carries either a generic message or a quota error — the screen
/// branches on `quotaError` to show the upgrade banner instead of a snack.
class AtsProvider extends ChangeNotifier {
  AtsAnalysisResult? _result;
  List<AtsHistoryEntry> _history = const [];
  bool _loading = false;
  String? _error;
  AiQuotaExceededException? _quotaError;
  String? _scopedJobId;

  AtsAnalysisResult? get result => _result;
  List<AtsHistoryEntry> get history => _history;
  bool get isLoading => _loading;
  String? get error => _error;
  AiQuotaExceededException? get quotaError => _quotaError;
  String? get scopedJobId => _scopedJobId;

  Future<AiQuota?> analyze({String? jobId, bool refresh = false}) async {
    _loading = true;
    _error = null;
    _quotaError = null;
    _scopedJobId = jobId;
    notifyListeners();
    try {
      final res = await AiService.instance.atsScore(
        jobId: jobId,
        refresh: refresh,
      );
      _result = res.data;
      _loading = false;
      notifyListeners();
      return res.quota;
    } on AiQuotaExceededException catch (e) {
      _quotaError = e;
      _loading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadHistory({int limit = 10}) async {
    try {
      _history = await AiService.instance.atsHistory(limit: limit);
      notifyListeners();
    } catch (_) {
      // History is best-effort; never block the analyze flow.
    }
  }

  void clear() {
    _result = null;
    _error = null;
    _quotaError = null;
    _scopedJobId = null;
    notifyListeners();
  }
}
