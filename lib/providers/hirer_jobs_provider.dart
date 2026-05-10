import 'package:flutter/foundation.dart';

import '../data/models/hirer_job_model.dart';
import '../data/services/hirer_job_service.dart';

class HirerJobsProvider extends ChangeNotifier {
  final HirerJobService _service = HirerJobService.instance;

  final List<HirerJob> _jobs = [];
  String _statusFilter = 'all';
  bool _loading = false;
  String? _error;
  int _total = 0;

  List<HirerJob> get jobs => List.unmodifiable(_jobs);
  String get statusFilter => _statusFilter;
  bool get loading => _loading;
  String? get error => _error;
  int get total => _total;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> load({String? status}) async {
    if (status != null) _statusFilter = status;
    _setLoading(true);
    _error = null;
    try {
      final res = await _service.listMine(status: _statusFilter);
      _jobs
        ..clear()
        ..addAll(res.jobs);
      _total = res.total;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<HirerJob?> create(HirerJobInput input) async {
    _error = null;
    try {
      final created = await _service.create(input);
      _jobs.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    _error = null;
    try {
      await _service.updateStatus(id, status);
      // Refresh to pick up new status filter alignment.
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDraft(String id) async {
    _error = null;
    try {
      await _service.delete(id);
      _jobs.removeWhere((j) => j.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
