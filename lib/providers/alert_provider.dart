import 'package:flutter/foundation.dart';

import '../data/models/alert_model.dart';
import '../data/services/alert_service.dart';
import '../data/services/api_client.dart';

class AlertProvider extends ChangeNotifier {
  final AlertService _service = AlertService();

  List<JobAlert> _alerts = [];
  bool _isLoading = false;
  String? _error;

  List<JobAlert> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Total notifications across all alerts — used for the bell badge.
  int get unreadBadge => _alerts.fold<int>(
        0,
        (sum, a) => sum + a.notificationCount,
      );

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _alerts = await _service.list();
    } catch (e) {
      _error = _formatError(e);
      _alerts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<JobAlert?> create({
    String? label,
    required String query,
    List<String> filters = const [],
    String? location,
    String? sort,
  }) async {
    try {
      final created = await _service.create(
        label: label,
        query: query,
        filters: filters,
        location: location,
        sort: sort,
      );
      // Replace existing entry if backend dedupe matched, else prepend.
      final idx = _alerts.indexWhere((a) => a.id == created.id);
      if (idx >= 0) {
        _alerts = [..._alerts]..[idx] = created;
      } else {
        _alerts = [created, ..._alerts];
      }
      notifyListeners();
      return created;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> toggleActive(JobAlert alert) async {
    try {
      final updated = await _service.update(alert.id, active: !alert.active);
      _alerts =
          _alerts.map((a) => a.id == alert.id ? updated : a).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _service.remove(id);
      _alerts = _alerts.where((a) => a.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }
}
